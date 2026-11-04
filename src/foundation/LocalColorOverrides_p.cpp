// SPDX-License-Identifier: LGPL-3.0-or-later
#include "LocalColorOverrides_p.h"
#include "AppearanceTrace_p.h"

namespace InterActive {

QColor LocalColorOverrides::Branch::evaluate(const QVariantList &next,
    const std::function<QColor()> &calculate, const char *operation, const void *owner, quint64 revision)
{
    if (!valid || inputs != next) {
        qCDebug(appearanceWork).nospace() << "owner=" << owner << " revision=" << revision
            << " operation=local-derivation branch=" << operation;
        const TraceAggregate aggregated(TraceScope::AggLocalDerivation, 0);
        result = calculate();
        inputs = next;
        valid = true;
    }
    return result;
}

QColor LocalColorOverrides::color(ControlColor property, const PaletteState &palette,
                                  const ControlColorMapping &mapping) const
{
    if (m_values.isEmpty())
        return palette.color(mapping[size_t(property)]);
    const auto found = m_values.constFind(controlColorKey(property));
    return found == m_values.cend() ? palette.color(mapping[size_t(property)]) : found->value<QColor>();
}

void LocalColorOverrides::install(const PaletteState &palette, const ControlColorMapping &mapping,
    const QVariantMap &overrides, bool coupleBorder, const void *owner, quint64 revision)
{
    const AppearanceWorkScope timing("local-colors", owner);
    TraceSpan span(TraceScope::LocalInstall, owner);
    QVariantMap values;
    for (size_t i = 0; i < ControlColorCount; ++i) {
        const auto &name = controlColorKey(ControlColor(i));
        if (overrides.contains(name))
            values.insert(name, overrides.value(name));
    }
    m_findings = palette.controlFindings(mapping);
    if (values.isEmpty()) {
        m_resting.valid = m_hover.valid = m_pressed.valid = m_foreground.valid = m_selected.valid = m_inactive.valid = false;
        for (auto &pair : m_pairs)
            pair.valid = false;
        m_values.clear();
        return;
    }
    const auto name = [](ControlColor property) -> const QString & { return controlColorKey(property); };
    const auto explicitLocal = [&](ControlColor property) { return overrides.contains(name(property)); };
    const auto effective = [&](ControlColor property) {
        return values.contains(name(property)) ? values.value(name(property)).value<QColor>() : palette.color(mapping[size_t(property)]);
    };
    const auto put = [&](ControlColor property, const QColor &value) { values.insert(name(property), value); };
    const QColor base = effective(ControlColor::backgroundColor);
    const QColor backdrop = palette.backdrop;
    const qreal target = palette.target;
    const qreal labelTarget = palette.labelTarget;
    const bool backgroundOwned = explicitLocal(ControlColor::backgroundColor);
    const bool foregroundOwned = explicitLocal(ControlColor::foregroundColor);
    if (backgroundOwned) {
        const QColor resting = foregroundOwned ? effective(ControlColor::foregroundColor)
            : m_resting.evaluate({base, backdrop, labelTarget, true, false}, [&] {
                return TokenSchema::contrastingText(base, {base}, backdrop, labelTarget);
            }, "resting-foreground", owner, revision);
        if (!explicitLocal(ControlColor::hoverBackgroundColor)) {
            put(ControlColor::hoverBackgroundColor, m_hover.evaluate({base, resting, palette.hoverBlend,
                backdrop, labelTarget, foregroundOwned}, [&] {
                    return TokenSchema::feedbackSurface(base, resting, palette.hoverBlend);
                }, "hover-feedback", owner, revision));
        } else {
            m_hover.valid = false;
        }
        if (!explicitLocal(ControlColor::pressedBackgroundColor)) {
            put(ControlColor::pressedBackgroundColor, m_pressed.evaluate({base, resting, palette.pressedBlend,
                backdrop, labelTarget, foregroundOwned}, [&] {
                    return TokenSchema::feedbackSurface(base, resting, palette.pressedBlend);
                }, "pressed-feedback", owner, revision));
        } else {
            m_pressed.valid = false;
        }
        if (foregroundOwned)
            m_resting.valid = false;
    } else {
        m_resting.valid = m_hover.valid = m_pressed.valid = false;
    }
    const bool hoverOwned = explicitLocal(ControlColor::hoverBackgroundColor);
    const bool pressedOwned = explicitLocal(ControlColor::pressedBackgroundColor);
    if (!foregroundOwned && (backgroundOwned || hoverOwned || pressedOwned)) {
        const QColor hover = effective(ControlColor::hoverBackgroundColor);
        const QColor pressed = effective(ControlColor::pressedBackgroundColor);
        put(ControlColor::foregroundColor, m_foreground.evaluate({base, hover, pressed, backdrop, labelTarget,
            backgroundOwned, hoverOwned, pressedOwned}, [&] {
                return TokenSchema::contrastingText(base, {base, hover, pressed}, backdrop, labelTarget);
            }, "ordinary-foreground", owner, revision));
    } else {
        m_foreground.valid = false;
    }
    const auto pairedText = [&](ControlColor background, ControlColor foreground, Branch &branch, const char *operation) {
        if (explicitLocal(background) && !explicitLocal(foreground)) {
            const QColor surface = effective(background);
            put(foreground, branch.evaluate({surface, backdrop, labelTarget, true, false}, [&] {
                return TokenSchema::contrastingText(surface, {surface}, backdrop, labelTarget);
            }, operation, owner, revision));
        } else {
            branch.valid = false;
        }
    };
    pairedText(ControlColor::selectedBackgroundColor, ControlColor::selectedForegroundColor, m_selected, "selected-foreground");
    pairedText(ControlColor::inactiveBackgroundColor, ControlColor::inactiveForegroundColor, m_inactive, "inactive-foreground");
    if (coupleBorder && !explicitLocal(ControlColor::borderColor)
        && values.contains(name(ControlColor::foregroundColor)))
        put(ControlColor::borderColor, effective(ControlColor::foregroundColor));
    if (explicitLocal(ControlColor::borderColor) && !explicitLocal(ControlColor::disabledBorderColor))
        put(ControlColor::disabledBorderColor, effective(ControlColor::borderColor));

    std::shared_ptr<ControlFindings> localFindings;
    for (size_t i = 0; i < ControlDiagnosticPairs.size(); ++i) {
        const auto [foreground, background] = ControlDiagnosticPairs[i];
        const bool focus = i == 5;
        const QString path = name(foreground) + QLatin1Char('/') + (focus ? QStringLiteral("content") : name(background));
        const bool localText = values.contains(name(foreground));
        const bool localSurface = !focus && values.contains(name(background));
        const bool locallyMeasured = localText || localSurface;
        auto &pair = m_pairs[i];
        if (!locallyMeasured) {
            pair.valid = false;
            continue;
        }
        const QColor text = effective(foreground);
        const QColor surface = focus ? backdrop : effective(background);
        const qreal required = focus ? 3 : target;
        const QVariantList inputs{text, surface, backdrop, required, localText, localSurface};
        if (!pair.valid || pair.inputs != inputs) {
            qCDebug(appearanceWork).nospace() << "owner=" << owner << " revision=" << revision
                << " operation=local-pair-measurement pair=" << i;
            const TraceAggregate aggregated(TraceScope::AggLocalPairMeasure, quint16(i));
            pair.findings.clear();
            TokenSchema::checkContrast(&pair.findings, path, text,
                focus ? backdrop : TokenSchema::composite(surface, backdrop), required);
            pair.inputs = inputs;
            pair.valid = true;
        }
        if (!localFindings)
            localFindings = std::make_shared<ControlFindings>(*m_findings);
        (*localFindings)[i] = pair.findings;
    }
    m_values = std::move(values);
    if (localFindings)
        m_findings = std::move(localFindings);
}

} // namespace InterActive
