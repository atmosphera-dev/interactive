// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtTest
import InterActive
import InterActive.Foundation as IA
import InterActive.Tests

Item {
    id: scene
    width: 1200
    height: 1000
    Component { id: mixedComponent; MixedFixture {} }
    Component {
        id: focusComponent
        Column {
            width: 400
            spacing: 8
            property var controls: [button, primary, tool, field, check, radio, toggle, tab, row, menu, slider]
            Item { id: entry; width: 1; height: 1; activeFocusOnTab: true }
            property alias entry: entry
            IAButton { id: button; text: "Button" }
            IAButton { id: primary; text: "Primary"; tone: IA.Presentation.Primary }
            IAToolButton { id: tool; text: "Tool" }
            IATextField { id: field; text: "Field" }
            IACheckBox { id: check; text: "Check" }
            IARadioButton { id: radio; text: "Radio" }
            IASwitch { id: toggle; text: "Switch" }
            IATabButton { id: tab; text: "Tab" }
            IAItemDelegate { id: row; text: "Row" }
            IAMenuItem { id: menu; text: "Menu" }
            IASlider { id: slider; value: 0.5 }
        }
    }
    Component {
        id: scrollComponent
        IAScrollView {
            width: 360
            height: 200
            Flickable {
                objectName: "consumerFlickable"
                contentWidth: width
                contentHeight: 400
            }
        }
    }

    TestCase {
        name: "MixedGeometry"
        when: windowShown
        property MixedFixture fixture

        function cleanup(): void {
            IA.Appearance.input = {};
        }

        function test_sharedLanes_data(): var {
            const rows = [];
            for (const width of [360, 768, 1200]) {
                for (const scale of [1, 1.5, 2]) {
                    for (const rtl of [false, true]) {
                        rows.push({tag: width + "-scale" + scale + (rtl ? "-rtl" : "-ltr"),
                                   width: width, scale: scale, rtl: rtl});
                    }
                }
            }
            return rows;
        }

        function near(actual: real, expected: real, description: string): void {
            verify(Math.abs(actual - expected) <= 0.5,
                   description + ": " + actual + " versus " + expected);
        }

        function test_sharedLanes(data: var): void {
            scene.width = data.width;
            IA.Appearance.input = {fontScale: data.scale};
            fixture = createTemporaryObject(mixedComponent, scene,
                                             {width: data.width, height: scene.height, rtl: data.rtl}) as MixedFixture;
            verify(fixture !== null);
            verify(waitForRendering(fixture));
            verify(TestProbe.activate(fixture));
            const field = fixture.editor;
            const button = fixture.applyButton;
            const label = findChild(button, "iaLabel") as Text;
            verify(label !== null);
            near(field.height, button.height, "Composed field/button height");
            const fieldBaseline = field.mapToItem(fixture, 0, field.baselineOffset).y;
            const buttonBaseline = label.mapToItem(fixture, 0, label.baselineOffset).y;
            near(fieldBaseline, buttonBaseline, "Rendered text baselines");
            compare(label.font.pixelSize, Math.round(13 * data.scale));
            compare(field.font.pixelSize, label.font.pixelSize);
            verify(field.width > 0);
            const fieldLeft = field.mapToItem(fixture, 0, 0).x;
            const buttonLeft = button.mapToItem(fixture, 0, 0).x;
            verify(fieldLeft >= 0 && fieldLeft + field.width <= fixture.width + 0.5);
            verify(buttonLeft >= 0 && buttonLeft + button.width <= fixture.width + 0.5);
            if (data.rtl)
                verify(buttonLeft + button.width <= fieldLeft + 0.5, "RTL reorders the composed row");
            else
                verify(fieldLeft + field.width <= buttonLeft + 0.5, "LTR controls do not overlap");

            const track = findChild(fixture.slider, "iaTrack") as Item;
            const thumb = findChild(fixture.slider, "iaThumb") as Item;
            verify(track !== null);
            verify(thumb !== null);
            compare(fixture.slider.mirrored, data.rtl);
            const fill = findChild(fixture.progress, "iaFill") as Rectangle;
            verify(fill !== null);
            for (const value of [0, 37, 100]) {
                fixture.slider.value = value;
                verify(waitForRendering(fixture.slider));
                const trackCenter = track.mapToItem(fixture, track.width / 2, track.height / 2);
                const thumbCenter = thumb.mapToItem(fixture, thumb.width / 2, thumb.height / 2);
                near(thumbCenter.y, trackCenter.y, "Slider track/thumb centerline at " + value);
                verify(thumb.width > 0 && thumb.height > 0);
                const start = track.mapToItem(fixture, 0, 0).x;
                verify(thumbCenter.x >= start - 0.5);
                verify(thumbCenter.x <= start + track.width + 0.5);
                near(thumbCenter.x, start + track.width * fixture.slider.visualPosition,
                     "Thumb follows the track at " + value);
                near(fill.width, fixture.progress.contentItem.width * value / 100,
                     "Rendered progress fill at " + value);
                near(fill.x, data.rtl ? fixture.progress.contentItem.width - fill.width : 0,
                     "Progress fill origin respects layout direction");
            }
            for (const choice of [fixture.check, fixture.radioOne, fixture.radioTwo, fixture.toggle]) {
                const indicator = findChild(choice, "iaIndicator") as Item;
                const choiceLabel = findChild(choice, "iaLabel") as Text;
                verify(indicator !== null && choiceLabel !== null);
                near(indicator.mapToItem(fixture, 0, indicator.height / 2).y,
                     choiceLabel.mapToItem(fixture, 0, choiceLabel.height / 2).y,
                     "Indicator/label centerline");
                compare(choice.mirrored, data.rtl);
            }
            fixture.slider.value = 37;
            fixture.slider.forceActiveFocus(Qt.TabFocusReason);
            verify(TestProbe.keyClick(fixture.slider, data.rtl ? Qt.Key_Left : Qt.Key_Right));
            compare(fixture.valueSummary.text, "Intensity: 38%");
            compare(fixture.progress.value, 38);

            const width = button.width;
            const height = button.height;
            verify(TestProbe.move(button, button.width / 2, button.height / 2));
            tryCompare(button, "hovered", true);
            near(button.width, width, "Hover width");
            near(button.height, height, "Hover height");
            verify(TestProbe.press(button, button.width / 2, button.height / 2));
            tryCompare(button, "down", true);
            near(button.width, width, "Pressed width");
            near(button.height, height, "Pressed height");
            verify(TestProbe.release(button, button.width / 2, button.height / 2));
            fixture.editor.forceActiveFocus(Qt.TabFocusReason);
            verify(TestProbe.keyClick(fixture.editor, Qt.Key_Tab));
            tryCompare(button, "activeFocus", true);
            tryCompare(button, "visualFocus", true);
            near(button.width, width, "Focus width");
            near(button.height, height, "Focus height");
        }

        function test_validationAndFocusRemainDistinct_data(): var {
            return [{tag: "default", input: {}}, {tag: "red-primary", input: {tokens: {colors: {accent: "#E53935"}}}},
                {tag: "green-primary", input: {tokens: {colors: {accent: "#36A56A"}}}},
                {tag: "amber-high", input: {contrast: "high", tokens: {colors: {accent: "#D99B24"}}}},
                {tag: "light-high", input: {scheme: "light", contrast: "high"}},
                {tag: "dark-normal", input: {scheme: "dark", contrast: "normal"}},
                {tag: "dark-high", input: {scheme: "dark", contrast: "high"}}];
        }

        function test_singleFocusBorder_data(): var {
            const rows = [];
            for (const scheme of ["light", "dark"]) {
                for (const contrast of ["normal", "high"])
                    rows.push({tag: scheme + "-" + contrast, scheme: scheme, contrast: contrast});
            }
            return rows;
        }

        function test_singleFocusBorder(data: var): void {
            scene.width = 1200;
            IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast};
            const samples = createTemporaryObject(focusComponent, scene);
            verify(samples !== null);
            verify(TestProbe.render(samples));
            verify(TestProbe.activate(samples));
            verify(TestProbe.move(scene, scene.width - 2, scene.height - 2));
            for (let index = 0; index < samples.controls.length; ++index) {
                const control = samples.controls[index];
                samples.entry.forceActiveFocus(Qt.OtherFocusReason);
                tryCompare(control, "activeFocus", false);
                // Choice focus belongs to its indicator; slider focus to its thumb.
                const border = (index >= 4 && index <= 6 ? control.indicator
                    : index === 10 ? control.handle : control.background) as Rectangle;
                verify(border !== null);
                const borderless = [2, 7, 8, 9].indexOf(index) !== -1;
                compare(border.border.width, borderless ? 0 : IA.Appearance.metrics.borderWidth);
                const bounds = [border.x, border.y, border.width, border.height, border.radius,
                    control.width, control.height, control.implicitWidth, control.implicitHeight];
                control.forceActiveFocus(Qt.TabFocusReason);
                tryCompare(control, "activeFocus", true);
                if (index !== 3)
                    tryCompare(control, "visualFocus", true);
                verify(waitForRendering(control));
                compare(border.border.width, IA.Appearance.metrics.focusWidth);
                const colors = index >= 4 && index <= 6 ? (border as IA.ChoiceIndicator).colors
                    : (border as IA.ControlBackground).colors;
                compare(border.border.color, colors.focusedBorderColor);
                if (index !== 1) // Primary retains the readable colored-fill fallback.
                    compare(border.border.color, IA.Appearance.colors.focus, "Neutral focus is the shared accent hue");
                compare([border.x, border.y, border.width, border.height, border.radius,
                    control.width, control.height, control.implicitWidth, control.implicitHeight], bounds,
                    "Focus grows inward without changing bounds or radius");
                for (const child of border.children) {
                    const rectangle = child as Rectangle;
                    if (rectangle !== null) {
                        if (index >= 4 && index <= 6)
                            compare(rectangle, (border as IA.ChoiceIndicator).mark, "Only the choice's mark, no ring");
                        else
                            compare(rectangle.objectName, "iaPressInset", "Only the press inset, no ring");
                    }
                }
                if (index >= 4 && index <= 6)
                    compare((control.background as Rectangle).border.width, 0, "Choice row has no second focus border");
                // Qt 6.8 grabImage crops with the item's parent-local x/y, not
                // scene coordinates. Grab the root and map nested controls.
                const image = grabImage(scene);
                verify(image.width > 0 && image.height > 0);
                const point = border.mapToItem(scene, border.width / 2, border.border.width / 2);
                const expected = border.border.color;
                fuzzyCompare(image.pixel(Math.floor(point.x * image.width / scene.width),
                    Math.floor(point.y * image.height / scene.height)), expected, 0.03,
                    "Focus color reaches the rendered top border: " + index);
            }
        }

        function test_validationAndFocusRemainDistinct(data: var): void {
            IA.Appearance.input = data.input;
            fixture = createTemporaryObject(mixedComponent, scene) as MixedFixture;
            verify(fixture !== null);
            verify(waitForRendering(fixture));
            verify(TestProbe.activate(fixture));
            const field = fixture.editor;
            const width = field.width;
            const height = field.height;
            field.validation = IA.Presentation.Invalid;
            field.forceActiveFocus(Qt.TabFocusReason);
            tryCompare(field, "activeFocus", true);
            verify(waitForRendering(field));
            const background = field.background as Rectangle;
            verify(background !== null);
            compare(background.border.color, IA.Appearance.colors.errorText);
            compare(background.border.width, IA.Appearance.metrics.focusWidth);
            for (const child of background.children) {
                const rectangle = child as Rectangle;
                if (rectangle !== null)
                    compare(rectangle.objectName, "iaPressInset", "Only the press inset, no focus outline");
            }
            const image = grabImage(fixture);
            verify(image.width > 0 && image.height > 0);
            const validationPoint = background.mapToItem(fixture, background.width / 2, background.border.width / 2);
            const scaleX = image.width / fixture.width;
            const scaleY = image.height / fixture.height;
            fuzzyCompare(image.pixel(Math.floor(validationPoint.x * scaleX), Math.floor(validationPoint.y * scaleY)),
                         IA.Appearance.colors.errorText, 0.03, "The wider focused border still renders invalid color");
            near(field.width, width, "Validation/focus width");
            near(field.height, height, "Validation/focus height");
            compare(field.text, "Maya Chen");
        }

        function test_touchTargetsDoNotOverlap(): void {
            IA.Appearance.input = {density: "touch"};
            fixture = createTemporaryObject(mixedComponent, scene, {width: 360}) as MixedFixture;
            verify(fixture !== null);
            verify(waitForRendering(fixture));
            for (const control of [fixture.applyButton, fixture.check, fixture.radioOne,
                                    fixture.radioTwo, fixture.toggle, fixture.secondTab, fixture.delegate]) {
                verify(control.width >= 44 && control.height >= 44,
                       "Touch target is at least 44 by 44: " + control);
            }
            const first = fixture.radioOne.mapToItem(fixture, 0, 0);
            const second = fixture.radioTwo.mapToItem(fixture, 0, 0);
            verify(first.x + fixture.radioOne.width <= second.x
                   || second.x + fixture.radioTwo.width <= first.x
                   || first.y + fixture.radioOne.height <= second.y
                   || second.y + fixture.radioTwo.height <= first.y);
        }

        function test_scrollViewAdoptsConsumerFlickable(): void {
            const view = createTemporaryObject(scrollComponent, scene) as IAScrollView;
            verify(view !== null);
            verify(TestProbe.render(view));
            const content = findChild(view, "consumerFlickable") as Flickable;
            verify(content !== null);
            compare(view.contentItem, content, "The supplied Flickable is the viewport, not nested content");
            near(content.width, view.availableWidth, "Consumer viewport width");
            near(content.height, view.availableHeight, "Consumer viewport height");
        }
    }
}
