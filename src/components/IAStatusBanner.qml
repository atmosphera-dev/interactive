// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import InterActive
import InterActive.Foundation as IA

IAPane {
    id: root
    property string title: ""
    property string message: ""
    property int validation: IA.Presentation.None

    backgroundColor: validation === IA.Presentation.Invalid ? IA.Appearance.colors.errorSurface
        : validation === IA.Presentation.Warning ? IA.Appearance.colors.warningSurface
        : IA.Appearance.colors.canvas
    contentItem: ColumnLayout {
        spacing: IA.Appearance.metrics.spacingXS
        IALabel {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.title
            fontWeight: IA.Appearance.typography.emphasisWeight
            wrapMode: Text.Wrap
        }
        IALabel {
            Layout.fillWidth: true
            text: root.message
            foregroundColor: root.validation === IA.Presentation.Invalid ? IA.Appearance.colors.errorText
                : root.validation === IA.Presentation.Warning ? IA.Appearance.colors.warningText
                : IA.Appearance.colors.secondaryText
            wrapMode: Text.Wrap
        }
    }
}
