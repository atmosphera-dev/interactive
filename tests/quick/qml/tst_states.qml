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
    Component {
        id: indicatorComponent
        IA.ChoiceIndicator {
            resolvedAppearance: IA.ControlAppearance { source: IA.Appearance; family: "choice" }
        }
    }
    Component { id: fieldComponent; IATextField {} }
    Component { id: labelComponent; IALabel {} }
    Component { id: progressComponent; IAProgressBar {} }
    Component { id: sliderComponent; IASlider {} }
    Component { id: scrollComponent; IAScrollBar {} }
    Component { id: menuItemComponent; IAMenuItem {} }
    Component { id: menuSeparatorComponent; IAMenuSeparator { width: 200 } }
    Component { id: toolSeparatorComponent; IAToolSeparator {} }
    Component {
        id: tabBarComponent
        IATabBar {
            width: 300
            IATabButton { text: "Overview"; hoverEnabled: false }
            IATabButton { text: "Details"; hoverEnabled: false }
        }
    }
    Component {
        id: slotMenuComponent
        IAMenu {
            width: 300
            IAMenuItem { text: "Plain command"; hoverEnabled: false }
            IAMenuItem { text: "Checked command"; checkable: true; checked: true; hoverEnabled: false }
            IAMenuItem { text: "Icon command"; icon.source: IA.Appearance.icons.search; hoverEnabled: false }
            IAMenuItem {
                text: "Both slots"; checkable: true; checked: true
                icon.source: IA.Appearance.icons.search; hoverEnabled: false
            }
            IAMenu {
                title: "Submenu"
                IAMenuItem { text: "Nested command" }
            }
        }
    }
    TestCase {
        name: "PressedStatePairs"
        when: windowShown

        function init(): void { IA.Appearance.input = {}; }

        function cleanup(): void {
            TestProbe.move(scene, scene.width - 2, scene.height - 2);
            TestProbe.release(scene, scene.width - 2, scene.height - 2);
            IA.Appearance.input = {};
        }

        function test_onlyUsedVisuals(): void {
            const indicator = createTemporaryObject(indicatorComponent, scene, {checked: true}) as IA.ChoiceIndicator;
            verify(indicator !== null);
            compare(indicator.children.length, 1, "Only the check mark is instantiated");
            verify(indicator.children[0] instanceof Rectangle);
            verify(indicator.mark.children[0] instanceof IA.Icon);
            compare(visualItemCount(indicator), 5);
            indicator.partial = true;
            compare((indicator.mark.children[0] as IA.Icon).source, IA.Appearance.icons.minus);
            indicator.kind = IA.ChoiceIndicator.Radio;
            tryVerify(function() { return indicator.children.length === 1; });
            verify(indicator.children[0] instanceof Rectangle);
            compare(visualItemCount(indicator), 1);
            verify(findChild(indicator, "iaThumb") === null);
            indicator.kind = IA.ChoiceIndicator.Toggle;
            tryVerify(function() { return indicator.children.length === 1; });
            compare(indicator.mark.children[0].objectName, "iaThumb");
            compare(visualItemCount(indicator), 2);
            indicator.kind = IA.ChoiceIndicator.Check;
            tryVerify(function() { return indicator.children.length === 1; });
            verify(indicator.mark.children[0] instanceof IA.Icon);
            compare(visualItemCount(indicator), 5);

            for (const component of [buttonComponent, toolComponent, tabComponent, delegateComponent,
                                     checkComponent, radioComponent, switchComponent]) {
                const control = createTemporaryObject(component, scene) as T.AbstractButton;
                const inset = findChild(control.background, "iaPressInset") as Rectangle;
                verify(inset !== null);
                const usesInset = component === buttonComponent || component === toolComponent;
                compare(inset.gradient instanceof Gradient, usesInset,
                        "No Gradient or stops are created for a non-inset family");
            }
        }

        function test_supplementaryRoleConsumers(): void {
            const field = createTemporaryObject(fieldComponent, scene, {placeholderText: "Placeholder"}) as IATextField;
            const label = createTemporaryObject(labelComponent, scene) as IALabel;
            const progress = createTemporaryObject(progressComponent, scene) as IAProgressBar;
            const slider = createTemporaryObject(sliderComponent, scene) as IASlider;
            const scroll = createTemporaryObject(scrollComponent, scene) as IAScrollBar;
            verify(field !== null && label !== null && progress !== null && slider !== null && scroll !== null);
            IA.Appearance.input = {tokens: {colors: {placeholderText: "green", onAccent: "yellow", link: "red"}}};
            compare(field.placeholderTextColor, "#008000");
            compare(field.selectedTextColor, "#ffff00");
            compare(label.linkColor, "#ff0000");
            for (const control of [progress, slider]) {
                control.fillColor = "purple";
                const fill = findChild(control, "iaFill") as Rectangle;
                verify(fill !== null);
                compare(fill.color, "#800080", "A fill-only edit updates the actual consumer");
                control.enabled = false;
                compare(fill.color, control.disabledForegroundColor);
            }
            field.enabled = false;
            compare(field.color, field.disabledForegroundColor);
            compare(field.placeholderTextColor, field.disabledForegroundColor);
            const track = findChild(slider, "iaTrack") as Rectangle;
            compare(track.color, slider.disabledBackgroundColor);
            scroll.enabled = false;
            compare((scroll.contentItem as Rectangle).color, scroll.disabledForegroundColor);
            compare((scroll.background as Rectangle).color, scroll.backgroundColor,
                    "The scrollbar track still ignores enabled");
        }

        function test_choiceCenters_data(): var {
            const rows = [];
            for (const scheme of ["light", "dark"]) {
                for (const contrast of ["normal", "high"]) {
                    for (const component of [checkComponent, radioComponent, switchComponent]) {
                        for (const rtl of [false, true])
                            rows.push({tag: scheme + "-" + contrast + "-" + rows.length,
                                scheme: scheme, contrast: contrast, component: component, rtl: rtl});
                    }
                }
            }
            return rows;
        }

        function test_segmentedTabs_data(): var { return test_choiceLocalOffTracks_data(); }

        function test_segmentedTabs(data: var): void {
            IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast};
            const bar = createTemporaryObject(tabBarComponent, scene) as IATabBar;
            verify(bar !== null);
            verify(TestProbe.render(bar));
            verify(TestProbe.activate(bar));
            const track = bar.background as IA.ControlBackground;
            const first = bar.itemAt(0) as IATabButton;
            const second = bar.itemAt(1) as IATabButton;
            const segment = first.background as IA.ControlBackground;
            compare(track.resolvedAppearance.family, "tabBar");
            compare(track.color, bar.backgroundColor);
            compare(track.border.width, 0);
            compare(bar.leftPadding, IA.Appearance.metrics.spacingXS);
            compare(bar.topPadding, bar.leftPadding);
            compare(bar.spacing, 0);
            compare(segment.color, data.scheme === "dark" ? IA.Appearance.colors.controlHover : IA.Appearance.colors.content);
            compare(segment.border.width, 0);
            compare((second.background as Rectangle).color.a, 0);
            verify(segment.color !== track.color);
            fuzzyCompare(first.mapToItem(bar, 0, 0).x, bar.leftPadding, 0.001);
            fuzzyCompare(first.mapToItem(bar, 0, 0).y, bar.topPadding, 0.001);
            first.forceActiveFocus(Qt.TabFocusReason);
            verify(TestProbe.keyClick(first, Qt.Key_Right));
            tryCompare(bar, "currentIndex", 1);
            compare((first.background as Rectangle).color.a, 0);
            compare((second.background as Rectangle).color, second.selectedBackgroundColor);
            // Already-focused items keep their native focus reason. Enter with
            // a real Tab event, as the existing capture/focus probes do.
            scene.forceActiveFocus(Qt.OtherFocusReason);
            tryCompare(scene, "activeFocus", true);
            for (let i = 0; i < 24 && !second.activeFocus; ++i)
                verify(TestProbe.keyClick(scene, Qt.Key_Tab));
            tryCompare(second, "activeFocus", true);
            tryCompare(second, "visualFocus", true);
            compare((second.background as Rectangle).border.width, IA.Appearance.metrics.focusWidth);
        }

        function test_menuSlots_data(): var {
            const rows = [];
            for (const rtl of [false, true]) {
                for (const touch of [false, true])
                    rows.push({tag: rtl + "-" + touch, rtl: rtl, touch: touch});
            }
            return rows;
        }

        function test_menuSlots(data: var): void {
            IA.Appearance.input = {density: data.touch ? "touch" : "compact", fontScale: data.touch ? 1.5 : 1};
            const menu = createTemporaryObject(slotMenuComponent, scene, {parent: scene}) as IAMenu;
            verify(menu !== null);
            menu.open();
            tryCompare(menu, "opened", true);
            for (let i = 0; i < menu.count; ++i)
                menu.itemAt(i).LayoutMirroring.enabled = data.rtl;
            verify(TestProbe.render(menu.contentItem));
            let labelEdge = null;
            let iconEdge = null;
            let markEdge = null;
            for (let i = 0; i < menu.count; ++i) {
                const row = menu.itemAt(i) as IAMenuItem;
                const label = findChild(row, "iaLabel") as Text;
                verify(label !== null);
                const edge = label.mapToItem(menu.contentItem, data.rtl ? label.width : 0, 0).x;
                if (labelEdge === null)
                    labelEdge = edge;
                fuzzyCompare(edge, labelEdge, 0.5, "Native menu text padding keeps every label in the same lane");
                if (row.showsIcon) {
                    const icon = findChild(row, "iaMenuIcon") as IA.Icon;
                    verify(icon !== null);
                    const position = icon.mapToItem(menu.contentItem, 0, 0).x;
                    if (iconEdge === null)
                        iconEdge = position;
                    fuzzyCompare(position, iconEdge, 0.5, "Action icons retain their slot with or without a check mark");
                }
                if (row.checkable) {
                    const position = row.indicator.mapToItem(menu.contentItem, 0, 0).x;
                    if (markEdge === null)
                        markEdge = position;
                    fuzzyCompare(position, markEdge, 0.5, "Check marks retain their slot with or without an action icon");
                }
                if (row.subMenu !== null) {
                    const arrow = row.arrow;
                    const slot = findChild(row, "iaArrowSlot") as Item;
                    verify(slot !== null);
                    compare(slot.width, row.height);
                    compare(slot.height, row.height);
                    const box = arrow.mapToItem(row, 0, 0);
                    const top = box.y, bottom = row.height - box.y - arrow.height;
                    const end = data.rtl ? box.x : row.width - box.x - arrow.width;
                    fuzzyCompare(top, bottom, 1);
                    fuzzyCompare(end, top, 1, "Arrow has equal clearance to all facing row edges");
                }
            }
            // A menu with no accessories collapses the shared leading lane.
            for (let i = 0; i < menu.count; ++i) {
                const row = menu.itemAt(i) as IAMenuItem;
                row.checkable = false;
                row.icon.source = "";
            }
            verify(TestProbe.render(menu.contentItem));
            compare((menu.itemAt(0) as IAMenuItem).leadingPadding, 0);
            menu.close();
        }

        function test_menuDangerAndSeparators_data(): var { return test_choiceLocalOffTracks_data(); }

        function test_menuDangerAndSeparators(data: var): void {
            IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast};
            const item = createTemporaryObject(menuItemComponent, scene, {
                text: "Remove collection", width: 240, tone: IA.Presentation.Destructive, hoverEnabled: false
            }) as IAMenuItem;
            verify(item !== null);
            const surface = item.background as IA.ControlBackground;
            const label = findChild(item, "iaLabel") as Text;
            verify(TestProbe.render(item));
            compare(surface.color.a, 0);
            compare(label.color, item.foregroundColor);
            // P2 can finalize a generated danger label for hover headroom.
            // An explicit semantic text role proves the role-to-pixel mapping.
            IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast,
                tokens: {colors: {errorText: "#b03050", destructiveText: "#00ff00"}}};
            compare(label.color, "#b03050");
            compare(surface.color.a, 0);
            IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast};
            item.highlighted = true;
            compare(surface.color, item.selectedBackgroundColor);
            compare(label.color, "#ffffff");
            verify(menuPairContrast(label.color, surface.color) >= 7);
            for (const component of [menuSeparatorComponent, toolSeparatorComponent]) {
                const separator = createTemporaryObject(component, scene);
                verify(separator !== null);
                const line = findChild(separator, "iaSeparator") as Rectangle;
                verify(line !== null);
                compare(line.color, IA.Appearance.colors.separator);
                separator.foregroundColor = "magenta";
                verify(TestProbe.render(separator));
                compare(line.color, "#ff00ff");
                IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast,
                    tokens: {colors: {separator: "green", text: "red"}}};
                compare(line.color, "#ff00ff", "Explicit line overrides stay owned");
                separator.foregroundColor = undefined;
                compare(line.color, "#008000", "RESET resumes the live separator role, not text");
                separator.foregroundColor = "blue";
                separator.resetAppearance();
                compare(line.color, "#008000");
                IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast};
                compare(line.color, IA.Appearance.colors.separator);
            }
        }

        function test_choiceCenters(data: var): void {
            IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast};
            const control = createTemporaryObject(data.component, scene, {
                x: 20, y: 20, width: 240, text: "One shared choice row", hoverEnabled: false
            }) as T.AbstractButton;
            verify(control !== null);
            control.LayoutMirroring.enabled = data.rtl;
            const row = control.contentItem as IA.ChoiceRow;
            verify(row !== null, "Every Qt choice template uses Foundation.ChoiceRow");
            compare(control.indicator, row.indicator, "Native interaction retains the real indicator");
            verify(TestProbe.render(control));
            verify(TestProbe.activate(control));
            const indicator = control.indicator as IA.ChoiceIndicator;
            const center = indicator.mark as Rectangle;
            verify(center !== null);
            const thumb = findChild(indicator, "iaThumb") as Rectangle;
            const glyph = center.children.length ? center.children[0] as IA.Icon : null;
            compare(indicator.color.a, 0, "The outline-to-center lane is not painted over");
            compare(indicator.border.color, control.borderColor);
            const labelCenter = row.mapToItem(control, 0, row.height / 2).y;
            fuzzyCompare(indicator.mapToItem(control, 0, indicator.height / 2).y, labelCenter, 0.001);
            compare(row.mirrored, data.rtl);
            compare(indicator.x, data.rtl ? row.width - indicator.width : 0);
            compare(data.rtl ? row.rightPadding : row.leftPadding, indicator.width + control.spacing);
            compare(data.rtl ? row.leftPadding : row.rightPadding, 0);

            for (const on of [false, true]) {
                control.checked = on;
                compare(indicator.selected, on);
                compare(center.color, on ? indicator.colors.choiceCenterColor
                    : thumb ? indicator.colors.choiceTrackColor : indicator.colors.backgroundColor);
                if (on) {
                    compare(center.color, control.selectedBackgroundColor);
                    compare(indicator.markColor, "#ffffff", "Default on pair has a light mark");
                    verify(menuPairContrast(indicator.markColor, center.color) >= 7);
                }
                if (thumb) {
                    compare(thumb.color, indicator.markColor);
                    const gap = (center.height - thumb.height) / 2;
                    verify(gap >= IA.Appearance.metrics.choiceGap);
                    fuzzyCompare(thumb.y, gap, 0.001);
                    const edge = indicator.visualPosition < 0.5 ? thumb.x
                        : center.width - thumb.x - thumb.width;
                    fuzzyCompare(edge, gap, 0.001, "Thumb has equal facing-edge clearance");
                } else if (glyph) {
                    compare(center.radius, IA.Appearance.metrics.choiceCenterRadius,
                        "A thicker outline must not consume the checkbox center's rounded corners");
                    compare(glyph.visible, on);
                    compare(glyph.color, indicator.markColor);
                }
                for (const focused of [false, true]) {
                    indicator.focused = focused;
                    verify(TestProbe.render(control));
                    verify(center.width > 0 && center.height > 0);
                    fuzzyCompare(center.x - indicator.border.width, IA.Appearance.metrics.choiceGap, 0.001);
                    fuzzyCompare(center.y - indicator.border.width, IA.Appearance.metrics.choiceGap, 0.001);
                    fuzzyCompare(indicator.width - center.x - center.width - indicator.border.width,
                        IA.Appearance.metrics.choiceGap, 0.001);
                    const image = grabImage(scene);
                    // A straight-edge sample measures an actual unpainted lane,
                    // not merely geometry. Avoid the rounded corner and tick.
                    const lane = indicator.mapToItem(scene, indicator.width / 2,
                        indicator.border.width + IA.Appearance.metrics.choiceGap / 2);
                    const outside = indicator.mapToItem(scene, -2, indicator.height / 2);
                    compare(image.pixel(Math.floor(lane.x * image.width / scene.width),
                        Math.floor(lane.y * image.height / scene.height)),
                        image.pixel(Math.floor(outside.x * image.width / scene.width),
                            Math.floor(outside.y * image.height / scene.height)),
                        "The gap has exactly the host backdrop, not the outline or center fill");
                }
                indicator.focused = false;
                indicator.hovered = true;
                compare(center.color, on ? indicator.colors.choiceCenterColor
                    : thumb ? indicator.colors.choiceTrackColor : indicator.colors.backgroundColor);
                const hover = center.color.toString();
                indicator.hovered = false;
                verify(center.color.toString() !== hover, "Both off and on have visible hover feedback");
                indicator.down = true;
                compare(center.color, on ? indicator.colors.choiceCenterColor
                    : thumb ? indicator.colors.choiceTrackColor : indicator.colors.backgroundColor);
                indicator.down = false;
            }
            if (control instanceof IACheckBox) {
                control.checkState = Qt.PartiallyChecked;
                compare(indicator.selected, true);
                verify(glyph.visible);
                compare(glyph.source, IA.Appearance.icons.minus);
                compare(center.color, indicator.colors.choiceCenterColor);
            }
            control.checked = true;
            control.enabled = false;
            compare(center.color, indicator.colors.choiceCenterColor, "Disabled-on retains its center");
            verify(center.color.a > 0);
            compare(indicator.markColor, indicator.colors.choiceMarkColor);
            if (thumb)
                compare(thumb.color, indicator.markColor);
            else if (glyph)
                compare(glyph.color, indicator.markColor);
            compare(indicator.border.color, control.disabledBorderColor);
        }

        function test_menuHighlightPair_data(): var {
            const rows = [];
            for (const scheme of ["light", "dark"]) {
                for (const contrast of ["normal", "high"]) {
                    for (const accent of ["#5c9cf5", "#ffff00", "#800020"])
                        rows.push({tag: scheme + "-" + contrast + "-" + accent,
                            scheme: scheme, contrast: contrast, accent: accent});
                }
            }
            return rows;
        }

        function test_choiceLocalOffTracks_data(): var {
            const rows = [];
            for (const scheme of ["light", "dark"]) {
                for (const contrast of ["normal", "high"])
                    rows.push({tag: scheme + "-" + contrast, scheme: scheme, contrast: contrast});
            }
            return rows;
        }

        function test_choiceLocalOffTracks(data: var): void {
            IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast};
            const control = createTemporaryObject(switchComponent, scene, {
                text: "Local off pair", hoverEnabled: false,
                backgroundColor: "#c0d0e0", foregroundColor: "#111111",
                hoverBackgroundColor: "#b0c0d0", pressedBackgroundColor: "#a0b0c0",
                disabledBackgroundColor: "#909090"
            }) as IASwitch;
            verify(control !== null);
            const indicator = control.indicator as IA.ChoiceIndicator;
            const center = indicator.mark as Rectangle;
            compare(center.color, "#c0d0e0", "An explicit off background owns the inner track");
            indicator.hovered = true;
            compare(center.color, "#b0c0d0");
            indicator.down = true;
            compare(center.color, "#a0b0c0");
            indicator.down = false;
            indicator.hovered = false;
            control.enabled = false;
            compare(center.color, "#909090");
        }

        function menuPairContrast(text: color, fill: color): real {
            const luminances = [];
            for (const value of [text, fill]) {
                compare(value.a, 1);
                const channels = [value.r, value.g, value.b];
                for (let index = 0; index < channels.length; ++index) {
                    const channel = channels[index];
                    channels[index] = channel <= 0.04045 ? channel / 12.92
                        : Math.pow((channel + 0.055) / 1.055, 2.4);
                }
                luminances.push(0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]);
            }
            return (Math.max(luminances[0], luminances[1]) + 0.05)
                / (Math.min(luminances[0], luminances[1]) + 0.05);
        }

        function test_menuHighlightPair(data: var): void {
            IA.Appearance.input = {scheme: data.scheme, contrast: data.contrast,
                tokens: {colors: {accent: data.accent}}};
            const item = createTemporaryObject(menuItemComponent, scene, {
                x: 20, y: 20, width: 240, text: "Command", checkable: true, checked: true
            }) as IAMenuItem;
            verify(item !== null);
            const background = item.background as IA.ControlBackground;
            const mark = item.indicator as IA.Icon;
            verify(background !== null && mark !== null);
            verify(TestProbe.render(item));
            compare(background.color.a, 0, "Checking alone does not add a band");
            verify(mark.visible);
            item.highlighted = true;
            compare(background.color, item.selectedBackgroundColor);
            compare(background.foregroundColor, "#ffffff");
            compare(mark.color, background.foregroundColor);
            const label = findChild(item, "iaLabel") as Text;
            verify(label !== null);
            compare(label.color, background.foregroundColor);
            verify(menuPairContrast(label.color, background.color) >= 7,
                "Actual menu label reaches the 7:1 target on its band");
            background.active = false;
            compare(background.color, item.selectedBackgroundColor, "Menu highlight is not inactive selection");
            compare(label.color, "#ffffff");
            verify(menuPairContrast(label.color, background.color) >= 7);
            item.enabled = false;
            compare(background.color.a, 0, "Disabled wins even over a highlighted checked row");
            compare(background.foregroundColor, item.disabledForegroundColor);
            verify(mark.visible, "Disabling does not erase the checked mark");
            item.inactiveBackgroundColor = "#123456";
            item.inactiveForegroundColor = "#ffffff";
            item.enabled = true;
            compare(background.color, "#123456", "Explicit inactive colors still own that pair");
            compare(background.foregroundColor, "#ffffff");
            item.destroy();
        }

        function visualItemCount(item: Item): int {
            let count = 0;
            for (const child of item.children)
                count += 1 + visualItemCount(child);
            return count;
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
                const indicator = control.indicator as IA.ChoiceIndicator;
                foreground = control instanceof IASwitch ? findChild(indicator, "iaThumb")
                    : control instanceof IACheckBox ? indicator.mark.children[0] : null;
            }
            verify(foreground !== null || control instanceof IARadioButton);
            const center = data.choice ? (control.indicator as IA.ChoiceIndicator).mark as Rectangle : null;
            if (data.choice) {
                compare(background.color.a, 0);
                compare(center.color, "#000000");
                verifySelectedForeground(control, (control.indicator as IA.ChoiceIndicator).markColor);
            } else {
                compare(background.color, "#000000");
                verifySelectedForeground(control, foreground.color);
            }
            verify(TestProbe.press(control, control.width / 2, control.height / 2));
            try {
                tryCompare(control, "down", true);
                verify(TestProbe.render(control));
                if (data.inset) {
                    const surface = background as IA.ControlBackground;
                    const state = TestProbe.hostWindow(control).active ? IA.Presentation.SelectedHover : IA.Presentation.InactiveHover;
                    compare(background.color, surface.resolvedAppearance.stateTable.colors(state).backgroundColor);
                    verify(background.color !== "#000000", "Checked hover composes with the inset press");
                } else if (data.choice) {
                    const indicator = control.indicator as IA.ChoiceIndicator;
                    compare(center.color, indicator.colors.choiceCenterColor);
                    verify(center.color.toString() !== "#dddddd", "An on choice retains its on pair when pressed");
                    verifySelectedForeground(control, indicator.markColor);
                    if (foreground !== null)
                        compare(foreground.color, indicator.markColor, "The actual glyph/thumb consumes the pressed on pair");
                } else {
                    compare(background.color, "#dddddd");
                }
                const inset = findChild(control.background, "iaPressInset") as Rectangle;
                verify(inset !== null);
                compare(inset.visible, Boolean(data.inset));
                if (data.inset)
                    verifySelectedForeground(control, foreground.color);
                else if (!data.choice)
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
                compare(background.color.a, 0);
                compare(center.color, "#eeeeee", "The explicit off background still reaches the inner track");
                compare(foreground.color, "#111111");
            } else if (data.choice) {
                compare(center.color, "#000000");
                verifySelectedForeground(control, (control.indicator as IA.ChoiceIndicator).markColor);
            } else {
                compare(background.color, "#000000");
                verifySelectedForeground(control, foreground.color);
            }
        }
    }
}
