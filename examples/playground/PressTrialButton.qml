// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import InterActive
import InterActive.Foundation as IA

// Temporary pressed-look trial; removed once a look is chosen.
IAButton {
    id: control
    property bool keepPressedColor: true

    Binding {
        target: control
        property: "pressedBackgroundColor"
        value: control.backgroundColor
        when: !control.keepPressedColor
    }

    contentItem.transform: Translate {
        y: control.down ? IA.Appearance.metrics.borderWidth : 0
    }

    Rectangle {
        id: inset
        anchors.fill: parent
        anchors.margins: IA.Appearance.metrics.borderWidth
        radius: Math.max(0, control.controlRadius - IA.Appearance.metrics.borderWidth)
        visible: control.down
        z: -0.5
        Accessible.ignored: true
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.28) }
            GradientStop {
                position: Math.min(0.5, IA.Appearance.metrics.spacingS / inset.height)
                color: IA.Appearance.colors.transparent
            }
        }
    }
}
