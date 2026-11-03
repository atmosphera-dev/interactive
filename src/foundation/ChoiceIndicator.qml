// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick

Rectangle {
    id: root
    enum Kind { Check, Radio, Toggle }
    required property ControlAppearance resolvedAppearance
    property int kind: ChoiceIndicator.Check
    property bool checked: false
    property bool partial: false
    property bool controlEnabled: true
    property bool down: false
    property bool hovered: false
    property bool active: true
    property real visualPosition: checked ? 1 : 0
    readonly property bool selected: checked || partial
    readonly property color markColor: !controlEnabled ? resolvedAppearance.disabledForegroundColor
        : down ? resolvedAppearance.foregroundColor
        : selected ? (active ? resolvedAppearance.selectedForegroundColor : resolvedAppearance.inactiveForegroundColor)
        : resolvedAppearance.foregroundColor
    objectName: "iaIndicator"
    implicitWidth: kind === ChoiceIndicator.Toggle ? Appearance.metrics.switchWidth : Appearance.metrics.indicatorSize
    implicitHeight: kind === ChoiceIndicator.Toggle ? Appearance.metrics.switchHeight : Appearance.metrics.indicatorSize
    radius: kind === ChoiceIndicator.Check ? resolvedAppearance.controlRadius : height / 2
    color: !controlEnabled ? resolvedAppearance.disabledBackgroundColor
         : down ? resolvedAppearance.pressedBackgroundColor
         : selected ? (active ? resolvedAppearance.selectedBackgroundColor : resolvedAppearance.inactiveBackgroundColor)
         : hovered ? resolvedAppearance.hoverBackgroundColor : resolvedAppearance.backgroundColor
    border.color: controlEnabled ? resolvedAppearance.borderColor : resolvedAppearance.disabledBorderColor
    border.width: Appearance.metrics.borderWidth
    Icon {
        anchors.fill: parent
        visible: root.kind === ChoiceIndicator.Check && root.selected
        source: root.partial ? Appearance.icons.minus : Appearance.icons.check
        color: root.markColor
    }
    Rectangle {
        anchors.centerIn: parent
        visible: root.kind === ChoiceIndicator.Radio && root.checked
        width: Math.max(0, root.width - 2 * Appearance.metrics.spacingXS)
        height: width
        radius: width / 2
        color: root.markColor
    }
    Rectangle {
        objectName: "iaThumb"
        anchors.verticalCenter: parent.verticalCenter
        visible: root.kind === ChoiceIndicator.Toggle
        width: Appearance.metrics.thumbSize
        height: width
        radius: width / 2
        x: root.border.width + root.visualPosition * Math.max(0, root.width - width - 2 * root.border.width)
        color: root.markColor
    }
}
