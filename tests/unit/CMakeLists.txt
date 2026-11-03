# SPDX-License-Identifier: LGPL-3.0-or-later
qt_add_executable(interactive_appearance_tests tst_appearance.cpp ../shared/TestTraceSetup.h ../shared/TestTraceSetup.cpp)
target_link_libraries(interactive_appearance_tests PRIVATE
    InterActive::Foundation Qt6::Test Qt6::Gui Qt6::Qml
)
target_include_directories(interactive_appearance_tests PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../shared"
    "${CMAKE_BINARY_DIR}/src/foundation"
)
# Independent final-output measurements; Foundation's private vendor symbols
# remain hidden. No production palette-selection code is linked into the oracle.
set(appearance_test_math "${PROJECT_SOURCE_DIR}/third_party/material-color-utilities")
target_sources(interactive_appearance_tests PRIVATE
    "${appearance_test_math}/cpp/cam/cam.cc"
    "${appearance_test_math}/cpp/cam/hct_solver.cc"
    "${appearance_test_math}/cpp/cam/hct.cc"
    "${appearance_test_math}/cpp/contrast/contrast.cc"
    "${appearance_test_math}/cpp/utils/utils.cc"
)
target_include_directories(interactive_appearance_tests PRIVATE "${appearance_test_math}")
set_target_properties(interactive_appearance_tests PROPERTIES
    OUTPUT_NAME interactive-appearance-tests
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin"
)
add_test(NAME interactive.appearance COMMAND interactive_appearance_tests)
set_tests_properties(interactive.appearance PROPERTIES
    LABELS interactive-overview
)

qt_add_executable(interactive_appearance_trace_tests tst_appearance_trace.cpp ../shared/TestTraceSetup.h ../shared/TestTraceSetup.cpp)
target_link_libraries(interactive_appearance_trace_tests PRIVATE
    InterActive::Foundation Qt6::Test Qt6::Gui Qt6::Qml
)
target_include_directories(interactive_appearance_trace_tests PRIVATE
    "${CMAKE_BINARY_DIR}/src/foundation"
    "${CMAKE_CURRENT_SOURCE_DIR}/../shared"
)
set_target_properties(interactive_appearance_trace_tests PROPERTIES
    OUTPUT_NAME interactive-appearance-trace-tests
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin"
)
add_test(NAME interactive.trace COMMAND interactive_appearance_trace_tests)
set_tests_properties(interactive.trace PROPERTIES
    LABELS interactive-overview
)

if(INTERACTIVE_BUILD_PLAYGROUND)
    qt_add_executable(interactive_playground_calibration_tests tst_playground_calibration.cpp)
    target_link_libraries(interactive_playground_calibration_tests PRIVATE
        interactive_playground_scene InterActive::Foundation Qt6::Test Qt6::Gui Qt6::Qml)
    set_target_properties(interactive_playground_calibration_tests PROPERTIES
        OUTPUT_NAME interactive-playground-calibration-tests
        RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin")
    add_test(NAME interactive.playground-calibration COMMAND interactive_playground_calibration_tests)
    set_tests_properties(interactive.playground-calibration PROPERTIES
        LABELS interactive-overview TIMEOUT 180)
endif()
