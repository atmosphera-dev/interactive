// SPDX-License-Identifier: LGPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import InterActive.Foundation as IA

T.DialogButtonBox {
    id: control
    // -1 selects automatically; NoButton explicitly removes primary emphasis.
    // This is visual prominence only, not Qt's default/keyboard action.
    property int principalAction: -1
    readonly property int _principalAction: {
        if (principalAction !== -1)
            return principalAction;
        // Stable priority independent of the platform's visual button ordering.
        const completions = [T.DialogButtonBox.Ok, T.DialogButtonBox.Open,
            T.DialogButtonBox.Save, T.DialogButtonBox.SaveAll, T.DialogButtonBox.Retry,
            T.DialogButtonBox.Ignore, T.DialogButtonBox.Yes, T.DialogButtonBox.YesToAll,
            T.DialogButtonBox.Apply];
        for (const action of completions) {
            if (standardButtons & action)
                return action;
        }
        return T.DialogButtonBox.NoButton;
    }
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
    // The same row owns actual button extents and the aligned layout width.
    contentWidth: buttonRow.contentWidth
    horizontalPadding: appearance.horizontalPadding
    verticalPadding: appearance.verticalPadding
    spacing: appearance.spacing
    font: appearance.resolvedFont
    alignment: Qt.AlignRight
    delegate: IAButton {
        id: button
        fontFamily: control.fontFamily
        fontPixelSize: control.fontPixelSize
        fontWeight: control.fontWeight
        tone: {
            const role = T.DialogButtonBox.buttonRole;
            if (role === T.DialogButtonBox.DestructiveRole)
                return IA.Presentation.Destructive;
            const completion = role === T.DialogButtonBox.AcceptRole
                || role === T.DialogButtonBox.YesRole || role === T.DialogButtonBox.ApplyRole;
            // Qt publishes standardButtons after constructing all delegates.
            // Observe it even for an explicit (unchanged) principal choice.
            return completion && (control.standardButtons & control._principalAction) !== 0
                && control.count > 0
                && control.standardButton(control._principalAction) === button
                ? IA.Presentation.Primary : IA.Presentation.Neutral;
        }
    }
    contentItem: ListView {
        id: buttonRow
        implicitWidth: contentWidth
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
