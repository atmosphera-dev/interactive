// SPDX-License-Identifier: LGPL-3.0-or-later
#include "TestProbe.h"

#include <QTest>
#include <QSignalSpy>
#include <QQmlEngine>
#include <QGuiApplication>
#ifdef IA_TEST_PLAYGROUND
#include "PlaygroundState.h"
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#endif

QQuickWindow *TestProbe::hostWindow(QQuickItem *item) const
{
    auto *window = item ? item->window() : nullptr;
    // Invokable QObject returns otherwise acquire JavaScript ownership. These
    // windows belong to QuickTest/the popup, not to the script receiving them.
    if (window)
        QQmlEngine::setObjectOwnership(window, QQmlEngine::CppOwnership);
    return window;
}

bool TestProbe::exposed(QQuickItem *item) const
{
    const auto *window = hostWindow(item);
    return window && window->isExposed();
}

bool TestProbe::render(QQuickItem *item, int timeout) const
{
    if (!exposed(item))
        return false;
    auto *window = item->window();
    QSignalSpy rendered(window, &QQuickWindow::frameSwapped);
    // A static, already-exposed popup need not have another frame pending.
    // Subscribe before requesting one so an earlier frame cannot satisfy this.
    window->update();
    return rendered.wait(timeout);
}

bool TestProbe::activate(QQuickItem *item) const
{
    if (!exposed(item))
        return false;
    item->window()->requestActivate();
    return true;
}

bool TestProbe::click(QQuickItem *item, qreal x, qreal y) const
{
    if (!exposed(item))
        return false;
    QTest::mouseClick(item->window(), Qt::LeftButton, Qt::NoModifier,
                      item->mapToScene(QPointF(x, y)).toPoint());
    return true;
}

bool TestProbe::press(QQuickItem *item, qreal x, qreal y) const
{
    if (!exposed(item))
        return false;
    QTest::mousePress(item->window(), Qt::LeftButton, Qt::NoModifier,
                     item->mapToScene(QPointF(x, y)).toPoint());
    return true;
}

bool TestProbe::move(QQuickItem *item, qreal x, qreal y) const
{
    if (!exposed(item))
        return false;
    QTest::mouseMove(item->window(), item->mapToScene(QPointF(x, y)).toPoint());
    return true;
}

bool TestProbe::release(QQuickItem *item, qreal x, qreal y) const
{
    if (!exposed(item))
        return false;
    QTest::mouseRelease(item->window(), Qt::LeftButton, Qt::NoModifier,
                       item->mapToScene(QPointF(x, y)).toPoint());
    return true;
}

bool TestProbe::keyClick(QQuickItem *hostItem, int key, int modifiers) const
{
    if (!exposed(hostItem))
        return false;
    QTest::keyClick(hostItem->window(), static_cast<Qt::Key>(key), Qt::KeyboardModifiers(modifiers));
    return true;
}

bool TestProbe::typeAscii(QQuickItem *hostItem, const QString &text) const
{
    if (!exposed(hostItem))
        return false;
    // This fixture uses printable ASCII. Reject unsupported input rather than
    // substituting characters or claiming to exercise IME/Unicode composition.
    for (const QChar character : text) {
        if (character.unicode() < 0x20 || character.unicode() > 0x7e)
            return false;
    }
    for (const QChar character : text)
        QTest::keyClick(hostItem->window(), character.toLatin1());
    return true;
}

QQuickItem *TestProbe::pickerItem(QObject *dialog, const QString &name) const
{
    if (!dialog)
        return nullptr;
    const QString title = dialog->property("title").toString();
    const auto windows = QGuiApplication::allWindows();
    for (auto *window : windows) {
        const auto objects = window->findChildren<QObject *>();
        for (auto *object : objects) {
            if (object == dialog || object->property("title").toString() != title)
                continue;
            auto *item = object->findChild<QQuickItem *>(name);
            if (item && item->isVisible()) {
                QQmlEngine::setObjectOwnership(item, QQmlEngine::CppOwnership);
                return item;
            }
        }
    }
    return nullptr;
}

