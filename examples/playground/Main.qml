// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import InterActive
import InterActive.Foundation as IA

Window {
    id: window
    objectName: "playgroundWindow"
    width: 1200
    height: 820
    minimumWidth: 320
    minimumHeight: 320
    visible: true
    title: "InterActive / Foundations"
    color: IA.Appearance.colors.canvas

    property string initialScene: "default"
    property bool windowPopups: false
    property bool rightToLeft: false
    property bool startupDispatched: false
    readonly property Item activePopupContent: gallery.activePopupContent
    readonly property list<Item> openPopupContents: gallery.openPopupContents
    readonly property bool sceneReady: startupDispatched
        && (initialScene === "menu" ? gallery.menuOpen
            : initialScene === "dialog" ? gallery.dialogOpen : true)
    signal observationChanged()
    onActivePopupContentChanged: observationChanged()
    onOpenPopupContentsChanged: observationChanged()
    onSceneReadyChanged: observationChanged()

    function openMenu(): void { gallery.openMenu(); }
    function openDialog(): void { gallery.openDialog(); }

    // The launcher calls this only after the native parent is active and exposed.
    function startScene(): void {
        if (!startupDispatched && visible && active) {
            startupDispatched = true;
            if (initialScene === "menu")
                openMenu();
            else if (initialScene === "dialog")
                openDialog();
        }
    }

    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: window.rightToLeft
        LayoutMirroring.childrenInherit: true
        RowLayout {
            anchors.fill: parent
            spacing: 0
            IAPane {
                visible: window.width >= 1000
                Layout.preferredWidth: 176
                Layout.fillHeight: true
                backgroundColor: IA.Appearance.colors.inverseSurface
                contentItem: ColumnLayout {
                    spacing: IA.Appearance.metrics.spacingS
                    IALabel {
                        Layout.fillWidth: true
                        text: "InterActive"
                        fontPixelSize: IA.Appearance.typography.headingSize
                        fontWeight: IA.Appearance.typography.emphasisWeight
                        foregroundColor: IA.Appearance.colors.inverseText
                        wrapMode: Text.Wrap
                    }
                    IALabel {
                        Layout.fillWidth: true
                        text: "Control workbench"
                        foregroundColor: IA.Appearance.colors.inverseSecondary
                        fontPixelSize: IA.Appearance.typography.supportingSize
                        wrapMode: Text.Wrap
                    }
                    IAItemDelegate {
                        Layout.fillWidth: true
                        text: "Foundations"
                        highlighted: true
                        // This explicit inverse subpalette is local, not a
                        // second appearance source for the application.
                        foregroundColor: IA.Appearance.colors.inverseText
                        selectedForegroundColor: IA.Appearance.colors.inverseText
                        selectedBackgroundColor: IA.Appearance.colors.inverseSurface
                        inactiveForegroundColor: IA.Appearance.colors.inverseText
                        inactiveBackgroundColor: IA.Appearance.colors.inverseSurface
                        backgroundColor: IA.Appearance.colors.inverseSurface
                        fontWeight: IA.Appearance.typography.emphasisWeight
                    }
                    Repeater {
                        model: ["Actions", "Forms", "Values", "Lists", "Overlays"]
                        IAItemDelegate {
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            enabled: false
                            backgroundColor: IA.Appearance.colors.inverseSurface
                            disabledBackgroundColor: IA.Appearance.colors.inverseSurface
                            disabledForegroundColor: IA.Appearance.colors.inverseSecondary
                        }
                    }
                    Item { Layout.fillHeight: true }
                    IALabel {
                        Layout.fillWidth: true
                        text: "First overview\nOther pages unavailable until visual review."
                        foregroundColor: IA.Appearance.colors.inverseSecondary
                        fontPixelSize: IA.Appearance.typography.supportingSize
                        wrapMode: Text.Wrap
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0
                IAToolBar {
                    Layout.fillWidth: true
                    contentItem: AppearanceEditor {}
                }
                FoundationsPage {
                    id: gallery
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    windowPopups: window.windowPopups
                }
            }
        }
    }
}
