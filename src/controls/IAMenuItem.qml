// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import InterActive.Foundation as IA

T.MenuItem {
    id: control
    property int tone: IA.Presentation.Auto
    // The action owns shortcut activation; this is its optional human-readable label.
    property string shortcutText
    property alias backgroundColor: appearance.backgroundColor
    property alias foregroundColor: appearance.foregroundColor
    property alias hoverBackgroundColor: appearance.hoverBackgroundColor
    property alias pressedBackgroundColor: appearance.pressedBackgroundColor
    property alias disabledBackgroundColor: appearance.disabledBackgroundColor
    property alias disabledForegroundColor: appearance.disabledForegroundColor
    property alias selectedBackgroundColor: appearance.selectedBackgroundColor
    property alias selectedForegroundColor: appearance.selectedForegroundColor
    property alias inactiveBackgroundColor: appearance.inactiveBackgroundColor
    property alias inactiveForegroundColor: appearance.inactiveForegroundColor
    property alias borderColor: appearance.borderColor
    property alias disabledBorderColor: appearance.disabledBorderColor
    property alias focusColor: appearance.focusColor
    property alias controlRadius: appearance.controlRadius
    property alias fontFamily: appearance.fontFamily
    property alias fontPixelSize: appearance.fontPixelSize
    property alias fontWeight: appearance.fontWeight
    property alias minimumHeight: appearance.minimumHeight
    readonly property alias appearanceDiagnostics: appearance.diagnostics
    readonly property bool hasIcon: icon.name.length > 0 || icon.source.toString().length > 0
    readonly property bool showsIcon: hasIcon && display !== T.AbstractButton.TextOnly
    readonly property real leadingPadding: Math.max(implicitTextPadding, textPadding)
    function resetAppearance(): void { appearance.resetOverrides(); }
    IA.ControlAppearance { id: appearance; source: IA.Appearance; family: "delegate"; tone: control.tone }
    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: Math.max(implicitContentHeight + topPadding + bottomPadding, minimumHeight)
    implicitTextPadding: (checkable ? IA.Appearance.metrics.indicatorSize + spacing : 0)
                         + (showsIcon ? icon.width + spacing : 0)
    horizontalPadding: appearance.horizontalPadding
    verticalPadding: appearance.verticalPadding
    spacing: appearance.spacing
    font: appearance.resolvedFont
    hoverEnabled: true
    icon.width: IA.Appearance.metrics.iconSize
    icon.height: IA.Appearance.metrics.iconSize
    icon.color: surface.foregroundColor

    indicator: IA.Icon {
        objectName: "iaIndicator"
        visible: control.checkable && control.checked
        width: IA.Appearance.metrics.indicatorSize
        height: IA.Appearance.metrics.indicatorSize
        x: control.mirrored ? control.width - control.rightPadding - width : control.leftPadding
        anchors.verticalCenter: control.verticalCenter
        source: IA.Appearance.icons.check
        color: surface.foregroundColor
    }
    arrow: IA.Icon {
        id: submenuArrow
        objectName: "iaSubmenuArrow"
        visible: control.subMenu !== null
        width: IA.Appearance.metrics.iconSize
        height: IA.Appearance.metrics.iconSize
        x: control.mirrored ? control.leftPadding : control.width - control.rightPadding - width
        anchors.verticalCenter: control.verticalCenter
        source: IA.Appearance.icons.chevronRight
        color: surface.foregroundColor
        mirrored: control.mirrored
    }
    contentItem: Item {
        id: content
        LayoutMirroring.enabled: false
        LayoutMirroring.childrenInherit: true
        implicitWidth: control.leadingPadding + (label.visible ? label.implicitWidth : 0)
                       + (shortcut.visible ? shortcut.implicitWidth + control.spacing : 0)
                       + (submenuArrow.visible ? submenuArrow.width + control.spacing : 0)
        implicitHeight: Math.max(label.implicitHeight, shortcut.implicitHeight,
                                 control.showsIcon ? control.icon.height : 0,
                                 control.checkable ? IA.Appearance.metrics.indicatorSize : 0)
        IA.Icon {
            visible: control.showsIcon
            width: control.icon.width
            height: control.icon.height
            x: control.mirrored ? content.width - control.leadingPadding + control.spacing
                               : control.leadingPadding - control.spacing - width
            anchors.verticalCenter: parent.verticalCenter
            name: control.icon.name
            source: IA.IconSource.resolve(control, control.icon.source)
            color: control.icon.color
            cache: control.icon.cache
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: control.mirrored
                ? (submenuArrow.visible ? submenuArrow.width + control.spacing : 0) : control.leadingPadding
            anchors.rightMargin: control.mirrored ? control.leadingPadding
                : (submenuArrow.visible ? submenuArrow.width + control.spacing : 0)
            spacing: control.spacing
            layoutDirection: control.mirrored ? Qt.RightToLeft : Qt.LeftToRight
            Text {
                id: label
                objectName: "iaLabel"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: control.display !== T.AbstractButton.IconOnly
                text: control.text
                font: control.font
                color: surface.foregroundColor
                textFormat: Text.PlainText
                elide: Text.ElideRight
                horizontalAlignment: control.mirrored ? Text.AlignRight : Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                id: shortcut
                objectName: "iaShortcut"
                Layout.minimumWidth: 0
                visible: control.shortcutText.length > 0
                text: control.shortcutText
                font: control.font
                color: surface.foregroundColor
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
    background: IA.ControlBackground {
        id: surface
        resolvedAppearance: appearance
        controlEnabled: control.enabled
        down: control.down
        hovered: control.hovered
        selected: control.highlighted
        active: control.Window.active
        focused: control.visualFocus
        outlined: false
        focusInset: IA.Appearance.metrics.borderWidth
    }
}
