function(get_project_version_from_commit_count BRANCH_NAME)
    find_package(Git)
    if (NOT GIT_FOUND)
        message(FATAL_ERROR "Could not find git (required to set project version)")
    endif ()

    message(status "${PROJECT_NAME}: CMAKE_CURRENT_SOURCE_DIR       = '${CMAKE_CURRENT_SOURCE_DIR}'")
    execute_process(
        COMMAND "${GIT_EXECUTABLE}" rev-list ${BRANCH_NAME} --count
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
        RESULT_VARIABLE GIT_RESULT
        OUTPUT_VARIABLE GIT_COMMIT_COUNT
        ERROR_VARIABLE GIT_ERROR
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_STRIP_TRAILING_WHITESPACE
    )

    if (NOT GIT_RESULT EQUAL 0)
        message(FATAL_ERROR ${GIT_ERROR})
    endif ()

    math(EXPR version_major "${GIT_COMMIT_COUNT} / (256*256) + 1")
    math(EXPR version_minor "(${GIT_COMMIT_COUNT} - (${version_major}-1)*256*256) / 256")
    math(EXPR version_patch "(${GIT_COMMIT_COUNT} - (${version_major}-1)*256*256) - ${version_minor}*256")

    message(STATUS "${PROJECT_NAME}: GIT_COMMIT_COUNT               = '${GIT_COMMIT_COUNT}'")
    message(STATUS "${PROJECT_NAME}: version_major                  = '${version_major}'")
    message(STATUS "${PROJECT_NAME}: version_minor                  = '${version_minor}'")
    message(STATUS "${PROJECT_NAME}: version_patch                  = '${version_patch}'")

    set(GIT_EXECUTABLE ${GIT_EXECUTABLE} PARENT_SCOPE)
    set(GIT_COMMIT_COUNT ${GIT_COMMIT_COUNT} PARENT_SCOPE)
    set(version_major ${version_major} PARENT_SCOPE)
    set(version_minor ${version_minor} PARENT_SCOPE)
    set(version_patch ${version_patch} PARENT_SCOPE)
endfunction()
