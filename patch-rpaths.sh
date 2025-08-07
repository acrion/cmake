#!/usr/bin/env bash

show_usage() {
    echo
    echo "Usage: $0 <path-to-file-or-directory> [file-filter] [-n]"
    echo
    echo "This script updates the paths of dependent binaries or shared libraries to reference"
    echo "those located in the build directory, avoiding system-wide locations after a build process."
    echo "Designed for use on macOS (for .dylib files and executables) and Linux (for .so files and executables)."
    echo
    echo "Arguments:"
    echo "  <path-to-file-or-directory>  The file or directory to process."
    echo "  [file-filter]                Optional. Restricts the search in a directory, e.g., '*.so*'."
    echo "  [-n]                         Optional. If provided, the search will not be recursive."
    echo
}

check_requirements() {
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        command -v patchelf >/dev/null 2>&1 || { echo >&2 "The tool 'patchelf' is required but it's not installed. Aborting."; exit 1; }
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        command -v install_name_tool >/dev/null 2>&1 || { echo >&2 "The tool 'install_name_tool' is required but it's not installed. Aborting."; exit 1; }
        command -v otool >/dev/null 2>&1 || { echo >&2 "The tool 'otool' is required but it's not installed. Aborting."; exit 1; }
        command -v realpath >/dev/null 2>&1 || { echo >&2 "The tool 'realpath' is required but it's not installed. Aborting."; exit 1; }
    fi
}

patch_linux_binary() {
    local target_file="$1"
    echo "Processing $target_file on Linux..."
    patchelf --set-rpath '$ORIGIN' "$target_file"
    echo "RPATH successfully set to '\$ORIGIN' for $target_file."
}

patch_macos_binary() {
    local target_file="$1"
    echo "Processing $target_file..."

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

patch_binary() {
    local binary_file=$1
    local filetype=$(file --brief --no-dereference "$binary_file")

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
        esac
    fi
}

if [[ $# -eq 0 || $# -gt 3 ]]; then
    show_usage
    exit 1
fi

check_requirements

TARGET_PATH="$1"
FILE_FILTER=""
NON_RECURSIVE_FLAG=false

if [[ "$2" == "-n" ]]; then
    NON_RECURSIVE_FLAG=true
elif [[ -n "$2" ]]; then
    FILE_FILTER="$2"
fi

if [[ "$3" == "-n" ]]; then
    NON_RECURSIVE_FLAG=true
fi


if [[ -d "$TARGET_PATH" ]]; then
    find_cmd="find \"$TARGET_PATH\""
    if [[ "$NON_RECURSIVE_FLAG" == true ]]; then
        find_cmd+=" -maxdepth 1"
    fi
    find_cmd+=" -type f"
    if [[ -n "$FILE_FILTER" ]]; then
        find_cmd+=" -name \"$FILE_FILTER\""
    fi
    eval "$find_cmd" | while read -r binary_file; do
        patch_binary "$binary_file"
    done
elif [[ -f "$TARGET_PATH" ]]; then
    patch_binary "$TARGET_PATH"
else
    echo "The specified path is not valid."
    exit 1
fi
