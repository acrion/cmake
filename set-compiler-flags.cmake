if (WIN32)
    target_compile_definitions(${PROJECT_NAME} PRIVATE _WIN32_WINNT=0x0A00 _SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING)
    if (MSVC)
        # note that property COMPILE_OPTIONS is not suitable for this purpose, as it does not contain the predefined options
        string(REGEX REPLACE "/W[0-4]" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")

        # Under MSVC, we want to be able to debug with the Release runtime without restrictions caused by optimizations
        string(REGEX REPLACE "/O2" "/Od" CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
        string(REGEX REPLACE "/Ob2" "" CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")

        target_compile_options(${PROJECT_NAME} PRIVATE /W4 /wd4068 /wd4251 /wd4275 /Zc:__cplusplus /utf-8)
    elseif (MINGW)
        target_compile_options(${PROJECT_NAME} PRIVATE -fexceptions -Wall -pedantic)
    else ()
        message(error "${CMAKE_SYSTEM_NAME}: Only Windows systems MSVC and MINGW are supported")
    endif ()
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    get_target_property(_target_sources ${PROJECT_NAME} SOURCES)
    foreach(_source IN LISTS _target_sources)
        get_filename_component(_source_ext "${_source}" EXT)
        if(_source_ext STREQUAL ".cpp")
            set_source_files_properties(${_source} PROPERTIES COMPILE_OPTIONS "-stdlib=libc++")
        endif()
    endforeach()

    set_target_properties(${PROJECT_NAME} PROPERTIES MACOSX_RPATH ON)
    SET(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -current_version ${PROJECT_VERSION}")
elseif (${CMAKE_SYSTEM_NAME} MATCHES "Linux")
    target_compile_options(${PROJECT_NAME} PRIVATE -Wno-unknown-pragmas -pthread -fPIC -Wall -pedantic -Wl,-rpath,'$ORIGIN')
else ()
    message(error "Unsupported system ${CMAKE_SYSTEM_NAME}")
endif ()

# In MSVC, the configuration is determined at build time rather than at generate time, 
# making it necessary to use generator expressions to set the compile definitions accordingly.
# Here, if the configuration is either Debug or RelWithDebInfo, the DBG and _DEBUG compile 
# definitions are set for the target.
target_compile_definitions(${PROJECT_NAME} PRIVATE
    $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:DBG>
    $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:_DEBUG>
)

if (CMAKE_BUILD_TYPE MATCHES Debug OR CMAKE_BUILD_TYPE MATCHES RelWithDebInfo)
    # Workaround for MSVC in scenarios where generator expressions are
    # difficult to employ, such as when source files are conditionally added
    # based on the configuration. Here, the GENERATED_WITH_DBG_CONFIGURATION 
    # compile definition is set for the target if the build type at generation 
    # time (in contrast to build time) is either Debug or RelWithDebInfo.
    target_compile_definitions(${PROJECT_NAME} PRIVATE GENERATED_WITH_DBG_CONFIGURATION)
    set(GENERATED_WITH_DBG_CONFIGURATION ON CACHE INTERNAL "Generated with Debug or RelWithDebInfo Configuration")
else ()
    set(GENERATED_WITH_DBG_CONFIGURATION OFF CACHE INTERNAL "Not generated with Debug or RelWithDebInfo Configuration")
endif ()

target_compile_options(${PROJECT_NAME} PUBLIC -DUSING_CMAKE)

if (NOT MSVC)
    target_compile_options(${PROJECT_NAME} PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:-g>)
endif ()

string(TIMESTAMP BUILD_TIME "%Y-%m-%d %H:%M") # to make BUILD_TIME available for file configuration
