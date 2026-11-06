// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Templates as T
import QtTest
import InterActive
import InterActive.Foundation as IA
import InterActive.Tests

Item {
    id: scene
    width: 800
    height: 640
    Component { id: popupComponent; PopupFixture {} }
    Component { id: buttonBoxComponent; IADialogButtonBox {} }
    Component { id: emptyDialogComponent; IADialog {} }

    TestCase {
        name: "PopupConsumers"
        when: windowShown
        property PopupFixture fixture

        function modes(): var {
            return [{tag: "item", mode: T.Popup.Item}, {tag: "window", mode: T.Popup.Window}];
        }

        function init(): void {
            IA.Appearance.input = {};
            fixture = createTemporaryObject(popupComponent, scene) as PopupFixture;
            verify(fixture !== null);
            verify(waitForRendering(fixture));
            verify(TestProbe.activate(fixture));
        }

        function cleanup(): void {
            fixture.tooltip.close();
            fixture.submenu.close();
            fixture.menu.close();
            fixture.dialog.close();
            fixture.popup.close();
            IA.Appearance.input = {};
        }

        function click(item: Item): void {
            verify(TestProbe.click(item, item.width / 2, item.height / 2));
        }

        function openWithKeyboard(opener: Item, popup: T.Popup, mode: int): void {
            fixture.popupMode = mode;
            opener.forceActiveFocus(Qt.TabFocusReason);
            tryCompare(opener, "activeFocus", true);
            verify(TestProbe.keyClick(opener, Qt.Key_Space));
            assertHost(popup, mode);
        }

        function assertHost(popup: T.Popup, mode: int): void {
            tryCompare(popup, "opened", true);
            tryVerify(function() { return TestProbe.exposed(popup.contentItem); });
            verify(TestProbe.render(popup.contentItem));
            const owner = TestProbe.hostWindow(fixture);
            const host = TestProbe.hostWindow(popup.contentItem);
            verify(owner !== null);
            verify(host !== null);
            compare(popup.contentItem.Window.window, host);
            if (mode === T.Popup.Window)
                verify(host !== owner, "Window popup has a distinct exposed QQuickWindow, not an Item fallback");
            else {
                compare(host, owner, "Item popup is rendered in its owner's actual window");
                const corner = popup.background.mapToItem(owner.contentItem, 0, 0);
                verify(corner.x >= -0.5 && corner.y >= -0.5);
                verify(corner.x + popup.background.width <= owner.width + 0.5);
                verify(corner.y + popup.background.height <= owner.height + 0.5);
            }
            // Window-mode compositor placement requires the separate marker/
            // output-capture gate; Qt global coordinates are not evidence of it.
        }

        function test_menuThemeWhileOpen_data(): var { return modes(); }
        function test_menuThemeWhileOpen(data: var): void {
            openWithKeyboard(fixture.menuOpener, fixture.menu, data.mode);
            const background = fixture.menu.background as Rectangle;
            verify(background !== null);
            const light = String(background.color);
            const label = findChild(fixture.firstAction, "iaLabel") as Text;
            verify(label !== null);
            const disabledLabel = findChild(fixture.disabledAction, "iaLabel") as Text;
            const shortcut = findChild(fixture.firstAction, "iaShortcut") as Text;
            verify(disabledLabel !== null && shortcut !== null);
            compare(shortcut.text, "Ctrl+K");
            fuzzyCompare(label.mapToItem(fixture.menu.contentItem, 0, 0).x,
                         disabledLabel.mapToItem(fixture.menu.contentItem, 0, 0).x, 0.5,
                         "Menu text shares a leading column despite shortcut/disabled differences");
            const lightText = String(label.color);
            IA.Appearance.input = {scheme: "dark", fontScale: 1.5,
                                   tokens: {metrics: {popupRadius: 11}}};
            verify(waitForRendering(fixture.menu.contentItem));
            assertHost(fixture.menu, data.mode);
            verify(String(background.color) !== light);
            compare(background.color, IA.Appearance.colors.popup);
            compare(background.radius, 11);
            verify(String(label.color) !== lightText);
            compare(disabledLabel.color, fixture.disabledAction.disabledForegroundColor);
            compare(label.font.pixelSize, Math.round(IA.Appearance.typography.controlSize));
            compare(fixture.menuSummary.text, "No action selected");
            click(fixture.firstAction);
            compare(fixture.menuSummary.text, "Compact preview selected");
            tryCompare(fixture.menu, "visible", false);
            tryCompare(fixture.menuOpener, "activeFocus", true);
        }

        function test_nestedMenuEscapeAndOutcome_data(): var { return modes(); }
        function test_nestedMenuEscapeAndOutcome(data: var): void {
            openWithKeyboard(fixture.menuOpener, fixture.menu, data.mode);
            click(fixture.disabledAction);
            compare(fixture.menuSummary.text, "No action selected");
            verify(fixture.menu.visible);
            const entry = fixture.menu.itemAt(2);
            verify(entry !== null);
            click(entry);
            assertHost(fixture.submenu, data.mode);
            if (data.mode === T.Popup.Window)
                verify(TestProbe.hostWindow(fixture.submenu.contentItem)
                       !== TestProbe.hostWindow(fixture.menu.contentItem));
            verify(TestProbe.keyClick(fixture.submenu.contentItem, Qt.Key_Escape));
            tryCompare(fixture.submenu, "visible", false);
            verify(fixture.menu.visible, "Escape closes only the nested level");
            compare(fixture.menuSummary.text, "No action selected");
            verify(TestProbe.keyClick(fixture.menu.contentItem, Qt.Key_Escape));
            tryCompare(fixture.menu, "visible", false);
            tryCompare(fixture.menuOpener, "activeFocus", true);

            openWithKeyboard(fixture.menuOpener, fixture.menu, data.mode);
            click(entry);
            assertHost(fixture.submenu, data.mode);
            const nestedLabel = findChild(fixture.nestedAction, "iaLabel") as Text;
            verify(nestedLabel !== null);
            const light = String((fixture.submenu.background as Rectangle).color);
            IA.Appearance.input = {scheme: "dark", fontScale: 2};
            verify(waitForRendering(fixture.submenu.contentItem));
            verify(String((fixture.submenu.background as Rectangle).color) !== light);
            compare(nestedLabel.font.pixelSize, Math.round(IA.Appearance.typography.controlSize));
            verify(fixture.menu.visible && fixture.submenu.visible);
            fixture.nestedAction.forceActiveFocus(Qt.TabFocusReason);
            verify(TestProbe.keyClick(fixture.nestedAction, Qt.Key_Space));
            compare(fixture.menuSummary.text, "Summary exported");
            tryCompare(fixture.submenu, "visible", false);
            tryCompare(fixture.menu, "visible", false);
            tryCompare(fixture.menuOpener, "activeFocus", true);
        }

        function test_dialogApplyCancelAndModalBlock_data(): var { return modes(); }

        function test_principalAction_data(): var {
            return [
                {tag: "accept", buttons: T.DialogButtonBox.Ok | T.DialogButtonBox.Cancel, principal: -1, expected: T.DialogButtonBox.Ok},
                {tag: "save", buttons: T.DialogButtonBox.Save | T.DialogButtonBox.Close, principal: -1, expected: T.DialogButtonBox.Save},
                {tag: "yes", buttons: T.DialogButtonBox.Yes | T.DialogButtonBox.No, principal: -1, expected: T.DialogButtonBox.Yes},
                {tag: "apply-only", buttons: T.DialogButtonBox.Apply | T.DialogButtonBox.Cancel, principal: -1, expected: T.DialogButtonBox.Apply},
                {tag: "accept-and-apply", buttons: T.DialogButtonBox.Save | T.DialogButtonBox.Apply, principal: -1, expected: T.DialogButtonBox.Save},
                {tag: "multiple-accept", buttons: T.DialogButtonBox.Ok | T.DialogButtonBox.Save | T.DialogButtonBox.Yes, principal: -1, expected: T.DialogButtonBox.Ok},
                {tag: "override", buttons: T.DialogButtonBox.Save | T.DialogButtonBox.Apply, principal: T.DialogButtonBox.Apply, expected: T.DialogButtonBox.Apply},
                {tag: "none", buttons: T.DialogButtonBox.Save | T.DialogButtonBox.Apply | T.DialogButtonBox.Discard, principal: T.DialogButtonBox.NoButton, expected: T.DialogButtonBox.NoButton},
                {tag: "cancel-only", buttons: T.DialogButtonBox.Cancel | T.DialogButtonBox.Close, principal: -1, expected: T.DialogButtonBox.NoButton},
                {tag: "cancel-override", buttons: T.DialogButtonBox.Save | T.DialogButtonBox.Cancel, principal: T.DialogButtonBox.Cancel, expected: T.DialogButtonBox.NoButton},
                {tag: "missing-override", buttons: T.DialogButtonBox.Save, principal: T.DialogButtonBox.Apply, expected: T.DialogButtonBox.NoButton},
                {tag: "destructive", buttons: T.DialogButtonBox.Save | T.DialogButtonBox.Discard, principal: -1, expected: T.DialogButtonBox.Save}
            ];
        }

        function assertPrincipal(box: IADialogButtonBox, expected: int): void {
            let primaryCount = 0;
            for (let index = 0; index < box.count; ++index) {
                const button = box.itemAt(index) as IAButton;
                verify(button !== null);
                const destructive = button.T.DialogButtonBox.buttonRole === T.DialogButtonBox.DestructiveRole;
                const primary = expected !== T.DialogButtonBox.NoButton && button === box.standardButton(expected);
                compare(button.tone, destructive ? IA.Presentation.Destructive
                    : primary ? IA.Presentation.Primary : IA.Presentation.Neutral);
                if (primary) {
                    ++primaryCount;
                    compare((button.background as Rectangle).color, IA.Appearance.colors.primarySurface,
                            "The principal action consumes the shared solid Primary fill");
                }
            }
            compare(primaryCount, expected === T.DialogButtonBox.NoButton ? 0 : 1);
        }

        function test_principalAction(data: var): void {
            const box = createTemporaryObject(buttonBoxComponent, fixture, {
                standardButtons: data.buttons, principalAction: data.principal
            }) as IADialogButtonBox;
            verify(box !== null);
            verify(TestProbe.render(box));
            assertPrincipal(box, data.expected);
            // Rebuilding Qt's standard-button model must not leave a stale choice.
            box.principalAction = -1;
            box.standardButtons = T.DialogButtonBox.Apply | T.DialogButtonBox.Cancel;
            verify(TestProbe.render(box));
            assertPrincipal(box, T.DialogButtonBox.Apply);
            box.standardButtons |= T.DialogButtonBox.Ok;
            verify(TestProbe.render(box));
            assertPrincipal(box, T.DialogButtonBox.Ok);
            box.principalAction = T.DialogButtonBox.NoButton;
            assertPrincipal(box, T.DialogButtonBox.NoButton);
        }

        function test_dialogHeadingAndEdges_data(): var {
            const rows = [];
            for (const host of modes()) {
                for (const density of ["compact", "touch"]) {
                    for (const scale of [1, 1.5])
                        rows.push({tag: host.tag + "-" + density + "-" + scale,
                            mode: host.mode, density: density, scale: scale});
                }
            }
            return rows;
        }

        function assertDialogEdges(dialog: IADialog): void {
            const footer = dialog.footer as IADialogButtonBox;
            verify(footer !== null);
            verify(TestProbe.render(footer));
            const content = dialog.contentItem;
            const background = dialog.background;
            const contentLeft = content.mapToItem(background, 0, 0).x;
            const contentRight = content.mapToItem(background, content.width, 0).x;
            fuzzyCompare(footer.mapToItem(background, footer.leftPadding, 0).x, contentLeft, 1,
                         "Footer and content share the leading inset");
            fuzzyCompare(footer.mapToItem(background, footer.width - footer.rightPadding, 0).x, contentRight, 1,
                         "Footer and content share the trailing inset");
            fuzzyCompare(footer.contentItem.mapToItem(background, footer.contentItem.width, 0).x, contentRight, 1,
                         "The real button row ends at the content edge");
            let buttonRight = 0;
            for (let index = 0; index < footer.count; ++index) {
                const button = footer.itemAt(index);
                buttonRight = Math.max(buttonRight, button.mapToItem(background, button.width, 0).x);
            }
            fuzzyCompare(buttonRight, contentRight, 1, "The actual trailing button ends at the content edge");
            const title = dialog.header as IALabel;
            verify(title !== null);
            fuzzyCompare(title.mapToItem(background, title.leftPadding, 0).x, contentLeft, 1,
                         "Title and content share the leading inset");
            compare(footer.topPadding, dialog.topPadding);
            compare(footer.bottomPadding, dialog.bottomPadding);
        }

        function test_dialogHeadingAndEdges(data: var): void {
            IA.Appearance.input = {density: data.density, fontScale: data.scale,
                tokens: {typography: {headingSize: 21, emphasisWeight: 650}, metrics: {popupPadding: 13}}};
            openWithKeyboard(fixture.dialogOpener, fixture.dialog, data.mode);
            const dialog = fixture.dialog;
            const title = findChild(dialog, "iaTitle") as IALabel;
            verify(title !== null);
            compare(title.font.pixelSize, Math.round(21 * data.scale));
            compare(title.font.weight, 650);
            compare(dialog.standardButton(T.Dialog.Apply).font.pixelSize, Math.round(13 * data.scale));
            assertDialogEdges(dialog);
            dialog.leftPadding = 17;
            dialog.rightPadding = 23;
            dialog.topPadding = 11;
            dialog.bottomPadding = 19;
            verify(TestProbe.render(dialog.contentItem));
            assertDialogEdges(dialog);
            // Equal-to-default assignments are genuine local ownership, not a
            // value comparison against the current ordinary typography role.
            dialog.fontPixelSize = IA.Appearance.typography.controlSize;
            dialog.fontWeight = IA.Appearance.typography.controlWeight;
            const localSize = dialog.fontPixelSize;
            const localWeight = dialog.fontWeight;
            IA.Appearance.input = {scheme: "dark", fontScale: 2,
                tokens: {typography: {headingSize: 24, emphasisWeight: 700}}};
            verify(TestProbe.render(dialog.contentItem));
            compare(title.font.pixelSize, Math.round(localSize));
            compare(title.font.weight, localWeight);
            compare(dialog.standardButton(T.Dialog.Apply).font.pixelSize, Math.round(localSize));
            dialog.resetAppearance();
            verify(TestProbe.render(dialog.contentItem));
            compare(title.font.pixelSize, 48);
            compare(title.font.weight, 700);
            compare(dialog.standardButton(T.Dialog.Apply).font.pixelSize, 26);
        }

        function test_dialogWidthRole(): void {
            IA.Appearance.input = {tokens: {metrics: {dialogMinWidth: 260, menuMinWidth: 700}}};
            const dialog = createTemporaryObject(emptyDialogComponent, fixture) as IADialog;
            verify(dialog !== null);
            compare(dialog.implicitWidth, 260);
            IA.Appearance.input = {tokens: {metrics: {dialogMinWidth: 300, menuMinWidth: 20}}};
            compare(dialog.implicitWidth, 300);
        }

        function test_dialogApplyCancelAndModalBlock(data: var): void {
            openWithKeyboard(fixture.dialogOpener, fixture.dialog, data.mode);
            tryCompare(fixture.dialogEditor, "activeFocus", true);
            verify(TestProbe.keyClick(fixture.dialogEditor, Qt.Key_A, Qt.ControlModifier));
            verify(TestProbe.typeAscii(fixture.dialogEditor, "Avery Stone"));
            compare(fixture.dialogEditor.text, "Avery Stone");
            compare(fixture.committedSummary.text, "Saved: Maya Chen");

            // Deliver to the owner window, not the modal host. Its overlay/modal
            // handling must prevent the background consumer from activating.
            click(fixture.backgroundButton);
            compare(fixture.backgroundSummary.text, "Background unchanged");
            verify(fixture.dialog.visible);
            const apply = fixture.dialog.standardButton(T.Dialog.Apply);
            const cancel = fixture.dialog.standardButton(T.Dialog.Cancel);
            verify(apply !== null && cancel !== null);
            verify(findChild(apply, "iaLabel") !== null, "Standard dialog buttons use IA visuals");
            click(apply);
            compare(fixture.committedSummary.text, "Saved: Avery Stone");
            verify(fixture.dialog.visible, "Apply commits without dismissing the dialog");
            click(fixture.dialogEditor);
            verify(TestProbe.keyClick(fixture.dialogEditor, Qt.Key_A, Qt.ControlModifier));
            verify(TestProbe.typeAscii(fixture.dialogEditor, "Cancelled draft"));
            click(cancel);
            tryCompare(fixture.dialog, "visible", false);
            compare(fixture.committedSummary.text, "Saved: Avery Stone");
            tryCompare(fixture.dialogOpener, "activeFocus", true);
            click(fixture.backgroundButton);
            compare(fixture.backgroundSummary.text, "Background activated");
            openWithKeyboard(fixture.dialogOpener, fixture.dialog, data.mode);
            compare(fixture.dialogEditor.text, "Avery Stone");
            verify(TestProbe.keyClick(fixture.dialogEditor, Qt.Key_Escape));
            tryCompare(fixture.dialog, "visible", false);
            compare(fixture.committedSummary.text, "Saved: Avery Stone");
        }

        function test_dialogThemePreservesDraftFocusAndOverrides_data(): var { return modes(); }
        function test_dialogThemePreservesDraftFocusAndOverrides(data: var): void {
            fixture.dialog.controlRadius = 13;
            openWithKeyboard(fixture.dialogOpener, fixture.dialog, data.mode);
            const editor = fixture.dialogEditor;
            editor.backgroundColor = "purple";
            editor.fontPixelSize = 18;
            editor.controlRadius = 9;
            tryCompare(editor, "activeFocus", true);
            verify(TestProbe.keyClick(editor, Qt.Key_A, Qt.ControlModifier));
            verify(TestProbe.typeAscii(editor, "Retained dialog draft"));
            verify(TestProbe.keyClick(editor, Qt.Key_A, Qt.ControlModifier));
            const selected = editor.selectedText;
            const light = String((fixture.dialog.background as Rectangle).color);
            const apply = fixture.dialog.standardButton(T.Dialog.Apply);
            const applyLabel = findChild(apply, "iaLabel") as Text;
            verify(applyLabel !== null);
            IA.Appearance.input = {scheme: "dark", fontScale: 1.5,
                                   tokens: {metrics: {popupRadius: 10}}};
            verify(waitForRendering(fixture.dialog.contentItem));
            assertHost(fixture.dialog, data.mode);
            compare(editor.text, "Retained dialog draft");
            compare(editor.selectedText, selected);
            verify(editor.activeFocus);
            compare(fixture.committedSummary.text, "Saved: Maya Chen");
            verify(String((fixture.dialog.background as Rectangle).color) !== light);
            compare((fixture.dialog.background as Rectangle).color, IA.Appearance.colors.popup);
            compare((fixture.dialog.background as Rectangle).radius, 13);
            compare((editor.background as Rectangle).color, "#800080");
            compare((editor.background as Rectangle).radius, 9);
            compare(editor.font.pixelSize, 18);
            compare(applyLabel.font.pixelSize, Math.round(IA.Appearance.typography.controlSize));
            editor.resetAppearance();
            fixture.dialog.resetAppearance();
            compare(editor.font.pixelSize, applyLabel.font.pixelSize);
            compare((fixture.dialog.background as Rectangle).radius, 10);
            verify(editor.activeFocus);
            click(apply);
            compare(fixture.committedSummary.text, "Saved: Retained dialog draft");
        }

        function test_dialogFooterPreservesOutline_data(): var {
            const rows = [];
            for (const host of modes()) {
                for (const scheme of ["light", "dark"])
                    rows.push({tag: host.tag + "-" + scheme, mode: host.mode, scheme: scheme});
            }
            return rows;
        }

        function test_dialogFooterPreservesOutline(data: var): void {
            IA.Appearance.input = {scheme: data.scheme};
            openWithKeyboard(fixture.dialogOpener, fixture.dialog, data.mode);
            const dialog = fixture.dialog;
            const background = dialog.background as Rectangle;
            const footer = dialog.footer;
            verify(background !== null && footer !== null);
            verify(footer.visible && footer.height > 0);
            const root = TestProbe.hostWindow(dialog.contentItem).contentItem;

            for (const customized of [false, true]) {
                if (customized) {
                    dialog.backgroundColor = "#d6e2ef";
                    dialog.borderColor = "#27445e";
                    IA.Appearance.input = {scheme: data.scheme === "light" ? "dark" : "light"};
                }
                verify(TestProbe.render(background));
                // Grab the host root: Qt 6.8 grabImage uses local rather than scene x/y.
                const pixels = grabImage(root);
                verify(pixels.width > 0 && pixels.height > 0);
                const scaleX = pixels.width / root.width;
                const scaleY = pixels.height / root.height;
                const footerCenter = footer.mapToItem(background, footer.width / 2, footer.height / 2);
                const halfBorder = background.border.width / 2;
                verify(halfBorder > 0);
                const samples = [
                    {x: halfBorder, y: footerCenter.y, color: dialog.borderColor, edge: "left footer edge"},
                    {x: background.width - halfBorder, y: footerCenter.y, color: dialog.borderColor, edge: "right footer edge"},
                    {x: background.width / 2, y: background.height - halfBorder, color: dialog.borderColor, edge: "bottom edge"},
                    {x: dialog.leftPadding + background.radius, y: footerCenter.y,
                     color: dialog.backgroundColor, edge: "surface beneath the footer"}
                ];
                for (const sample of samples) {
                    const point = background.mapToItem(root, sample.x, sample.y);
                    fuzzyCompare(pixels.pixel(Math.floor(point.x * scaleX), Math.floor(point.y * scaleY)),
                                 sample.color, 2, sample.edge + (customized ? " with local appearance" : ""));
                }
            }
        }

        function test_popupAndTooltip_data(): var { return modes(); }
        function test_popupAndTooltip(data: var): void {
            openWithKeyboard(fixture.popupOpener, fixture.popup, data.mode);
            tryCompare(fixture.popupEditor, "activeFocus", true);
            verify(TestProbe.keyClick(fixture.popupEditor, Qt.Key_A, Qt.ControlModifier));
            verify(TestProbe.typeAscii(fixture.popupEditor, "Retained filter"));
            const light = String((fixture.popup.background as Rectangle).color);
            IA.Appearance.input = {scheme: "dark", fontScale: 1.5};
            verify(waitForRendering(fixture.popup.contentItem));
            compare(fixture.popupEditor.text, "Retained filter");
            verify(fixture.popupEditor.activeFocus);
            verify(String((fixture.popup.background as Rectangle).color) !== light);
            compare(fixture.popupEditor.font.pixelSize, Math.round(IA.Appearance.typography.controlSize));
            verify(TestProbe.keyClick(fixture.popupEditor, Qt.Key_Escape));
            tryCompare(fixture.popup, "visible", false);
            tryCompare(fixture.popupOpener, "activeFocus", true);
            fixture.tooltip.open();
            assertHost(fixture.tooltip, data.mode);
            verify(fixture.popupOpener.activeFocus, "Standalone tooltip does not steal focus");
            fixture.tooltip.close();
            tryCompare(fixture.tooltip, "visible", false);
            verify(fixture.popupOpener.activeFocus);
        }
    }
}
