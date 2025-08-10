if (MSVC)
    add_custom_target(
        run_${PROJECT_NAME}_tests ALL
        COMMAND ${PROJECT_NAME} --gtest_brief=1 # no need to manipulate %errorlevel%, because Visual Studio does not delete the test executable on test failure ("|| exit /b 0" doesn't work anyway, because Visual Studio analyzes stdout in addition to %errorlevel%)
        COMMENT "Running ${PROJECT_NAME}..."
    )
else ()
    set(executable_path $<TARGET_FILE:${PROJECT_NAME}>)

    add_custom_target(
        run_${PROJECT_NAME}_tests ALL
        COMMAND bash ${CMAKE_CURRENT_LIST_DIR}/run_and_check_stderr.sh ${executable_path} --gtest_brief=1 || true # avoid automatic deletion of the test executable on test failure
        COMMENT "Running ${PROJECT_NAME}..."
    )
endif ()

add_dependencies(run_${PROJECT_NAME}_tests ${PROJECT_NAME})
