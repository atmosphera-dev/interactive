// SPDX-License-Identifier: LGPL-3.0-or-later
import QtQuick
import QtQuick.Templates as T
import QtTest
import InterActive.Foundation as IA
import InterActive.Tests
import "iconconsumer" as Consumer

Rectangle {
    id: scene
    width: 640
    height: 200
    color: "white"
    Component { id: consumerComponent; Consumer.IconConsumer {} }
    TestCase {
        name: "IconSources"
        when: windowShown

        function iconIn(item: Item): IA.Icon {
            for (const child of item.children) {
                const icon = child as IA.Icon;
                if (icon !== null && icon.visible)
                    return icon;
                const nested = iconIn(child);
                if (nested !== null)
                    return nested;
            }
            return null;
        }

        function test_relativeConsumerSource_data(): var {
            const rows = [];
            const types = ["button", "tool", "tab", "delegate", "menuItem"];
            for (let i = 0; i < types.length; ++i) {
                for (const mode of ["original", "missingName", "tinted"]) {
                    rows.push({tag: types[i] + "-" + mode, index: i, mode: mode});
                }
            }
            return rows;
        }

        function test_relativeConsumerSource(data: var): void {
            const fixture = createTemporaryObject(consumerComponent, scene, {
                requestedName: data.mode === "missingName" ? "__ia_nonexistent_fixture_icon__" : "",
                tint: data.mode === "tinted" ? "#80c04020" : "transparent"
            }) as Consumer.IconConsumer;
            verify(fixture !== null);
            const control = fixture.controls[data.index] as T.AbstractButton;
            verify(control !== null);
            const icon = iconIn(control.contentItem);
            verify(icon !== null);
            let sourceImage = null;
            for (const child of icon.children) {
                if (child instanceof Image)
                    sourceImage = child as Image;
            }
            verify(sourceImage !== null);
            tryCompare(sourceImage, "status", Image.Ready, 1000);
            compare(sourceImage.source, Qt.resolvedUrl("iconconsumer/icons/consumer-mark.svg"));
            compare(control.icon.source.toString(), "icons/consumer-mark.svg", "Do not mutate the caller's icon input");
            verify(TestProbe.render(icon));
            // Qt 6.8 grabImage crops by local x/y, so grab the root and map the sample into it.
            const pixels = grabImage(scene);
            verify(pixels.width > 0 && pixels.height > 0);
            const point = icon.mapToItem(scene, icon.width / 2, icon.height / 2);
            const background = (control.background as Rectangle).color;
            const alpha = 128 / 255;
            const expected = data.mode === "tinted"
                ? Qt.rgba(192 / 255 * alpha + (background.r * background.a + 1 - background.a) * (1 - alpha),
                          64 / 255 * alpha + (background.g * background.a + 1 - background.a) * (1 - alpha),
                          32 / 255 * alpha + (background.b * background.a + 1 - background.a) * (1 - alpha), 1)
                : Qt.rgba(32 / 255, 160 / 255, 96 / 255, 1);
            fuzzyCompare(pixels.pixel(Math.floor(point.x * pixels.width / scene.width),
                                      Math.floor(point.y * pixels.height / scene.height)),
                         expected, 2, "Consumer-relative icon pixels, including tint alpha composited over the surface");
        }
    }
}
