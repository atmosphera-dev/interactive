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
    Component { id: checkComponent; IACheckBox {} }
    Component { id: radioComponent; IARadioButton {} }
    Component { id: switchComponent; IASwitch {} }
    TestCase {
        name: "PressedStatePairs"
        when: windowShown

        function init(): void { IA.Appearance.input = {}; }

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
                verify(ratio >= 5, "Rendered selected foreground/black contrast (full/RGB8): " + ratio);
            }
        }

        function test_pressedCheckedPair_data(): var {
            return [
                {tag: "button", component: buttonComponent, choice: false},
                {tag: "check", component: checkComponent, choice: true},
                {tag: "partialCheck", component: checkComponent, choice: true, partial: true},
                {tag: "radio", component: radioComponent, choice: true},
                {tag: "switch", component: switchComponent, choice: true}
            ];
        }

        function test_pressedCheckedPair(data: var): void {
            const control = createTemporaryObject(data.component, scene, {
                x: 40, y: 40, width: 200, height: 50, text: "Selected",
                checkable: true, checked: true,
                backgroundColor: "#eeeeee", foregroundColor: "#111111",
                pressedBackgroundColor: "#dddddd", selectedBackgroundColor: "#000000",
                inactiveBackgroundColor: "#000000"
            }) as T.AbstractButton;
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
                compare(background.color, "#dddddd");
                compare(foreground.color, "#111111", "Pressed visual uses the foreground paired with the pressed surface");
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
