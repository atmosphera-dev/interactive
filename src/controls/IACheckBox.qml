// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Templates as T
import InterActive.Foundation as IA

T.CheckBox {
    id: control
    property alias backgroundColor: appearance.backgroundColor
    property alias foregroundColor: appearance.foregroundColor
    property alias hoverBackgroundColor: appearance.hoverBackgroundColor
    property alias pressedBackgroundColor: appearance.pressedBackgroundColor
    property alias disabledBackgroundColor: appearance.disabledBackgroundColor
    property alias disabledForegroundColor: appearance.disabledForegroundColor
    property alias selectedBackgroundColor: appearance.selectedBackgroundColor
    property alias selectedForegroundColor: appearance.selectedForegroundColor
    property alias inactiveBackgroundColor: appearance.inactiveBackgroundColor
    property alias inactiveForegroundColor: appearance.inactiveForegroundColor
    property alias borderColor: appearance.borderColor
    property alias disabledBorderColor: appearance.disabledBorderColor
    property alias focusColor: appearance.focusColor
    property alias controlRadius: appearance.controlRadius
    property alias fontFamily: appearance.fontFamily
    property alias fontPixelSize: appearance.fontPixelSize
    property alias fontWeight: appearance.fontWeight
    property alias minimumHeight: appearance.minimumHeight
    readonly property alias appearanceDiagnostics: appearance.diagnostics
    function resetAppearance(): void { appearance.resetOverrides(); }
    IA.ControlAppearance { id: appearance; source: IA.Appearance; family: "choice" }
    implicitWidth: Math.max(implicitContentWidth + leftPadding + rightPadding, minimumHeight)
    implicitHeight: Math.max(Math.max(implicitContentHeight, implicitIndicatorHeight) + topPadding + bottomPadding, minimumHeight)
    horizontalPadding: appearance.verticalPadding
    verticalPadding: appearance.verticalPadding
    spacing: appearance.spacing
    font: appearance.resolvedFont
    hoverEnabled: true
    indicator: IA.ChoiceIndicator {
        id: mark
        resolvedAppearance: appearance
        checked: control.checkState === Qt.Checked
        partial: control.checkState === Qt.PartiallyChecked
        controlEnabled: control.enabled
        down: control.down
        hovered: control.hovered
        active: control.Window.active
        x: control.mirrored ? control.width - control.rightPadding - width : control.leftPadding
        anchors.verticalCenter: control.verticalCenter
    }
    contentItem: Text {
        objectName: "iaLabel"
        LayoutMirroring.enabled: false
        leftPadding: !control.mirrored ? mark.width + (control.text.length ? control.spacing : 0) : 0
        rightPadding: control.mirrored ? mark.width + (control.text.length ? control.spacing : 0) : 0
        text: control.text
        font: control.font
        color: appearance.stateTable.colors(IA.ControlState.of(control.enabled, false, false, false, true, false)).foregroundColor
        textFormat: Text.PlainText
        elide: Text.ElideRight
        horizontalAlignment: control.mirrored ? Text.AlignRight : Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
    }
    background: IA.ControlBackground {
        resolvedAppearance: appearance
        color: IA.Appearance.colors.transparent
        outlined: false
        focused: control.visualFocus
    }
}
