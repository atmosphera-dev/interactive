// SPDX-License-Identifier: LGPL-3.0-or-later
#pragma once

#include <QObject>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtQml/qqmlregistration.h>
#ifdef IA_TEST_PLAYGROUND
#include <QTemporaryDir>
#include <QLockFile>
#include <memory>
#endif

// Public Qt APIs only: a popup's content item identifies its effective host.
class TestProbe : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
public:
    explicit TestProbe(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE QQuickWindow *hostWindow(QQuickItem *item) const;
    Q_INVOKABLE bool exposed(QQuickItem *item) const;
    Q_INVOKABLE bool render(QQuickItem *item, int timeout = 5000) const;
    Q_INVOKABLE bool activate(QQuickItem *item) const;
    Q_INVOKABLE bool click(QQuickItem *item, qreal x, qreal y) const;
    Q_INVOKABLE bool press(QQuickItem *item, qreal x, qreal y) const;
    Q_INVOKABLE bool move(QQuickItem *item, qreal x, qreal y) const;
    Q_INVOKABLE bool release(QQuickItem *item, qreal x, qreal y) const;
    Q_INVOKABLE bool keyClick(QQuickItem *hostItem, int key, int modifiers = 0) const;
    Q_INVOKABLE bool isWayland() const;
    Q_INVOKABLE bool nativeKeyHostReady(QQuickItem *hostItem) const;
    Q_INVOKABLE bool nativeKeyClick(QQuickItem *hostItem, int key) const;
    Q_INVOKABLE bool typeAscii(QQuickItem *hostItem, const QString &text) const;
    Q_INVOKABLE QStringList appearanceProperties(QObject *control) const;
    // Capture tooling only: snapshots include the actual parent/window clipping.
    Q_INVOKABLE QString captureDirectory() const;
    Q_INVOKABLE bool createCaptureMode(const QString &mode) const;
    Q_INVOKABLE QString captureDataUrl(QQuickItem *item, qreal margin) const;
    Q_INVOKABLE bool writeCaptureManifest(const QString &text) const;
    // Only tests may inspect Qt's fallback picker implementation.
    Q_INVOKABLE QQuickItem *pickerItem(QObject *dialog, const QString &name) const;
#ifdef IA_TEST_PLAYGROUND
    Q_INVOKABLE bool freshPaletteSamples();
    Q_INVOKABLE bool paletteSampleExists() const;
    Q_INVOKABLE QString paletteSampleBytes() const;
    Q_INVOKABLE QVariantList paletteSamples() const;
    Q_INVOKABLE bool paletteSampleLock(bool locked);
    Q_INVOKABLE bool writePaletteHistory(const QVariantList &accents, bool malformed = false);
    Q_INVOKABLE bool paletteHistoryReadable(bool readable);
private:
    QTemporaryDir m_samples;
    int m_sampleSequence = 0;
    std::unique_ptr<QLockFile> m_sampleLock;
#endif
};
