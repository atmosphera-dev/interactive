# SPDX-License-Identifier: LGPL-3.0-or-later
qt_add_executable(interactive_quick_tests runner.cpp ../shared/TestTraceSetup.h ../shared/TestTraceSetup.cpp)
set_target_properties(interactive_quick_tests PROPERTIES OUTPUT_NAME interactive-quick-tests)
target_include_directories(interactive_quick_tests PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/../shared")
target_link_libraries(interactive_quick_tests PRIVATE
    InterActive::Foundation InterActive::Controls Qt6::QuickTest Qt6::Quick Qt6::Gui Qt6::Test)
qt_add_qml_module(interactive_quick_tests
    URI InterActive.Tests
    DEPENDENCIES QtQuick
    SOURCES TestProbe.h TestProbe.cpp DocumentProbe.h DocumentProbe.cpp
    QML_FILES
        qml/MixedFixture.qml
        qml/PopupFixture.qml
        qml/tst_controls.qml
        qml/tst_geometry.qml
        qml/tst_popups.qml
        qml/tst_icons.qml
        qml/tst_states.qml
        qml/tst_capture.qml
        qml/tst_solid.qml
        qml/PaletteStateFixture.qml
        qml/tst_palette_state.qml
        qml/LongDocumentFixture.qml
        qml/tst_long_document.qml
        qml/iconconsumer/IconConsumer.qml
    RESOURCES qml/iconconsumer/icons/consumer-mark.svg
)
add_test(NAME interactive.qt-version COMMAND interactive_quick_tests --qt-version)
add_test(NAME interactive.controls COMMAND interactive_quick_tests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_controls.qml")
add_test(NAME interactive.geometry COMMAND interactive_quick_tests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_geometry.qml")
add_test(NAME interactive.popups COMMAND interactive_quick_tests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_popups.qml")
set_tests_properties(interactive.popups PROPERTIES RUN_SERIAL TRUE)
add_test(NAME interactive.icons COMMAND interactive_quick_tests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_icons.qml")
add_test(NAME interactive.states COMMAND interactive_quick_tests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_states.qml")
add_test(NAME interactive.solid COMMAND interactive_quick_tests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_solid.qml")
add_test(NAME interactive.palette-state COMMAND interactive_quick_tests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_palette_state.qml")
add_test(NAME interactive.long-document COMMAND interactive_quick_tests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_long_document.qml")
set_tests_properties(interactive.qt-version interactive.controls interactive.geometry interactive.popups interactive.icons interactive.states interactive.solid interactive.palette-state interactive.long-document
    PROPERTIES LABELS interactive-overview TIMEOUT 180)
add_test(NAME interactive.capture COMMAND interactive_quick_tests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_capture.qml")
set_tests_properties(interactive.capture PROPERTIES LABELS interactive-capture TIMEOUT 600)
target_compile_definitions(interactive_quick_tests PRIVATE
    IA_EXPECTED_QT_VERSION="${Qt6_VERSION}")

if(INTERACTIVE_BUILD_PLAYGROUND)
    target_compile_definitions(interactive_quick_tests PRIVATE IA_TEST_PLAYGROUND=1)
    target_link_libraries(interactive_quick_tests PRIVATE interactive_playground_scene InterActive::Components)
    qt_target_qml_sources(interactive_quick_tests QML_FILES qml/tst_playground.qml)
    add_test(NAME interactive.playground COMMAND interactive_quick_tests
        -input "${CMAKE_CURRENT_SOURCE_DIR}/qml/tst_playground.qml")
    set_tests_properties(interactive.playground PROPERTIES LABELS interactive-overview TIMEOUT 180)
    set_tests_properties(interactive.playground PROPERTIES RUN_SERIAL TRUE)
endif()
