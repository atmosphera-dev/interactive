// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Templates as T
import InterActive.Foundation as IA

T.TabBar {
    id: control
    property alias backgroundColor: appearance.backgroundColor
    property alias borderColor: appearance.borderColor
    property alias disabledBorderColor: appearance.disabledBorderColor
    property alias controlRadius: appearance.controlRadius
    property alias fontFamily: appearance.fontFamily
    property alias fontPixelSize: appearance.fontPixelSize
    property alias fontWeight: appearance.fontWeight
    readonly property alias appearanceDiagnostics: appearance.diagnostics
    function resetAppearance(): void { appearance.resetOverrides(); }
    readonly property IA.ControlAppearance _appearance: IA.ControlAppearance { id: appearance; source: IA.Appearance; family: "surface" }
    implicitWidth: contentWidth + leftPadding + rightPadding
    implicitHeight: contentHeight + topPadding + bottomPadding
    spacing: appearance.spacing
    font: appearance.resolvedFont
    contentItem: ListView {
        model: control.contentModel
        currentIndex: control.currentIndex
        orientation: ListView.Horizontal
        spacing: control.spacing
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.AutoFlickIfNeeded
        snapMode: ListView.SnapToItem
        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: 0
        preferredHighlightBegin: 0
        preferredHighlightEnd: width
        clip: true
    }
    background: IA.ControlBackground {
        resolvedAppearance: appearance
        outlined: false
    }
}
