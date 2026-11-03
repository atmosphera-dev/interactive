// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Templates as T
import QtTest
import InterActive
import InterActive.Foundation as IA
import InterActive.Tests

Item {
    id: scene
    width: 400
    height: 200
    Component { id: buttonComponent; IAButton {} }
    Component { id: toolComponent; IAToolButton {} }
    Component { id: tabComponent; IATabButton {} }
    Component { id: delegateComponent; IAItemDelegate {} }
    Component { id: checkComponent; IACheckBox {} }
    Component { id: radioComponent; IARadioButton {} }
    Component { id: switchComponent; IASwitch {} }
    TestCase {
        name: "PressedStatePairs"
        when: windowShown

        function init(): void { IA.Appearance.input = {}; }

        function cleanup(): void {
            TestProbe.move(scene, scene.width - 2, scene.height - 2);
            TestProbe.release(scene, scene.width - 2, scene.height - 2);
            IA.Appearance.input = {};
        }

        function test_pressedInset_data(): var {
            const rows = [];
            const controls = [
                {name: "button", component: buttonComponent, inset: true},
                {name: "tool", component: toolComponent, inset: true},
                {name: "tab", component: tabComponent, inset: false},
                {name: "delegate", component: delegateComponent, inset: false}
            ];
            for (const scheme of ["light", "dark"]) {
                for (const customized of [false, true]) {
                    for (const control of controls)
                        rows.push({tag: scheme + "-" + control.name + "-" + customized,
                            scheme: scheme, component: control.component,
                            inset: control.inset, customized: customized});
                }
            }
            return rows;
        }

        function test_pressedInset(data: var): void {
            IA.Appearance.input = data.customized ? {scheme: data.scheme, reducedMotion: true,
                tokens: {metrics: {pressInsetDepth: 12, pressContentShift: 2},
                         motion: {pressInsetOpacity: 0.4}}} : {scheme: data.scheme};
            const control = createTemporaryObject(data.component, scene, {
                x: 40, y: 40, width: 200, height: 50, text: "Press"
            }) as T.AbstractButton;
            verify(control !== null);
            verify(TestProbe.render(control));
            verify(TestProbe.activate(control));
            verify(TestProbe.move(scene, scene.width - 2, scene.height - 2));
            tryCompare(control, "hovered", false);
            const background = control.background as IA.ControlBackground;
            const content = control.contentItem as IA.IconLabel;
            verify(background !== null && content !== null);
            const inset = findChild(background, "iaPressInset") as Rectangle;
            verify(inset !== null);
            compare(background.color, background.resolvedAppearance.backgroundColor);
            compare(inset.visible, false);
            compare(content.mapToItem(control, 0, 0).y - content.y, 0);
            const geometry = [control.width, control.height, control.implicitWidth, control.implicitHeight,
                content.x, content.y, content.implicitWidth, content.implicitHeight, content.baselineOffset];
            verify(TestProbe.move(control, control.width / 2, control.height / 2));
            tryCompare(control, "hovered", true);
            const hoverFill = background.color;
            compare(hoverFill, background.resolvedAppearance.hoverBackgroundColor);
            verify(TestProbe.press(control, control.width / 2, control.height / 2));
            try {
                tryCompare(control, "down", true);
                verify(TestProbe.render(control));
                compare(background.color, data.inset ? hoverFill : background.resolvedAppearance.pressedBackgroundColor);
                compare(inset.visible, data.inset);
                const shift = data.inset ? IA.Appearance.metrics.pressContentShift : 0;
                compare(content.contentShift, shift);
                fuzzyCompare(content.mapToItem(control, 0, 0).y - content.y, shift, 0.001);
                compare([control.width, control.height, control.implicitWidth, control.implicitHeight,
                    content.x, content.y, content.implicitWidth, content.implicitHeight, content.baselineOffset], geometry);
                if (data.inset) {
                    verify(background.color !== background.resolvedAppearance.pressedBackgroundColor);
                    compare(inset.x, background.border.width);
                    compare(inset.y, background.border.width);
                    compare(inset.radius, Math.max(0, background.radius - background.border.width));
                    const gradient = inset.gradient as Gradient;
                    verify(gradient !== null);
                    compare(gradient.stops.length, 2);
                    compare(gradient.stops[0].position, 0);
                    compare(gradient.stops[0].color, Qt.rgba(0, 0, 0, IA.Appearance.motion.pressInsetOpacity));
                    compare(gradient.stops[1].position,
                        Math.min(0.5, IA.Appearance.metrics.pressInsetDepth / Math.max(1, inset.height)));
                    compare(gradient.stops[1].color, IA.Appearance.colors.transparent);
                    // A held inset button follows its actual hover state, never the pressed fill.
                    compare(background.color, control.hovered
                        ? background.resolvedAppearance.hoverBackgroundColor
                        : background.resolvedAppearance.backgroundColor);
                    if (data.customized) {
                        control.enabled = false;
                        verify(TestProbe.render(control));
                        compare(inset.visible, false);
                        compare(content.contentShift, 0);
                        compare(background.color, background.resolvedAppearance.disabledBackgroundColor);
                    }
                }
            } finally {
                TestProbe.move(scene, scene.width - 2, scene.height - 2);
                TestProbe.release(scene, scene.width - 2, scene.height - 2);
            }
            tryCompare(control, "down", false);
            verify(TestProbe.render(control));
            compare(inset.visible, false);
            compare(content.contentShift, 0);
            fuzzyCompare(content.mapToItem(control, 0, 0).y - content.y, 0, 0.001);
        }

        function verifySelectedForeground(control: var, foreground: color): void {
            compare(foreground, TestProbe.hostWindow(control).active
                    ? control.selectedForegroundColor : control.inactiveForegroundColor,
                    "Actual selected mark/text uses the resolved foreground for the window state");
            compare(foreground.a, 1);
            compare(foreground.r, foreground.g, "A black seed retains a neutral foreground");
            compare(foreground.g, foreground.b, "A black seed retains a neutral foreground");
            // The asserted surface is opaque black and all foreground channels are equal.
            for (const channel of [foreground.r, Math.round(foreground.r * 255) / 255]) {
                const luminance = channel <= 0.04045 ? channel / 12.92
                    : Math.pow((channel + 0.055) / 1.055, 2.4);
                const ratio = (luminance + 0.05) / 0.05;
                verify(ratio >= 7, "Rendered selected foreground/black meets the label target (full/RGB8): " + ratio);
            }
        }

        function test_pressedCheckedPair_data(): var {
            return [
                {tag: "button", component: buttonComponent, choice: false, inset: true},
                {tag: "tool", component: toolComponent, choice: false, inset: true},
                {tag: "tab", component: tabComponent, choice: false},
                {tag: "delegate", component: delegateComponent, choice: false},
                {tag: "check", component: checkComponent, choice: true},
                {tag: "partialCheck", component: checkComponent, choice: true, partial: true},
                {tag: "radio", component: radioComponent, choice: true},
                {tag: "switch", component: switchComponent, choice: true}
            ];
        }

        function test_pressedCheckedPair(data: var): void {
            const properties = {
                x: 40, y: 40, width: 200, height: 50, text: "Selected",
                checkable: true, checked: true,
                backgroundColor: "#eeeeee", foregroundColor: "#111111",
                selectedBackgroundColor: "#000000",
                inactiveBackgroundColor: "#000000"
            };
            if (!data.inset)
                properties.pressedBackgroundColor = "#dddddd";
            const control = createTemporaryObject(data.component, scene, properties) as T.AbstractButton;
            verify(control !== null);
            if (data.partial)
                (control as IACheckBox).checkState = Qt.PartiallyChecked;
            verify(TestProbe.render(control));
            verify(TestProbe.activate(control));
            const background = (data.choice ? control.indicator : control.background) as Rectangle;
            verify(background !== null);
            let foreground = null;
            if (!data.choice) {
                foreground = findChild(control, "iaLabel") as Text;
            } else {
                for (const child of control.indicator.children) {
                    if (child.visible && (child instanceof Rectangle || child instanceof IA.Icon))
                        foreground = child;
                }
            }
            verify(foreground !== null);
            compare(background.color, "#000000");
            verifySelectedForeground(control, foreground.color);
            verify(TestProbe.press(control, control.width / 2, control.height / 2));
            try {
                tryCompare(control, "down", true);
                verify(TestProbe.render(control));
                compare(background.color, data.inset ? "#000000" : "#dddddd");
                const inset = findChild(control.background, "iaPressInset") as Rectangle;
                verify(inset !== null);
                compare(inset.visible, Boolean(data.inset));
                if (data.inset)
                    verifySelectedForeground(control, foreground.color);
                else
                    compare(foreground.color, "#111111", "Pressed fill retains its paired foreground");
            } finally {
                TestProbe.move(scene, scene.width - 2, scene.height - 2);
                TestProbe.release(scene, scene.width - 2, scene.height - 2);
            }
            tryCompare(control, "down", false);
            verify(TestProbe.render(control));
            // Native Switch keeps its press outside the bounds and toggles on release.
            if (control instanceof IASwitch) {
                compare(control.checked, false);
                compare(background.color, "#eeeeee");
                compare(foreground.color, "#111111");
            } else {
                compare(background.color, "#000000");
                verifySelectedForeground(control, foreground.color);
            }
        }
    }
}
