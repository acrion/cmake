message(STATUS "Running test executable ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_CFG_INTDIR}/${PROJECT_NAME}")

set(OUTPUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/test_output.txt")

execute_process(
    COMMAND "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${CMAKE_CFG_INTDIR}/${PROJECT_NAME}"
    RESULT_VARIABLE test_result
    OUTPUT_FILE ${OUTPUT_FILE}
)

if(NOT test_result EQUAL 0)
    message("${PROJECT_NAME} failed: file:///${OUTPUT_FILE}")
endif()
