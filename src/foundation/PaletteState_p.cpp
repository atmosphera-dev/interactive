// SPDX-License-Identifier: LGPL-3.0-or-later
#include "PaletteState_p.h"
#include "AppearanceTrace_p.h"
#include <QPointer>
#include <algorithm>

namespace InterActive {

Q_LOGGING_CATEGORY(appearanceWork, "interactive.appearance.work", QtWarningMsg)

void PropertyNotifications::initialize(QObject *object, const QStringList &names)
{
    properties = names;
    if (properties.isEmpty()) {
        const auto *meta = object->metaObject();
        for (int i = meta->propertyOffset(); i < meta->propertyCount(); ++i) {
            const auto property = meta->property(i);
            if (property.hasNotifySignal() && !property.isConstant())
                properties.append(QString::fromLatin1(property.name()));
        }
    }
    const auto *meta = object->metaObject();
    for (const auto &name : properties) {
        const auto property = meta->property(meta->indexOfProperty(name.toLatin1().constData()));
        metadata.append({name, property});
        last.insert(name, property.read(object));
    }
}

void PropertyNotifications::installed(QObject *object)
{
    const AppearanceWorkScope timing("notification-compare", object);
    TraceSpan span(TraceScope::NotificationCompare, object);
    quint32 compared = 0;
    for (const auto &property : metadata) {
        ++compared;
        if (last.value(property.name) != property.metadata.read(object))
            pending.insert(property.name);
    }
    span.setAux(compared);
}

void PropertyNotifications::drain(QObject *object)
{
    const AppearanceWorkScope timing("notification-drain", object);
    TraceSpan span(TraceScope::NotificationDrain, object);
    quint32 emitted = 0;
    if (draining)
        return;
    draining = true;
    const QPointer<QObject> guard(object);
    while (!pending.isEmpty()) {
        // Property order is declaration order; nested signal order is not a contract.
        for (const auto &property : metadata) {
            if (!pending.remove(property.name))
                continue;
            const QVariant current = property.metadata.read(object);
            if (last.value(property.name) == current)
                continue;
            last.insert(property.name, current);
            ++emitted;
            property.metadata.notifySignal().invoke(object, Qt::DirectConnection);
            if (!guard)
                return;
        }
    }
    draining = false;
    span.setAux(emitted);
}

ControlFamily controlFamily(const QString &family)
{
    static const QStringList names{QStringLiteral("button"), QStringLiteral("tool"),
        QStringLiteral("field"), QStringLiteral("surface"), QStringLiteral("popup"),
        QStringLiteral("label"), QStringLiteral("delegate"), QStringLiteral("tab"),
        QStringLiteral("choice"), QStringLiteral("tooltip")};
    const int index = names.indexOf(family);
    return index < 0 ? ControlFamily::Button : ControlFamily(index);
}

const char *controlColorName(ControlColor color)
{
    static constexpr const char *names[]{"backgroundColor", "fillColor", "foregroundColor",
        "hoverBackgroundColor", "pressedBackgroundColor", "disabledBackgroundColor",
        "disabledForegroundColor", "inactiveBackgroundColor", "inactiveForegroundColor",
        "selectedBackgroundColor", "selectedForegroundColor", "borderColor",
        "disabledBorderColor", "focusColor"};
    return names[size_t(color)];
}

const QString &controlColorKey(ControlColor color)
{
    static const auto names = [] {
        std::array<QString, ControlColorCount> result;
        for (size_t i = 0; i < result.size(); ++i)
            result[i] = QString::fromLatin1(controlColorName(ControlColor(i)));
        return result;
    }();
    return names[size_t(color)];
}

ControlColorMapping controlColorMapping(ControlFamily family, Presentation::Tone tone,
                                       Presentation::Validation validation)
{
    // Finite selectors only: the finished colors already belong to the palette.
    static const auto mappings = [] {
        std::array<std::array<ControlColorMapping, 4>, 10> all{};
        for (size_t f = 0; f < all.size(); ++f) {
            ControlColorMapping neutral{ColorRole::control, ColorRole::accent, ColorRole::text,
                ColorRole::controlHover, ColorRole::controlPressed, ColorRole::disabledSurface,
                ColorRole::disabledText, ColorRole::inactiveSelection, ColorRole::text,
                ColorRole::selection, ColorRole::text, ColorRole::outline, ColorRole::outline, ColorRole::focus};
            const auto put = [&](ControlColor property, ColorRole role) { neutral[size_t(property)] = role; };
            switch (ControlFamily(f)) {
            case ControlFamily::Tool:
            case ControlFamily::Label:
            case ControlFamily::Delegate:
            case ControlFamily::Tab:
            case ControlFamily::Choice:
                put(ControlColor::backgroundColor, ColorRole::transparent);
                break;
            case ControlFamily::Field:
            case ControlFamily::Surface:
                put(ControlColor::backgroundColor, ColorRole::content);
                break;
            case ControlFamily::Popup:
                put(ControlColor::backgroundColor, ColorRole::popup);
                break;
            case ControlFamily::Tooltip:
                put(ControlColor::backgroundColor, ColorRole::tooltipBackground);
                put(ControlColor::hoverBackgroundColor, ColorRole::tooltipBackground);
                put(ControlColor::pressedBackgroundColor, ColorRole::tooltipBackground);
                put(ControlColor::foregroundColor, ColorRole::tooltipText);
                break;
            case ControlFamily::Button:
                break;
            }
            all[f][0] = neutral;
            const std::array<std::array<ColorRole, 6>, 3> semantic{{
                {ColorRole::primarySurface, ColorRole::primaryText, ColorRole::primaryHover,
                    ColorRole::primaryPressed, ColorRole::primaryOutline, ColorRole::accentText},
                {ColorRole::destructiveSurface, ColorRole::destructiveText, ColorRole::destructiveHover,
                    ColorRole::destructivePressed, ColorRole::destructiveOutline, ColorRole::errorText},
                {ColorRole::cautionSurface, ColorRole::cautionText, ColorRole::cautionHover,
                    ColorRole::cautionPressed, ColorRole::cautionOutline, ColorRole::warningText}}};
            for (size_t t = 0; t < semantic.size(); ++t) {
                auto colored = neutral;
                const auto &roles = semantic[t];
                if (ControlFamily(f) == ControlFamily::Label) {
                    colored[size_t(ControlColor::foregroundColor)] = roles[5];
                } else {
                    colored[size_t(ControlColor::backgroundColor)] = roles[0];
                    colored[size_t(ControlColor::foregroundColor)] = roles[1];
                    colored[size_t(ControlColor::hoverBackgroundColor)] = roles[2];
                    colored[size_t(ControlColor::pressedBackgroundColor)] = roles[3];
                    colored[size_t(ControlColor::selectedBackgroundColor)] = roles[3];
                    colored[size_t(ControlColor::selectedForegroundColor)] = roles[1];
                    colored[size_t(ControlColor::inactiveBackgroundColor)] = roles[0];
                    colored[size_t(ControlColor::inactiveForegroundColor)] = roles[1];
                    colored[size_t(ControlColor::borderColor)] = roles[4];
                }
                all[f][t + 1] = colored;
            }
        }
        return all;
    }();
    const size_t t = tone == Presentation::Primary ? 1 : tone == Presentation::Destructive ? 2
        : tone == Presentation::Caution ? 3 : 0;
    auto mapping = mappings[size_t(family)][t];
    if (validation != Presentation::None) {
        const auto role = validation == Presentation::Invalid ? ColorRole::errorText : ColorRole::warningText;
        mapping[size_t(ControlColor::borderColor)] = role;
        mapping[size_t(ControlColor::disabledBorderColor)] = role;
    }
    return mapping;
}

PaletteInputs PaletteInputs::from(const ResolvedAppearance &prepared)
{
    PaletteInputs input;
    input.scheme = prepared.scheme;
    input.contrast = prepared.contrast;
    input.colors = prepared.tokens.value(QStringLiteral("colors")).toMap();
    for (const auto &key : prepared.explicitTokens) {
        if (key.startsWith(QLatin1String("colors.")))
            input.presence.insert(key);
    }
    const auto motion = prepared.tokens.value(QStringLiteral("motion")).toMap();
    input.hoverBlend = motion.value(QStringLiteral("hoverBlend")).toDouble();
    input.pressedBlend = motion.value(QStringLiteral("pressedBlend")).toDouble();
    input.semanticBlend = motion.value(QStringLiteral("semanticBlend")).toDouble();
    return input;
}

bool PaletteInputs::operator==(const PaletteInputs &other) const
{
    return scheme == other.scheme && contrast == other.contrast && colors == other.colors
        && presence == other.presence && hoverBlend == other.hoverBlend
        && pressedBlend == other.pressedBlend && semanticBlend == other.semanticBlend;
}

QVariantList PaletteState::pairFindings(ColorRole foreground, ColorRole background,
                                       const QString &path, bool focus) const
{
    const auto found = std::find_if(pairs.cbegin(), pairs.cend(), [&](const DiagnosticPair &pair) {
        return pair.foreground == foreground && pair.background == background && pair.focus == focus;
    });
    Q_ASSERT(found != pairs.cend());
    QVariantList results;
    for (const auto &finding : found->findings) {
        auto entry = finding.toMap();
        entry.insert(QStringLiteral("path"), path);
        results.append(entry);
    }
    return results;
}

std::shared_ptr<const PaletteState> PaletteState::calculate(const ResolvedAppearance &prepared,
    const std::shared_ptr<const PaletteState> &previous, const void *owner, quint64 revision)
{
    const AppearanceWorkScope timing("shared-palette", owner);
    TraceSpan span(TraceScope::PaletteBuild, owner);
    qCDebug(appearanceWork).nospace() << "owner=" << owner << " revision=" << revision
        << " operation=shared-palette-build";
    auto input = prepared;
    input.diagnostics.clear();
    const auto output = TokenSchema::calculatePalette(std::move(input));
    auto state = std::make_shared<PaletteState>();
    state->values = output.tokens.value(QStringLiteral("colors")).toMap();
    state->diagnostics = output.diagnostics;
#define IA_INSTALL_COLOR(name, light, dark) \
    state->colors[size_t(ColorRole::name)] = state->values.value(QStringLiteral(#name)).value<QColor>(); \
    state->presence.set(size_t(ColorRole::name), prepared.explicitTokens.contains(QStringLiteral("colors." #name)));
    IA_COLOR_TOKENS(IA_INSTALL_COLOR)
#undef IA_INSTALL_COLOR
    state->backdrop = TokenSchema::composite(state->color(ColorRole::content), state->color(ColorRole::canvas));
    state->target = prepared.contrast == QLatin1String("high") ? 7 : 5;
    const auto motion = prepared.tokens.value(QStringLiteral("motion")).toMap();
    state->hoverBlend = motion.value(QStringLiteral("hoverBlend")).toDouble();
    state->pressedBlend = motion.value(QStringLiteral("pressedBlend")).toDouble();
    const auto addPair = [&](ColorRole foreground, ColorRole background, bool focus = false) {
        const auto descriptorMatches = [&](const DiagnosticPair &pair) {
            return pair.foreground == foreground && pair.background == background && pair.focus == focus;
        };
        if (std::any_of(state->pairs.cbegin(), state->pairs.cend(), descriptorMatches))
            return;
        DiagnosticPair pair{foreground, background, focus, {}};
        const qreal required = focus ? 3 : state->target;
        bool reused = false;
        if (previous && previous->backdrop == state->backdrop && (focus || previous->target == state->target)
            && previous->color(foreground) == state->color(foreground)
            && previous->color(background) == state->color(background)) {
            const auto old = std::find_if(previous->pairs.cbegin(), previous->pairs.cend(), descriptorMatches);
            if (old != previous->pairs.cend()) {
                pair.findings = old->findings;
                reused = true;
            }
        }
        if (!reused) {
            qCDebug(appearanceWork).nospace() << "owner=" << owner << " revision=" << revision
                << " operation=shared-pair-measurement foreground=" << int(foreground)
                << " background=" << int(background);
            AppearanceTrace::counter(TraceScope::PaletteBuild, owner, 2); // measured pair
            TokenSchema::checkContrast(&pair.findings, {}, state->color(foreground),
                focus ? state->backdrop : TokenSchema::composite(state->color(background), state->backdrop), required);
        } else {
            AppearanceTrace::counter(TraceScope::PaletteBuild, owner, 1); // reused pair
        }
        state->pairs.append(std::move(pair));
    };
    for (int f = 0; f <= int(ControlFamily::Tooltip); ++f) {
        for (const auto tone : {Presentation::Neutral, Presentation::Primary, Presentation::Destructive, Presentation::Caution}) {
            const auto roles = controlColorMapping(ControlFamily(f), tone, Presentation::None);
            for (const auto surface : {ControlColor::backgroundColor, ControlColor::hoverBackgroundColor,
                     ControlColor::pressedBackgroundColor})
                addPair(roles[size_t(ControlColor::foregroundColor)], roles[size_t(surface)]);
            addPair(roles[size_t(ControlColor::selectedForegroundColor)], roles[size_t(ControlColor::selectedBackgroundColor)]);
            addPair(roles[size_t(ControlColor::inactiveForegroundColor)], roles[size_t(ControlColor::inactiveBackgroundColor)]);
        }
    }
    addPair(ColorRole::focus, ColorRole::content, true);
    return state;
}

const std::shared_ptr<const PaletteState> &PaletteState::fallback()
{
    // Pure constants only. Font/application/engine state is deliberately absent.
    static const auto state = calculate(TokenSchema::prepare({}, QStringLiteral("Sans Serif")), {}, nullptr, 0);
    return state;
}

} // namespace InterActive
