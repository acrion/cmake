#!/usr/bin/env bash

# This script updates the RPATH of executables and shared libraries on Linux,
# or the dependent library paths on macOS. It makes them search for dependencies
# in their own directory first ('$ORIGIN' on Linux, '@loader_path' on macOS).
# This is useful for creating relocatable application bundles.

# --- Helper Functions ---

# Shows how to use the script.
show_usage() {
    echo
    echo "Usage: $0 <path> [file-filter] [-n] [--verbose]"
    echo
    echo "Arguments:"
    echo "  <path>          Required. The file or directory to process."
    echo "  [file-filter]   Optional. A pattern to filter files, e.g., '*.so*'."
    echo "  [-n]            Optional. If provided, the search in a directory will not be recursive."
    echo "  [--verbose]     Optional. Enables detailed logging for debugging purposes."
    echo
}

# Logs a message, but only if verbose mode is enabled.
# Prepends a timestamp and [DEBUG] prefix.
log_verbose() {
    if [[ "$VERBOSE_MODE" == "true" ]]; then
        echo "[$(date +'%H:%M:%S')] [DEBUG] $1"
    fi
}

# Checks if required command-line tools (like patchelf) are installed.
check_requirements() {
    log_verbose "Checking for required tools..."
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        command -v patchelf >/dev/null 2>&1 || { echo >&2 "Error: 'patchelf' is required but not installed. Aborting."; exit 1; }
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        command -v install_name_tool >/dev/null 2>&1 || { echo >&2 "Error: 'install_name_tool' is required but not installed. Aborting."; exit 1; }
        command -v otool >/dev/null 2>&1 || { echo >&2 "Error: 'otool' is required but not installed. Aborting."; exit 1; }
        command -v realpath >/dev/null 2>&1 || { echo >&2 "Error: 'realpath' is required but not installed. Aborting."; exit 1; }
    fi
    log_verbose "All required tools are present."
}

# --- Platform-Specific Patching Logic ---

patch_linux_binary() {
    local target_file="$1"
    echo "Processing Linux binary: $target_file"
    log_verbose "Executing: patchelf --set-rpath '\$ORIGIN' \"$target_file\""
    if patchelf --set-rpath '$ORIGIN' "$target_file"; then
        log_verbose "Successfully set RPATH to '\$ORIGIN' for $target_file."
    else
        echo "Warning: patchelf command failed for $target_file."
    fi
}

patch_macos_binary() {
    local target_file="$1"
    echo "Processing macOS binary: $target_file"

    local otool_output=$(otool -L "$target_file")
    IFS=$'\n'
    local dylib_lines_from_otool=($otool_output)
    unset IFS

    for line in "${dylib_lines_from_otool[@]}"; do
        stripped_line=$(echo "$line" | xargs)

        if [[ "$stripped_line" =~ ^(.+\.dylib) ]]; then
            local full_path="${BASH_REMATCH[1]}"
            local full_path_name=$(basename "$full_path")
            local target_file_realpath=$(realpath "$target_file")
            local target_file_name=$(basename "$target_file_realpath")
            local lib_name=$(basename "$full_path")
            local path_to_lib=$(dirname "$target_file_realpath")/"$lib_name"

            if [[ "$full_path_name" != "$target_file_name" && "$full_path" != "$target_file" && ! "$full_path" =~ ^@.* ]]; then
                if [[ -f "$path_to_lib" ]]; then
                if install_name_tool -change "$full_path" "@loader_path/$lib_name" "$target_file"; then
                        echo "Successfully updated '$target_file' to load '$lib_name' from the same directory instead of '$full_path'."
                else
                        echo "Failed to update '$target_file' to load '$lib_name' from the same directory instead of '$full_path'."
                        exit 1
                    fi
                    echo
                else
                    echo "Skipping '$lib_name' as it does not exist next to '$target_file'."
                fi
            fi
        fi
    done
}

# Determines file type and calls the appropriate patching function.
patch_binary() {
    local binary_file="$1"
    log_verbose "Checking file type for: $binary_file"
    local filetype
    filetype=$(file --brief --no-dereference "$binary_file")
    log_verbose "File type identified as: '$filetype'"

    # This regex covers both macOS and Linux output strings for executables and shared libraries,
    # e. g. "Mach-O 64-bit executable", "ELF 64-bit LSB pie executable", "ELF 64-bit LSB shared object"
    # and excludes object files ("Mach-O 64-bit object x86_64" or "ELF 64-bit LSB relocatable").
    if echo "$filetype" | grep -qE '(executable|shared)'; then
        case "$filetype" in
            ELF*)
                patch_linux_binary "$binary_file"
                ;;
            Mach-O*)
                patch_macos_binary "$binary_file"
                ;;
            *)
                log_verbose "File is of a recognized type but not ELF or Mach-O. Skipping."
                ;;
        esac
    else
        log_verbose "File is not an executable or shared library. Skipping."
    fi
}

# --- Main Execution Logic ---

# Argument parsing
TARGET_PATH=""
FILE_FILTER=""
NON_RECURSIVE_FLAG=false
VERBOSE_MODE=false
declare -a positional_args=()

for arg in "$@"; do
    case "$arg" in
        -n)
        NON_RECURSIVE_FLAG=true
        shift # remove flag from argument list
        ;;
        --verbose)
        VERBOSE_MODE=true
        shift # remove flag from argument list
        ;;
        *)
        positional_args+=("$arg") # store positional arg
        ;;
    esac
done

# Assign positional arguments
if (( ${#positional_args[@]} > 0 )); then
    TARGET_PATH="${positional_args[0]}"
fi
if (( ${#positional_args[@]} > 1 )); then
    FILE_FILTER="${positional_args[1]}"
fi

# Validate that the target path was provided
if [[ -z "$TARGET_PATH" ]]; then
    show_usage
    exit 1
fi

# --- Script Start ---
log_verbose "Script starting. Verbose mode is ON."
log_verbose "Target Path: '$TARGET_PATH'"
log_verbose "File Filter: '$FILE_FILTER'"
log_verbose "Non-recursive: $NON_RECURSIVE_FLAG"

check_requirements

if [[ -d "$TARGET_PATH" ]]; then
    # Construct the find command
    find_cmd="find \"$TARGET_PATH\""
    if [[ "$NON_RECURSIVE_FLAG" == true ]]; then
        find_cmd+=" -maxdepth 1"
    fi
    find_cmd+=" -type f"
    if [[ -n "$FILE_FILTER" ]]; then
        find_cmd+=" -name \"$FILE_FILTER\""
    fi
    
    log_verbose "Executing find command: $find_cmd"
    
    # Process the found files
    eval "$find_cmd" | while read -r file_to_process; do
        patch_binary "$file_to_process"
    done

elif [[ -f "$TARGET_PATH" ]]; then
    patch_binary "$TARGET_PATH"
else
    echo "Error: The specified path '$TARGET_PATH' is not a valid file or directory."
    exit 1
fi

log_verbose "Script finished."
