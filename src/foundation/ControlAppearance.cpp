// SPDX-License-Identifier: LGPL-3.0-or-later
#include "ControlAppearance.h"
#include "AirmailProfiles.h"
#include "AppearanceTrace_p.h"
#include "FontEnvironment_p.h"
#include "LocalColorOverrides_p.h"
#include <QFontMetricsF>
#include <QStringList>
#include <algorithm>
#include <cmath>

namespace InterActive {

struct ControlAppearancePrivate {
    AppearanceStatePtr sourceState;
    std::shared_ptr<const PaletteState> palette = PaletteState::fallback();
    ControlColorMapping mapping = controlColorMapping(ControlFamily::Button, Presentation::Auto, Presentation::None);
    LocalColorOverrides local;
    PropertyNotifications notifications;
    FontEnvironment *environment = nullptr;
    QVariantList noncolorInputs;
    QVariantList fontInputs;
    QVariantList heightInputs;
    qreal textHeight = 0;
    quint64 revision = 0;
};

namespace {
ResolvedAppearance fallbackNoncolors()
{
    ResolvedAppearance defaults;
    defaults.tokens = AirmailProfiles::profile(defaults.scheme, Appearance::initialFontFamily());
    defaults.tokens.remove(QStringLiteral("colors"));
    return defaults;
}
}

ControlAppearance::ControlAppearance(QObject *parent)
    : QObject(parent), m_defaults(fallbackNoncolors()), m_private(new ControlAppearancePrivate)
{
    m_private->environment = new FontEnvironment(this);
    connect(m_private->environment, &FontEnvironment::invalidated, this, &ControlAppearance::resolve);
    resolve();
    m_private->notifications.initialize(this);
}

ControlAppearance::~ControlAppearance() = default;

#define IA_COLOR_GETTER(type, name, upper, group, token) \
    type ControlAppearance::name() const { return m_private->local.color(ControlColor::name, \
        *m_private->palette, m_private->mapping); }
IA_CONTROL_COLOR_PROPERTIES(IA_COLOR_GETTER)
#undef IA_COLOR_GETTER
#define IA_NONCOLOR_GETTER(type, name, upper, group, token) \
    type ControlAppearance::name() const { return m_values.value(QStringLiteral(#name)).value<type>(); }
IA_CONTROL_NONCOLOR_PROPERTIES(IA_NONCOLOR_GETTER)
#undef IA_NONCOLOR_GETTER

void ControlAppearance::setSource(Appearance *source)
{
    if (m_source == source)
        return;
    disconnect(m_sourceChanged);
    disconnect(m_sourceDestroyed);
    m_source = source;
    if (source) {
        m_sourceChanged = connect(source, &Appearance::completed, this, [this, source](const PaletteUpdate &) {
            if (m_source == source)
                resolve();
        });
        m_sourceDestroyed = connect(source, &QObject::destroyed, this, [this] {
            m_source = nullptr;
            resolve();
        });
    }
    resolve();
}

void ControlAppearance::setFamily(const QString &family)
{
    const QStringList families{QStringLiteral("button"), QStringLiteral("tool"), QStringLiteral("field"),
                               QStringLiteral("surface"), QStringLiteral("popup"), QStringLiteral("label"),
                               QStringLiteral("delegate"), QStringLiteral("tab"), QStringLiteral("choice"),
                               QStringLiteral("tooltip")};
    if (!families.contains(family)) {
        m_invalidInputs.insert(QStringLiteral("family"), TokenSchema::diagnostic(QStringLiteral("family"),
            QStringLiteral("invalid-value"), QStringLiteral("Unknown family; previous family retained.")));
        resolve();
        return;
    }
    const bool hadError = m_invalidInputs.remove(QStringLiteral("family"));
    if (m_family == family && !hadError)
        return;
    m_family = family;
    resolve();
}

void ControlAppearance::setTone(Presentation::Tone tone)
{
    if (tone < Presentation::Auto || tone > Presentation::Caution) {
        m_invalidInputs.insert(QStringLiteral("tone"), TokenSchema::diagnostic(QStringLiteral("tone"),
            QStringLiteral("invalid-value"), QStringLiteral("Unknown tone; previous tone retained.")));
        resolve();
        return;
    }
    const bool hadError = m_invalidInputs.remove(QStringLiteral("tone"));
    if (m_tone == tone && !hadError)
        return;
    m_tone = tone;
    resolve();
}

void ControlAppearance::setValidation(Presentation::Validation validation)
{
    if (validation < Presentation::None || validation > Presentation::Invalid) {
        m_invalidInputs.insert(QStringLiteral("validation"), TokenSchema::diagnostic(QStringLiteral("validation"),
            QStringLiteral("invalid-value"), QStringLiteral("Unknown validation; previous value retained.")));
        resolve();
        return;
    }
    const bool hadError = m_invalidInputs.remove(QStringLiteral("validation"));
    if (m_validation == validation && !hadError)
        return;
    m_validation = validation;
    resolve();
}

#define IA_LOCAL_METHODS(type, name, upper, group, token) \
    void ControlAppearance::set##upper(const type &value) \
    { setOverride(QStringLiteral(#name), QStringLiteral(#group), QStringLiteral(#token), QVariant::fromValue(value)); } \
    void ControlAppearance::reset##upper() { resetOverride(QStringLiteral(#name)); }
IA_CONTROL_PROPERTIES(IA_LOCAL_METHODS)
#undef IA_LOCAL_METHODS

void ControlAppearance::setOverride(const QString &name, const QString &group, const QString &token, const QVariant &value)
{
    QVariant normalized;
    QVariantList diagnostics;
    if (!TokenSchema::validate(group, token, value, &normalized, &diagnostics, name, true)) {
        m_invalidInputs.insert(name, diagnostics.first());
        resolve();
        return;
    }
    const bool hadError = m_invalidInputs.remove(name);
    if (m_overrides.contains(name) && m_overrides.value(name) == normalized && !hadError)
        return;
    // Presence, not comparison with the effective value, defines an override.
    m_overrides.insert(name, normalized);
    resolve();
}

void ControlAppearance::resetOverride(const QString &name)
{
    const bool removed = m_overrides.remove(name);
    const bool hadError = m_invalidInputs.remove(name);
    if (removed || hadError)
        resolve();
}

void ControlAppearance::resetOverrides()
{
    if (m_overrides.isEmpty() && m_invalidInputs.isEmpty())
        return;
    m_overrides.clear();
    m_invalidInputs.clear();
    resolve();
}

void ControlAppearance::resolve()
{
    const AppearanceWorkScope timing("facade-update", this);
    TraceSpan span(TraceScope::FacadeResolve, this);
    auto &state = *m_private;
    // Own the installed source reference across every callback. Read the newest
    // source state, not the earlier dispatch mask, if an observer reentered it.
    state.sourceState = m_source ? m_source->m_state : AppearanceStatePtr();
    const auto &profile = state.sourceState ? state.sourceState->snapshot : m_defaults;
    state.palette = state.sourceState ? state.sourceState->palette : PaletteState::fallback();
    state.revision = state.sourceState ? state.sourceState->revision : state.revision + 1;
    const auto family = controlFamily(m_family);
    state.mapping = controlColorMapping(family, m_tone, m_validation);
    const bool colored = m_tone == Presentation::Primary || m_tone == Presentation::Destructive || m_tone == Presentation::Caution;
    const bool coupleBorder = colored && family != ControlFamily::Label && m_validation == Presentation::None
        && !state.palette->explicitRole(state.mapping[size_t(ControlColor::borderColor)]);
    state.local.install(*state.palette, state.mapping, m_overrides, coupleBorder, this, state.revision);

    const auto metrics = profile.tokens.value(QStringLiteral("metrics")).toMap();
    const auto typography = profile.tokens.value(QStringLiteral("typography")).toMap();
    QVariantMap noncolorOverrides;
#define IA_NONCOLOR_OVERRIDE(type, name, upper, group, token) \
    if (m_overrides.contains(QStringLiteral(#name))) \
        noncolorOverrides.insert(QStringLiteral(#name), m_overrides.value(QStringLiteral(#name)));
    IA_CONTROL_NONCOLOR_PROPERTIES(IA_NONCOLOR_OVERRIDE)
#undef IA_NONCOLOR_OVERRIDE
    const QVariantList inputs{metrics, typography, noncolorOverrides, m_family, profile.density,
        QVariant::fromValue(state.environment->generation())};
    if (state.noncolorInputs != inputs) {
        QVariantMap candidate;
#define IA_NONCOLOR_DEFAULT(type, name, upper, group, token) \
        candidate.insert(QStringLiteral(#name), group.value(QStringLiteral(#token)));
        IA_CONTROL_NONCOLOR_PROPERTIES(IA_NONCOLOR_DEFAULT)
#undef IA_NONCOLOR_DEFAULT
        if (family == ControlFamily::Popup) {
            candidate.insert(QStringLiteral("controlRadius"), metrics.value(QStringLiteral("popupRadius")));
            candidate.insert(QStringLiteral("horizontalPadding"), metrics.value(QStringLiteral("popupPadding")));
            candidate.insert(QStringLiteral("verticalPadding"), metrics.value(QStringLiteral("popupPadding")));
        }
        if (family == ControlFamily::Tooltip)
            candidate.insert(QStringLiteral("fontPixelSize"), typography.value(QStringLiteral("supportingSize")));
        if (family == ControlFamily::Tool)
            candidate.insert(QStringLiteral("minimumHeight"), metrics.value(QStringLiteral("toolHeight")));
        if (family == ControlFamily::Delegate || family == ControlFamily::Tab)
            candidate.insert(QStringLiteral("minimumHeight"), metrics.value(QStringLiteral("rowHeight")));
        const bool interactive = family != ControlFamily::Label && family != ControlFamily::Surface
            && family != ControlFamily::Popup && family != ControlFamily::Tooltip;
        if (!interactive)
            candidate.insert(QStringLiteral("minimumHeight"), qreal(0));
        for (auto it = noncolorOverrides.cbegin(); it != noncolorOverrides.cend(); ++it)
            candidate.insert(it.key(), it.value());
        const QString requestedFamily = candidate.value(QStringLiteral("fontFamily")).toString();
        const int pixelSize = std::max(1, qRound(candidate.value(QStringLiteral("fontPixelSize")).toDouble()));
        const int weight = candidate.value(QStringLiteral("fontWeight")).toInt();
        const QVariantList fontInputs{requestedFamily, pixelSize, weight,
            QVariant::fromValue(state.environment->generation())};
        if (state.fontInputs != fontInputs) {
            qCDebug(appearanceWork).nospace() << "owner=" << this << " revision=" << state.revision
                << " operation=font-construction";
            QFont font;
            font.setFamily(requestedFamily);
            font.setPixelSize(pixelSize);
            font.setWeight(static_cast<QFont::Weight>(weight));
            qCDebug(appearanceWork).nospace() << "owner=" << this << " revision=" << state.revision
                << " operation=font-measurement";
            state.textHeight = std::ceil(QFontMetricsF(font).height());
            m_font = font;
            state.fontInputs = fontInputs;
        }
        // Keep the requested floor, never yesterday's derived output, in the key.
        const qreal requestedFloor = candidate.value(QStringLiteral("minimumHeight")).toDouble();
        const qreal padding = candidate.value(QStringLiteral("verticalPadding")).toDouble();
        const qreal targetFloor = interactive && profile.density == QLatin1String("touch")
            ? metrics.value(QStringLiteral("targetSize")).toDouble() : 0;
        const QVariantList heightInputs{requestedFloor, padding, targetFloor, state.textHeight};
        qreal minimum = m_values.value(QStringLiteral("minimumHeight")).toDouble();
        if (state.heightInputs != heightInputs) {
            qCDebug(appearanceWork).nospace() << "owner=" << this << " revision=" << state.revision
                << " operation=geometry-calculation";
            minimum = std::max({requestedFloor, state.textHeight + 2 * padding, targetFloor});
            state.heightInputs = heightInputs;
        }
        candidate.insert(QStringLiteral("minimumHeight"), minimum);
        m_values = std::move(candidate);
        state.noncolorInputs = inputs;
    }
    QVariantList diagnostics;
    for (auto it = m_invalidInputs.cbegin(); it != m_invalidInputs.cend(); ++it)
        diagnostics.append(it.value());
    diagnostics.append(state.local.diagnostics());
    m_diagnostics = std::move(diagnostics);
    state.notifications.installed(this);
    const QPointer<ControlAppearance> guard(this);
    emit resolvedChanged();
    if (guard)
        state.notifications.drain(this);
}

} // namespace InterActive
