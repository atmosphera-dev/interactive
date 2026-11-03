// SPDX-License-Identifier: LGPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import InterActive.Foundation as IA

T.DialogButtonBox {
    id: control
    property alias backgroundColor: appearance.backgroundColor
    property alias foregroundColor: appearance.foregroundColor
    property alias controlRadius: appearance.controlRadius
    property alias fontFamily: appearance.fontFamily
    property alias fontPixelSize: appearance.fontPixelSize
    property alias fontWeight: appearance.fontWeight
    readonly property alias appearanceDiagnostics: appearance.diagnostics
    function resetAppearance(): void { appearance.resetOverrides(); }
    readonly property IA.ControlAppearance _appearance: IA.ControlAppearance { id: appearance; source: IA.Appearance; family: "surface" }
    implicitWidth: contentWidth + leftPadding + rightPadding
    implicitHeight: contentHeight + topPadding + bottomPadding
    horizontalPadding: appearance.horizontalPadding
    verticalPadding: appearance.verticalPadding
    spacing: appearance.spacing
    font: appearance.resolvedFont
    alignment: Qt.AlignRight
    delegate: IAButton {
        fontFamily: control.fontFamily
        fontPixelSize: control.fontPixelSize
        fontWeight: control.fontWeight
        tone: T.DialogButtonBox.buttonRole === T.DialogButtonBox.AcceptRole
              || T.DialogButtonBox.buttonRole === T.DialogButtonBox.YesRole ? IA.Presentation.Primary
            : T.DialogButtonBox.buttonRole === T.DialogButtonBox.DestructiveRole ? IA.Presentation.Destructive
            : IA.Presentation.Neutral
    }
    contentItem: ListView {
        model: control.contentModel
        spacing: control.spacing
        orientation: ListView.Horizontal
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
    }
    background: IA.ControlBackground {
        resolvedAppearance: appearance
        outlined: false
    }
}
