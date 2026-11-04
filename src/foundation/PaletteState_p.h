// SPDX-License-Identifier: LGPL-3.0-or-later
#pragma once

// Private Foundation state and finite ordinary-control projections.
#include "TokenDefinitions.h"
#include "TokenSchema.h"
#include "Presentation.h"
#include <QLoggingCategory>
#include <QElapsedTimer>
#include <QMetaProperty>
#include <QObject>
#include <array>
#include <bitset>
#include <memory>
#include <map>

namespace InterActive {

Q_DECLARE_LOGGING_CATEGORY(appearanceWork)

class AppearanceWorkScope {
public:
    AppearanceWorkScope(const char *scope, const void *owner) : m_scope(scope), m_owner(owner)
    {
        if (appearanceWork().isDebugEnabled())
            m_timer.start();
    }
    ~AppearanceWorkScope()
    {
        if (m_timer.isValid())
            qCDebug(appearanceWork).nospace() << "owner=" << m_owner << " operation=timing scope="
                << m_scope << " elapsedNs=" << m_timer.nsecsElapsed();
    }
private:
    const char *m_scope;
    const void *m_owner;
    QElapsedTimer m_timer;
};

enum class ColorRole {
#define IA_ROLE(name, light, dark) name,
    IA_COLOR_TOKENS(IA_ROLE)
#undef IA_ROLE
    Count
};
constexpr size_t ColorRoleCount = size_t(ColorRole::Count);
using ColorRoleMask = std::bitset<ColorRoleCount>;

enum class ControlColor {
    backgroundColor, fillColor, foregroundColor, hoverBackgroundColor,
    pressedBackgroundColor, disabledBackgroundColor, disabledForegroundColor,
    inactiveBackgroundColor, inactiveForegroundColor, selectedBackgroundColor,
    selectedForegroundColor, borderColor, disabledBorderColor, focusColor, Count
};
constexpr size_t ControlColorCount = size_t(ControlColor::Count);
using ControlColorMapping = std::array<ColorRole, ControlColorCount>;
using ControlFindings = std::array<QVariantList, 6>;
inline constexpr std::array<std::pair<ControlColor, ControlColor>, 6> ControlDiagnosticPairs{{
    {ControlColor::foregroundColor, ControlColor::backgroundColor},
    {ControlColor::foregroundColor, ControlColor::hoverBackgroundColor},
    {ControlColor::foregroundColor, ControlColor::pressedBackgroundColor},
    {ControlColor::selectedForegroundColor, ControlColor::selectedBackgroundColor},
    {ControlColor::inactiveForegroundColor, ControlColor::inactiveBackgroundColor},
    {ControlColor::focusColor, ControlColor::backgroundColor}}};

enum class ControlFamily { Button, Tool, Field, Surface, Popup, Label, Delegate, Tab, Choice, Tooltip };
ControlFamily controlFamily(const QString &family);
const char *controlColorName(ControlColor color);
const QString &controlColorKey(ControlColor color);
ControlColorMapping controlColorMapping(ControlFamily family, Presentation::Tone tone,
                                       Presentation::Validation validation);

struct PaletteInputs {
    QString scheme;
    QString contrast;
    QVariantMap colors;
    QSet<QString> presence;
    qreal hoverBlend = 0;
    qreal pressedBlend = 0;
    qreal semanticBlend = 0;
    static PaletteInputs from(const ResolvedAppearance &prepared);
    bool operator==(const PaletteInputs &other) const;
};

struct DiagnosticPair {
    ColorRole foreground;
    ColorRole background;
    bool focus = false;
    QVariantList findings;
};

struct PaletteState {
    std::array<QColor, ColorRoleCount> colors;
    ColorRoleMask presence;
    QVariantMap values;
    QVariantList diagnostics;
    QColor backdrop;
    qreal target = 5; // Readability/diagnostic floor, independent of label derivation.
    qreal labelTarget = LabelContrastTarget;
    qreal hoverBlend = 0.08;
    qreal pressedBlend = 0.16;
    QList<DiagnosticPair> pairs;

    QColor color(ColorRole role) const { return colors[size_t(role)]; }
    bool explicitRole(ColorRole role) const { return presence.test(size_t(role)); }
    QVariantList pairFindings(ColorRole foreground, ColorRole background,
                              const QString &path, bool focus = false) const;
    std::shared_ptr<const ControlFindings> controlFindings(const ControlColorMapping &mapping) const;
    static std::shared_ptr<const PaletteState> calculate(const ResolvedAppearance &prepared,
        const std::shared_ptr<const PaletteState> &previous, const void *owner, quint64 revision);
    static const std::shared_ptr<const PaletteState> &fallback();
private:
    // GUI-thread memoization of diagnostic projections only, not color/state tables.
    mutable std::map<ControlColorMapping, std::shared_ptr<const ControlFindings>> m_controlFindings;
};

struct AppearanceState {
    quint64 revision = 0;
    ResolvedAppearance snapshot;
    std::shared_ptr<const PaletteState> palette;
};
using AppearanceStatePtr = std::shared_ptr<const AppearanceState>;

enum NoncolorGroup : quint8 { MetricsGroup = 1, TypographyGroup = 2, MotionGroup = 4, IconsGroup = 8 };

struct PaletteUpdate {
    AppearanceStatePtr before;
    AppearanceStatePtr after;
    ColorRoleMask changedRoles;
    ColorRoleMask changedPresence;
    quint8 changedGroups = 0;
    static PaletteUpdate between(const AppearanceStatePtr &before, const AppearanceStatePtr &after);
};

// Same-stack notification obligations, separate from calculation/publication.
// Nested installation compares with last-notified values, not an obsolete delta.
struct PropertyNotifications {
    struct Property { QString name; QMetaProperty metadata; };
    QVariantMap last;
    QSet<QString> pending;
    QStringList properties;
    QList<Property> metadata;
    bool draining = false;
    void initialize(QObject *object, const QStringList &names = {});
    void installed(QObject *object);
    void drain(QObject *object);
};

} // namespace InterActive
