# SPDX-License-Identifier: LGPL-3.0-or-later
find_package(Qt6 6.8 REQUIRED COMPONENTS QuickDialogs2)
qt_add_qml_module(interactive_playground_scene SHARED
    URI InterActive.Playground
    VERSION 1.0
    DEPENDENCIES
        QtQuick.Dialogs
        TARGET interactive_foundation
        TARGET interactive_controls
        TARGET interactive_components
    SOURCES PlaygroundState.h PlaygroundState.cpp AppearanceTraceController.h AppearanceTraceController.cpp
        PaletteSampleWriter.h PaletteSampleWriter.cpp PaletteSampleHistory.h PaletteSampleHistory.cpp
        LabelContrastTrial.h LabelContrastTrial.cpp
    QML_FILES Main.qml FoundationsPage.qml AppearanceEditor.qml PaletteColorPicker.qml AccentPaletteMenu.qml Specimen.qml
)
include(GenerateExportHeader)
generate_export_header(interactive_playground_scene)
target_include_directories(interactive_playground_scene PUBLIC
    "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}")
target_link_libraries(interactive_playground_scene PUBLIC
    Qt6::Quick InterActive::Foundation
    PRIVATE InterActive::Controls InterActive::Components Qt6::QuickDialogs2)
# Temporary label contrast trial: the playground's own copy of the vendored
# HCT/contrast math; Foundation's private vendor symbols remain hidden.
set(playground_trial_math "${PROJECT_SOURCE_DIR}/third_party/material-color-utilities")
target_sources(interactive_playground_scene PRIVATE
    "${playground_trial_math}/cpp/cam/cam.cc"
    "${playground_trial_math}/cpp/cam/hct_solver.cc"
    "${playground_trial_math}/cpp/cam/hct.cc"
    "${playground_trial_math}/cpp/contrast/contrast.cc"
    "${playground_trial_math}/cpp/utils/utils.cc"
)
target_include_directories(interactive_playground_scene PRIVATE "${playground_trial_math}")

qt_add_executable(interactive_playground main.cpp)
target_link_libraries(interactive_playground PRIVATE
    interactive_playground_scene InterActive::Foundation Qt6::Quick Qt6::Gui)
set_target_properties(interactive_playground PROPERTIES
    OUTPUT_NAME interactive-playground)
# The gallery and its generated plugin are deliberately not installed.
