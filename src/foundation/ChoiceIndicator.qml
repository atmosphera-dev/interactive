// SPDX-License-Identifier: LGPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: root
    enum Kind { Check, Radio, Toggle }
    required property ControlAppearance resolvedAppearance
    property int kind: ChoiceIndicator.Check
    property bool checked: false
    property bool partial: false
    property bool controlEnabled: true
    property bool down: false
    property bool hovered: false
    property bool active: true
    property real visualPosition: checked ? 1 : 0
    readonly property bool selected: checked || partial
    readonly property stateColors colors: resolvedAppearance.stateTable.colors(
        ControlState.of(controlEnabled, down, hovered, selected, active, false))
    readonly property color markColor: colors.foregroundColor
    objectName: "iaIndicator"
    implicitWidth: kind === ChoiceIndicator.Toggle ? Appearance.metrics.switchWidth : Appearance.metrics.indicatorSize
    implicitHeight: kind === ChoiceIndicator.Toggle ? Appearance.metrics.switchHeight : Appearance.metrics.indicatorSize
    radius: kind === ChoiceIndicator.Check ? resolvedAppearance.controlRadius : height / 2
    color: colors.backgroundColor
    border.color: colors.borderColor
    border.width: Appearance.metrics.borderWidth
    property bool complete: false
    property Item mark: null
    function updateMark(): void {
        if (!complete)
            return;
        if (mark) {
            mark.visible = false;
            mark.destroy();
            mark = null;
        }
        const component = kind === ChoiceIndicator.Check ? checkComponent
            : kind === ChoiceIndicator.Radio ? radioComponent
            : kind === ChoiceIndicator.Toggle ? toggleComponent : null;
        if (component) {
            mark = component.createObject(root) as Item;
            if (!mark)
                throw new Error(component.errorString());
        }
    }
    Component.onCompleted: { complete = true; updateMark(); }
    onKindChanged: updateMark()
    Component {
        id: checkComponent
        Icon {
            anchors.fill: parent
            visible: root.selected
            source: root.partial ? Appearance.icons.minus : Appearance.icons.check
            color: root.markColor
        }
    }
    Component {
        id: radioComponent
        Rectangle {
            anchors.centerIn: parent
            visible: root.checked
            width: Math.max(0, root.width - 2 * Appearance.metrics.spacingXS)
            height: width
            radius: width / 2
            color: root.markColor
        }
    }
    Component {
        id: toggleComponent
        Rectangle {
            objectName: "iaThumb"
            anchors.verticalCenter: parent.verticalCenter
            width: Appearance.metrics.thumbSize
            height: width
            radius: width / 2
            // Square slot of the track height: equal gap on every facing edge.
            x: (root.height - height) / 2 + root.visualPosition * Math.max(0, root.width - root.height)
            color: root.markColor
        }
    }
}
