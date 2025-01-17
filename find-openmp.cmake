if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    find_package(OpenMP) # first try it without any extra configuration

    if (NOT OpenMP_FOUND)
        execute_process(COMMAND brew --prefix libomp
            OUTPUT_VARIABLE HOMEBREW_LIBOMP_PREFIX
            OUTPUT_STRIP_TRAILING_WHITESPACE)
        set(OpenMP_C_FLAGS
            "-Xpreprocessor -fopenmp -I${HOMEBREW_LIBOMP_PREFIX}/include")
        set(OpenMP_CXX_FLAGS
            "-Xpreprocessor -fopenmp -I${HOMEBREW_LIBOMP_PREFIX}/include")
        set(OpenMP_C_LIB_NAMES omp)
        set(OpenMP_CXX_LIB_NAMES omp)
        set(OpenMP_omp_LIBRARY ${HOMEBREW_LIBOMP_PREFIX}/lib/libomp.dylib)

        find_package(OpenMP REQUIRED)
    endif ()
else ()
    find_package(OpenMP REQUIRED)
endif ()
