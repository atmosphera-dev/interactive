// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Templates as T
import InterActive.Foundation as IA

T.ScrollBar {
    id: control
    property alias backgroundColor: appearance.backgroundColor
    property alias foregroundColor: appearance.foregroundColor
    property alias hoverBackgroundColor: appearance.hoverBackgroundColor
    property alias pressedBackgroundColor: appearance.pressedBackgroundColor
    property alias disabledForegroundColor: appearance.disabledForegroundColor
    property alias controlRadius: appearance.controlRadius
    readonly property alias appearanceDiagnostics: appearance.diagnostics
    function resetAppearance(): void { appearance.resetOverrides(); }
    IA.ControlAppearance { id: appearance; source: IA.Appearance; family: "tool" }
    implicitWidth: horizontal ? IA.Appearance.metrics.scrollBarMinimumLength : IA.Appearance.metrics.scrollBarWidth
    implicitHeight: horizontal ? IA.Appearance.metrics.scrollBarWidth : IA.Appearance.metrics.scrollBarMinimumLength
    minimumSize: Math.min(1, IA.Appearance.metrics.scrollBarMinimumLength / Math.max(1, horizontal ? availableWidth : availableHeight))
    hoverEnabled: true
    visible: policy !== T.ScrollBar.AlwaysOff && (policy === T.ScrollBar.AlwaysOn || size < 1)
    contentItem: Rectangle {
        objectName: "iaThumb"
        implicitWidth: IA.Appearance.metrics.scrollBarWidth
        implicitHeight: IA.Appearance.metrics.scrollBarWidth
        radius: control.controlRadius
        color: !control.enabled ? control.disabledForegroundColor : control.foregroundColor
    }
    background: Rectangle {
        objectName: "iaTrack"
        radius: control.controlRadius
        color: control.pressed ? control.pressedBackgroundColor
             : control.hovered ? control.hoverBackgroundColor : control.backgroundColor
    }
}
