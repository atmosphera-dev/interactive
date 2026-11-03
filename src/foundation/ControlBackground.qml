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
    property real focusInset: -Appearance.metrics.focusWidth
    readonly property color foregroundColor: !controlEnabled ? resolvedAppearance.disabledForegroundColor
        : down ? resolvedAppearance.foregroundColor
        : selected ? (active ? resolvedAppearance.selectedForegroundColor : resolvedAppearance.inactiveForegroundColor)
        : resolvedAppearance.foregroundColor
    objectName: "iaBackground"
    radius: resolvedAppearance.controlRadius
    color: !controlEnabled ? resolvedAppearance.disabledBackgroundColor
         : down ? resolvedAppearance.pressedBackgroundColor
         : selected ? (active ? resolvedAppearance.selectedBackgroundColor : resolvedAppearance.inactiveBackgroundColor)
         : hovered ? resolvedAppearance.hoverBackgroundColor : resolvedAppearance.backgroundColor
    border.color: controlEnabled ? resolvedAppearance.borderColor : resolvedAppearance.disabledBorderColor
    border.width: outlined ? Appearance.metrics.borderWidth : 0
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
