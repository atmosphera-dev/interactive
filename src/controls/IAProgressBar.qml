// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Templates as T
import InterActive.Foundation as IA

T.ProgressBar {
    id: control
    property alias backgroundColor: appearance.backgroundColor
    property alias foregroundColor: appearance.foregroundColor
    property alias disabledBackgroundColor: appearance.disabledBackgroundColor
    property alias disabledForegroundColor: appearance.disabledForegroundColor
    property alias controlRadius: appearance.controlRadius
    property alias fillColor: appearance.fillColor
    readonly property alias appearanceDiagnostics: appearance.diagnostics
    function resetAppearance(): void { appearance.resetOverrides(); }
    IA.ControlAppearance { id: appearance; source: IA.Appearance; family: "button" }
    implicitWidth: IA.Appearance.metrics.progressWidth
    implicitHeight: IA.Appearance.metrics.progressHeight + topPadding + bottomPadding
    contentItem: Item {
        id: lane
        clip: true
        Rectangle {
            objectName: "iaFill"
            visible: !control.indeterminate
            width: lane.width * control.position
            height: lane.height
            x: control.mirrored ? lane.width - width : 0
            radius: control.controlRadius
            color: control.enabled ? control.fillColor : control.disabledForegroundColor
        }
        Rectangle {
            id: busy
            property real phase: 0
            objectName: "iaBusySegment"
            visible: control.indeterminate
            width: Math.min(lane.width, IA.Appearance.metrics.busySize)
            height: lane.height
            radius: control.controlRadius
            color: control.enabled ? control.fillColor : control.disabledForegroundColor
            // A centered segment remains distinct from a zero or complete value without motion.
            x: IA.Appearance.reducedMotion || IA.Appearance.motion.busyDuration === 0 ? (lane.width - width) / 2
                : (control.mirrored ? 1 - phase : phase) * (lane.width + width) - width
            NumberAnimation {
                target: busy
                property: "phase"
                from: 0
                to: 1
                duration: IA.Appearance.motion.busyDuration
                running: control.indeterminate && control.visible && control.enabled
                         && !IA.Appearance.reducedMotion && IA.Appearance.motion.busyDuration > 0
                loops: Animation.Infinite
            }
        }
    }
    background: Rectangle {
        objectName: "iaBackground"
        color: control.enabled ? control.backgroundColor : control.disabledBackgroundColor
        radius: control.controlRadius
    }
}
