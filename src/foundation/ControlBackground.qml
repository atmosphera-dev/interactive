// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick

Rectangle {
    id: root
    required property ControlAppearance resolvedAppearance
    property bool controlEnabled: true
    property bool down: false
    property bool hovered: false
    property bool selected: false
    property bool active: true
    property bool focused: false
    property bool outlined: true
    property bool pressInset: false
    property real focusInset: -Appearance.metrics.focusWidth
    readonly property bool showsPressedFill: down && !pressInset
    readonly property real contentShift: pressInset && down && controlEnabled ? Appearance.metrics.pressContentShift : 0
    readonly property color foregroundColor: !controlEnabled ? resolvedAppearance.disabledForegroundColor
        : showsPressedFill ? resolvedAppearance.foregroundColor
        : selected ? (active ? resolvedAppearance.selectedForegroundColor : resolvedAppearance.inactiveForegroundColor)
        : resolvedAppearance.foregroundColor
    objectName: "iaBackground"
    radius: resolvedAppearance.controlRadius
    color: !controlEnabled ? resolvedAppearance.disabledBackgroundColor
         : showsPressedFill ? resolvedAppearance.pressedBackgroundColor
         : selected ? (active ? resolvedAppearance.selectedBackgroundColor : resolvedAppearance.inactiveBackgroundColor)
         : hovered ? resolvedAppearance.hoverBackgroundColor : resolvedAppearance.backgroundColor
    border.color: controlEnabled ? resolvedAppearance.borderColor : resolvedAppearance.disabledBorderColor
    border.width: outlined ? Appearance.metrics.borderWidth : 0
    Rectangle {
        id: inset
        objectName: "iaPressInset"
        anchors.fill: parent
        anchors.margins: root.border.width
        radius: Math.max(0, root.radius - root.border.width)
        visible: root.pressInset && root.down && root.controlEnabled
        Accessible.ignored: true
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, Appearance.motion.pressInsetOpacity) }
            GradientStop {
                position: Math.min(0.5, Appearance.metrics.pressInsetDepth / Math.max(1, inset.height))
                color: Appearance.colors.transparent
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: root.focusInset
        visible: root.focused
        color: Appearance.colors.transparent
        radius: Math.max(0, root.radius - root.focusInset)
        border.color: root.resolvedAppearance.focusColor
        border.width: Appearance.metrics.focusWidth
    }
}
