function(get_project_version_from_git_tag)
    find_package(Git)
    if (NOT GIT_FOUND)
        message(FATAL_ERROR "Could not find git (required to set project version from Git tag)")
    endif ()

    # Try to get the exact matching tag for the current commit
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" describe --tags --exact-match
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE GIT_RESULT
        OUTPUT_VARIABLE GIT_TAG
        ERROR_VARIABLE GIT_ERROR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE
    )

    if (NOT GIT_RESULT EQUAL 0)
        # If there's no exact matching tag, set version to 0.0.0
        set(version_major 0)
        set(version_minor 0)
        set(version_patch 0)
        message(WARNING "${PROJECT_NAME}: No exact matching tag found for current commit - version set to 0.0.0")
    else ()
        # We have an exact tag in GIT_TAG, now parse it.
        # Example tags: "v1.2.3" or "1.2.3"
        # We strip leading 'v' if present
        string(REGEX REPLACE "^v" "" GIT_TAG "${GIT_TAG}")

        # Now split on '.' to get major, minor, patch
        string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" MATCHED_VERSION "${GIT_TAG}")
        if (NOT MATCHED_VERSION)
            # Could not parse the tag in the form X.Y.Z
            set(version_major 0)
            set(version_minor 0)
            set(version_patch 0)
            message(WARNING
                "${PROJECT_NAME}: Tag '${GIT_TAG}' does not match the 'X.Y.Z' pattern - version set to 0.0.0")
        else ()
            string(REGEX REPLACE "^([0-9]+)\\..*$" "\\1" version_major "${GIT_TAG}")
            string(REGEX REPLACE "^[0-9]+\\.([0-9]+)\\..*$" "\\1" version_minor "${GIT_TAG}")
            string(REGEX REPLACE "^[0-9]+\\.[0-9]+\\.([0-9]+).*$" "\\1" version_patch "${GIT_TAG}")
            message(STATUS "${PROJECT_NAME}: Git tag '${GIT_TAG}' parsed successfully.")
            message(STATUS "${PROJECT_NAME}: version_major = '${version_major}'")
            message(STATUS "${PROJECT_NAME}: version_minor = '${version_minor}'")
            message(STATUS "${PROJECT_NAME}: version_patch = '${version_patch}'")
        endif ()
    endif ()

    # Propagate variables to parent scope
    set(GIT_EXECUTABLE ${GIT_EXECUTABLE} PARENT_SCOPE)
    set(GIT_TAG ${GIT_TAG} PARENT_SCOPE)
    set(version_major ${version_major} PARENT_SCOPE)
    set(version_minor ${version_minor} PARENT_SCOPE)
    set(version_patch ${version_patch} PARENT_SCOPE)
endfunction()
