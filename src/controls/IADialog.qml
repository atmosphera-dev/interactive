// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Templates as T
import InterActive.Foundation as IA

T.Dialog {
    id: control
    property alias backgroundColor: appearance.backgroundColor
    property alias foregroundColor: appearance.foregroundColor
    property alias borderColor: appearance.borderColor
    property alias disabledBorderColor: appearance.disabledBorderColor
    property alias focusColor: appearance.focusColor
    property alias controlRadius: appearance.controlRadius
    property alias fontFamily: appearance.fontFamily
    property alias fontPixelSize: appearance.fontPixelSize
    property alias fontWeight: appearance.fontWeight
    readonly property alias appearanceDiagnostics: appearance.diagnostics
    function resetAppearance(): void { appearance.resetOverrides(); }
    IA.ControlAppearance { id: appearance; source: IA.Appearance; family: "popup" }
    implicitWidth: Math.max(implicitContentWidth + leftPadding + rightPadding,
                            implicitHeaderWidth, implicitFooterWidth, IA.Appearance.metrics.menuMinWidth)
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
                    + implicitHeaderHeight + implicitFooterHeight
                    + (implicitHeaderHeight > 0 ? spacing : 0) + (implicitFooterHeight > 0 ? spacing : 0)
    horizontalPadding: appearance.horizontalPadding
    verticalPadding: appearance.verticalPadding
    spacing: appearance.spacing
    margins: IA.Appearance.metrics.spacingS
    font: appearance.resolvedFont
    popupType: T.Popup.Item
    header: IALabel {
        objectName: "iaTitle"
        visible: control.title.length > 0
        text: control.title
        fontFamily: control.fontFamily
        fontPixelSize: control.fontPixelSize
        fontWeight: control.fontWeight
        foregroundColor: control.foregroundColor
        leftPadding: control.leftPadding
        rightPadding: control.rightPadding
        topPadding: control.topPadding
        elide: Text.ElideRight
    }
    contentItem: Item { }
    // T.Dialog connects this template footer and forwards standardButtons itself.
    footer: IADialogButtonBox {
        objectName: "iaDialogButtons"
        visible: count > 0
        // The dialog owns the complete surface and outline, including beneath the footer.
        background: null
        fontFamily: control.fontFamily
        fontPixelSize: control.fontPixelSize
        fontWeight: control.fontWeight
    }
    background: IA.ControlBackground { resolvedAppearance: appearance }
    T.Overlay.modal: Rectangle { color: IA.Appearance.colors.scrim }
    T.Overlay.modeless: Rectangle { color: IA.Appearance.colors.scrim }
}