#ifdef IA_TEST_PLAYGROUND
namespace {
PlaygroundState *probeState(const QObject *probe)
{
    auto *engine = qmlEngine(probe);
    return engine ? engine->singletonInstance<PlaygroundState *>("InterActive.Playground", "PlaygroundState") : nullptr;
}
}

bool TestProbe::freshPaletteSamples()
{
    auto *state = probeState(this);
    if (!state || !m_samples.isValid())
        return false;
    m_sampleLock.reset();
    state->setPaletteSamplePath(m_samples.filePath(QStringLiteral("samples-%1.txt").arg(++m_sampleSequence)));
    return !QFileInfo::exists(state->paletteSamplePath());
}

bool TestProbe::paletteSampleExists() const
{
    const auto *state = probeState(this);
    return state && QFileInfo::exists(state->paletteSamplePath());
}

QString TestProbe::paletteSampleBytes() const
{
    const auto *state = probeState(this);
    if (!state)
        return {};
    QFile file(state->paletteSamplePath());
    return file.open(QIODevice::ReadOnly) ? QString::fromUtf8(file.readAll()) : QString();
}

QVariantList TestProbe::paletteSamples() const
{
    QVariantList result;
    const auto bytes = paletteSampleBytes().toUtf8();
    for (const auto &line : bytes.split('\n')) {
        if (!line.isEmpty()) {
            const auto document = QJsonDocument::fromJson(line);
            if (!document.isObject())
                return {QStringLiteral("INVALID SAMPLE LINE")};
            result.append(document.object().toVariantMap());
        }
    }
    return result;
}

bool TestProbe::paletteSampleLock(bool locked)
{
    if (!locked) {
        m_sampleLock.reset();
        return true;
    }
    const auto *state = probeState(this);
    if (!state)
        return false;
    m_sampleLock = std::make_unique<QLockFile>(state->paletteSamplePath() + QStringLiteral(".lock"));
    m_sampleLock->setStaleLockTime(0);
    return m_sampleLock->tryLock(0);
}

bool TestProbe::writePaletteHistory(const QVariantList &accents, bool malformed)
{
    const auto *state = probeState(this);
    // Test fixtures cannot write a production/CLI destination.
    const QString path = m_samples.filePath(QStringLiteral("samples-%1.txt").arg(m_sampleSequence));
    if (!state || !m_samples.isValid() || m_sampleSequence <= 0 || state->paletteSamplePath() != path)
        return false;
    QByteArray bytes;
    if (malformed)
        bytes += "{invalid history}\n";
    for (const auto &value : accents) {
        const QColor accent(value.toString());
        if (!accent.isValid())
            return false;
        const auto colorObject = [](const QColor &color) {
            const auto rgba = color.rgba64();
            return QJsonObject{{"hexArgb", color.name(QColor::HexArgb)},
                {"rgba16", QJsonArray{rgba.red(), rgba.green(), rgba.blue(), rgba.alpha()}}};
        };
        const QJsonObject record{{"version", 1}, {"utc", "2026-10-04T20:00:00.000Z"},
            {"scheme", "dark"}, {"contrast", "high"}, {"accent", colorObject(accent)},
            {"amber", colorObject(QColor("#aa5500"))}, {"danger", colorObject(QColor("#440011"))},
            {"corrections", QJsonObject{{"amber", false}, {"danger", false}}}};
        bytes += QJsonDocument(record).toJson(QJsonDocument::Compact) + '\n';
    }
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    const bool written = file.write(bytes) == bytes.size() && file.flush();
    file.close();
    return written && file.error() == QFileDevice::NoError;
}

bool TestProbe::paletteHistoryReadable(bool readable)
{
    const auto *state = probeState(this);
    const QString path = m_samples.filePath(QStringLiteral("samples-%1.txt").arg(m_sampleSequence));
    if (!state || !m_samples.isValid() || m_sampleSequence <= 0 || state->paletteSamplePath() != path)
        return false;
    return QFile::setPermissions(path, readable ? QFileDevice::ReadOwner | QFileDevice::WriteOwner
                                              : QFileDevice::Permissions{});
}
#endif
