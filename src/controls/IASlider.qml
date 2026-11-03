// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Templates as T
import InterActive.Foundation as IA

T.Slider {
    id: control
    property alias backgroundColor: appearance.backgroundColor
    property alias foregroundColor: appearance.foregroundColor
    property alias hoverBackgroundColor: appearance.hoverBackgroundColor
    property alias pressedBackgroundColor: appearance.pressedBackgroundColor
    property alias disabledBackgroundColor: appearance.disabledBackgroundColor
    property alias disabledForegroundColor: appearance.disabledForegroundColor
    property alias borderColor: appearance.borderColor
    property alias disabledBorderColor: appearance.disabledBorderColor
    property alias focusColor: appearance.focusColor
    property alias controlRadius: appearance.controlRadius
    property alias minimumHeight: appearance.minimumHeight
    property alias fillColor: appearance.fillColor
    readonly property alias appearanceDiagnostics: appearance.diagnostics
    function resetAppearance(): void { appearance.resetOverrides(); }
    IA.ControlAppearance { id: appearance; source: IA.Appearance; family: "button" }
    implicitWidth: Math.max(horizontal ? IA.Appearance.metrics.sliderLength : minimumHeight,
                            implicitHandleWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(horizontal ? minimumHeight : IA.Appearance.metrics.sliderLength,
                             implicitHandleHeight + topPadding + bottomPadding)
    horizontalPadding: appearance.verticalPadding
    verticalPadding: appearance.verticalPadding
    hoverEnabled: true

    background: Item {
        id: lane
        x: control.leftPadding
        y: control.topPadding
        width: control.availableWidth
        height: control.availableHeight
        Rectangle {
            id: track
            objectName: "iaTrack"
            anchors.centerIn: parent
            width: control.horizontal ? Math.max(0, lane.width - thumb.width) : IA.Appearance.metrics.trackHeight
            height: control.horizontal ? IA.Appearance.metrics.trackHeight : Math.max(0, lane.height - thumb.height)
            radius: Math.min(width, height) / 2
            color: control.enabled ? control.borderColor : control.disabledBackgroundColor
            Rectangle {
                objectName: "iaFill"
                width: control.horizontal ? track.width * control.position : track.width
                height: control.horizontal ? track.height : track.height * control.position
                x: control.horizontal && control.mirrored ? track.width - width : 0
                y: control.horizontal ? 0 : track.height - height
                radius: track.radius
                color: control.enabled ? control.fillColor : control.disabledForegroundColor
            }
        }
    }
    handle: IA.ControlBackground {
        id: thumb
        objectName: "iaThumb"
        resolvedAppearance: appearance
        implicitWidth: IA.Appearance.metrics.sliderThumbSize
        implicitHeight: IA.Appearance.metrics.sliderThumbSize
        radius: width / 2
        controlEnabled: control.enabled
        down: control.pressed
        hovered: control.hovered
        focused: control.visualFocus
        anchors.verticalCenter: control.horizontal ? lane.verticalCenter : undefined
        anchors.horizontalCenter: control.horizontal ? undefined : lane.horizontalCenter
        x: control.leftPadding + control.visualPosition * Math.max(0, control.availableWidth - width)
        y: control.topPadding + control.visualPosition * Math.max(0, control.availableHeight - height)
    }
}
