// SPDX-License-Identifier: LGPL-3.0-or-later
#include "TokenSchema.h"
#include "AirmailProfiles.h"
#include "AppearanceTrace_p.h"
#include "TokenDefinitions.h"
#include "cpp/cam/cam.h"
#include "cpp/cam/hct.h"
#include "cpp/contrast/contrast.h"
#include "cpp/utils/utils.h"
#include <QElapsedTimer>
#include <QLoggingCategory>
#include <QMetaType>
#include <QStringList>
#include <QUrl>
#include <algorithm>
#include <cmath>
#include <limits>

namespace InterActive {
namespace {

bool numeric(const QVariant &value)
{
    switch (value.metaType().id()) {
    case QMetaType::Int:
    case QMetaType::UInt:
    case QMetaType::LongLong:
    case QMetaType::ULongLong:
    case QMetaType::Double:
    case QMetaType::Float:
    case QMetaType::Short:
    case QMetaType::UShort:
    case QMetaType::Long:
    case QMetaType::ULong:
        return true;
    default:
        return false;
    }
}

bool numberInRange(const QVariant &value, qreal low, qreal high, bool integer = false)
{
    if (!numeric(value))
        return false;
    const double n = value.toDouble();
    return std::isfinite(n) && n >= low && n <= high && (!integer || n == std::floor(n));
}

QVariantMap definition(const QString &kind, qreal minimum = 0, qreal maximum = 0)
{
    return {{QStringLiteral("type"), kind}, {QStringLiteral("minimum"), minimum},
            {QStringLiteral("maximum"), maximum}};
}

qreal luminance(const QColor &color)
{
    const auto linear = [](qreal c) { return c <= 0.04045 ? c / 12.92 : std::pow((c + 0.055) / 1.055, 2.4); };
    return 0.2126 * linear(color.redF()) + 0.7152 * linear(color.greenF()) + 0.0722 * linear(color.blueF());
}

Q_LOGGING_CATEGORY(paletteLog, "interactive.palette", QtWarningMsg)
namespace mcu = material_color_utilities;

bool explicitColor(const QSet<QString> &supplied, const QString &role)
{
    return supplied.contains(QStringLiteral("colors.") + role);
}

QString actionFor(const QString &role)
{
    return role == QLatin1String("accent") ? QStringLiteral("primary")
        : role == QLatin1String("error") ? QStringLiteral("destructive")
        : role == QLatin1String("warning") ? QStringLiteral("caution") : QString();
}

struct SemanticGroup {
    QString identity;
    QVariantMap colors;
    QSet<QString> dependent;
};

// One finalization path for both candidates and caller-owned semantic seeds.
// Dependency flags distinguish immutable pairs from pairs a candidate can repair.
SemanticGroup finalizeGroup(const QVariantMap &input, const QSet<QString> &supplied,
                            const QVariantMap &motion, const QString &role, const QColor &seed,
                            bool candidate, const QColor &canvas, const QColor &content,
                            qreal floor, qreal labelTarget)
{
    const TraceAggregate aggregated(TraceScope::AggFinalizeGroup, 0);
    SemanticGroup group{role, {}, {}};
    const auto color = [&](const QString &name) {
        return group.colors.contains(name) ? group.colors.value(name).value<QColor>() : input.value(name).value<QColor>();
    };
    const auto set = [&](const QString &name, const QColor &value, bool dependent) {
        group.colors.insert(name, explicitColor(supplied, name) ? input.value(name) : QVariant(value));
        if (dependent && !explicitColor(supplied, name))
            group.dependent.insert(name);
    };
    set(role, seed, candidate);
    const QString action = actionFor(role);
    if (!action.isEmpty()) {
        QString foreground = role;
        foreground[0] = foreground[0].toUpper();
        foreground.prepend(QStringLiteral("on"));
        const bool explicitText = explicitColor(supplied, foreground);
        QColor restingText = explicitText ? color(foreground)
            : TokenSchema::contrastingText(color(role), {color(role)}, content, labelTarget);
        // The primary accent is exact even when absent/equal-to-default. Only
        // library-owned semantic companions may have their resting fill adjusted.
        if (candidate && color(role).alphaF() == 1 && restingText.alphaF() == 1
            && TokenSchema::contrastRatio(restingText, color(role)) < floor) {
            set(role, TokenSchema::contrastingText(color(role), {restingText}, content, floor + 0.1), true);
            if (!explicitText)
                restingText = TokenSchema::contrastingText(color(role), {color(role)}, content, labelTarget);
        }
        for (const auto *state : {"Hover", "Pressed"}) {
            const QString strength = QLatin1String(state) == QLatin1String("Hover")
                ? QStringLiteral("hoverBlend") : QStringLiteral("pressedBlend");
            set(role + QLatin1String(state), TokenSchema::feedbackSurface(color(role), restingText,
                motion.value(strength).toDouble()), candidate);
        }
        if (explicitText)
            set(foreground, color(foreground), false);
        else
            set(foreground, TokenSchema::contrastingText(color(role),
                {color(role), color(role + QStringLiteral("Hover")), color(role + QStringLiteral("Pressed"))}, content, labelTarget), candidate);
        set(action + QStringLiteral("Surface"), color(role), group.dependent.contains(role));
        for (const auto *state : {"Hover", "Pressed"}) {
            const QString semanticState = role + QLatin1String(state);
            set(action + QLatin1String(state), color(semanticState), group.dependent.contains(semanticState));
        }
        const QString actionText = action + QStringLiteral("Text");
        if (explicitColor(supplied, actionText)) {
            set(actionText, color(actionText), false);
        } else if (!explicitText && color(action + QStringLiteral("Surface")) == color(role)
            && color(action + QStringLiteral("Hover")) == color(role + QStringLiteral("Hover"))
            && color(action + QStringLiteral("Pressed")) == color(role + QStringLiteral("Pressed"))) {
            // Aliases with identical effective states have the same derivation.
            // Reuse this call's result, including its full precision; no cache.
            set(actionText, color(foreground), candidate);
        } else {
            set(actionText, TokenSchema::contrastingText(color(role),
                {color(action + QStringLiteral("Surface")), color(action + QStringLiteral("Hover")),
                 color(action + QStringLiteral("Pressed"))}, content, labelTarget), candidate);
        }
        set(action + QStringLiteral("Outline"), color(action + QStringLiteral("Text")),
            group.dependent.contains(action + QStringLiteral("Text")));
    }
    if (role != QLatin1String("accent")) {
        set(role + QStringLiteral("Surface"), TokenSchema::blend(color(QStringLiteral("content")), color(role),
            motion.value(QStringLiteral("semanticBlend")).toDouble()), candidate);
        const QString messageText = role + QStringLiteral("Text");
        if (explicitColor(supplied, messageText))
            set(messageText, color(messageText), false);
        else
            set(messageText, TokenSchema::contrastingText(color(role),
                {color(QStringLiteral("content")), color(role + QStringLiteral("Surface"))}, canvas, labelTarget), candidate);
    }
    return group;
}

struct PaletteFill {
    QString identity;
    QString role;
    QColor visible;
    mcu::Cam cam;
    bool dependent;
    bool resting;
    bool interactive;
};

PaletteFill paletteFill(const QString &identity, const QString &role, const QColor &color,
                        const QColor &content, bool dependent, bool resting, bool interactive)
{
    const QColor visible = QColor::fromRgb(TokenSchema::composite(color, content).rgb());
    return {identity, role, visible, mcu::CamFromInt(visible.rgb()), dependent, resting, interactive};
}

QList<PaletteFill> groupFills(const SemanticGroup &group, const QSet<QString> &supplied, const QColor &content)
{
    QList<PaletteFill> fills;
    const auto append = [&](const QString &role, bool resting, bool interactive) {
        fills.append(paletteFill(group.identity, role, group.colors.value(role).value<QColor>(), content,
            group.dependent.contains(role), resting, interactive));
    };
    append(group.identity, true, false);
    const QString action = actionFor(group.identity);
    if (!action.isEmpty()) {
        append(action + QStringLiteral("Surface"), true, true);
        for (const auto *state : {"Hover", "Pressed"}) {
            append(action + QLatin1String(state), false, true);
            const QString semantic = group.identity + QLatin1String(state);
            if (explicitColor(supplied, semantic))
                append(semantic, false, true);
        }
    }
    return fills;
}

qreal fillDistance(const PaletteFill &a, const PaletteFill &b)
{
    return std::sqrt(std::pow(a.cam.jstar - b.cam.jstar, 2)
        + std::pow(a.cam.astar - b.cam.astar, 2) + std::pow(a.cam.bstar - b.cam.bstar, 2));
}

qreal separationTarget(const PaletteFill &a, const PaletteFill &b)
{
    if (a.identity == b.identity)
        return 0;
    if (a.resting && b.resting)
        return 12;
    return a.interactive && b.interactive ? 8 : 0;
}

struct CandidateChecks {
    bool separated = true;
    bool readable = true;
    bool readableFull = true;
    bool readableRgb8 = true;
    bool family = true;
    qreal minimumDistance = std::numeric_limits<qreal>::infinity();
    // Composited RGB8 tones of the reserved fills blocking a dependent fill:
    // nonzero separation target with final measured distance below it.
    QList<qreal> blockers;
};

bool chromaticFamily(const QColor &color, qreal anchor)
{
    const mcu::Hct actual(color.rgb());
    return actual.get_chroma() >= 8 && mcu::DiffDegrees(actual.get_hue(), anchor) <= 22;
}

CandidateChecks checkCandidate(const SemanticGroup &group, const QSet<QString> &supplied,
                              const QList<PaletteFill> &reserved, const QColor &canvas,
                              const QColor &content, qreal target, qreal anchor, bool neutral)
{
    const TraceAggregate aggregated(TraceScope::AggCheckCandidate, 0);
    CandidateChecks checks;
    const auto fills = groupFills(group, supplied, content);
    for (const auto &fill : fills) {
        if (fill.dependent) {
            checks.family &= neutral ? (fill.visible.red() == fill.visible.green() && fill.visible.green() == fill.visible.blue())
                : chromaticFamily(fill.visible, anchor);
        }
        for (const auto &fixed : reserved) {
            const qreal required = separationTarget(fill, fixed);
            // A fixed action surface can mask the candidate completely. Its
            // fixed collision is diagnosed once and never steers repair proposals.
            if (!fill.dependent || required == 0)
                continue;
            const qreal distance = fillDistance(fill, fixed);
            checks.minimumDistance = std::min(checks.minimumDistance, distance);
            if (distance < required) {
                checks.separated = false;
                // Repair proposals read the reserved fill's composited RGB8 tone.
                checks.blockers.append(mcu::LstarFromArgb(fixed.visible.rgb()));
            }
        }
    }
    const auto color = [&](const QString &name) { return group.colors.value(name).value<QColor>(); };
    const auto pair = [&](const QString &foreground, const QString &background, const QColor &surface) {
        if (!group.dependent.contains(foreground) && !group.dependent.contains(background))
            return;
        const QColor backdrop = background == QStringLiteral("content") || background == group.identity + QStringLiteral("Surface")
            ? canvas : content;
        const QColor visible = TokenSchema::composite(surface, TokenSchema::composite(backdrop, QColor(Qt::white)));
        const qreal full = TokenSchema::contrastRatio(color(foreground), visible);
        const qreal rgb8 = TokenSchema::contrastRatio(QColor::fromRgba(color(foreground).rgba()), QColor::fromRgb(visible.rgb()));
        checks.readableFull &= full >= target;
        checks.readableRgb8 &= rgb8 >= target;
        checks.readable &= checks.readableFull && checks.readableRgb8;
    };
    if (group.identity != QLatin1String("accent")) {
        pair(group.identity + QStringLiteral("Text"), QStringLiteral("content"), content);
        pair(group.identity + QStringLiteral("Text"), group.identity + QStringLiteral("Surface"), color(group.identity + QStringLiteral("Surface")));
    }
    const QString action = actionFor(group.identity);
    if (!action.isEmpty()) {
        QString foreground = group.identity;
        foreground[0] = foreground[0].toUpper();
        foreground.prepend(QStringLiteral("on"));
        for (const auto &state : {QString(), QStringLiteral("Hover"), QStringLiteral("Pressed")})
            pair(foreground, group.identity + state, color(group.identity + state));
        for (const auto *state : {"Surface", "Hover", "Pressed"})
            pair(action + QStringLiteral("Text"), action + QLatin1String(state), color(action + QLatin1String(state)));
    }
    return checks;
}

// Bounded direct recipe: one direct base proposal per branch at the analyzed
// accent tone, then at most two tone repairs derived from the direct proposal's
// frozen separation blockers. No hue rotation, no tone×chroma grid. Branch
// proposals are counted per role for the trial's three/six bound evidence.
SemanticGroup selectGroup(const QVariantMap &colors, const QSet<QString> &supplied, const QVariantMap &motion,
                          const QString &role, const mcu::Hct &seed, qreal chroma, qreal anchor,
                          const QList<PaletteFill> &reserved, const QColor &canvas, const QColor &content,
                          qreal floor, qreal labelTarget, QVariantList *diagnostics)
{
    const TraceSpan span(TraceScope::SelectGroup, nullptr);
    QElapsedTimer timer;
    timer.start();
    // A red-family primary occupies the danger family: danger stays true gray.
    const bool neutralDanger = role == QLatin1String("error") && chroma >= 12
        && mcu::DiffDegrees(seed.get_hue(), anchor) <= 20;
    const qreal seedTone = seed.get_tone();
    // The chroma floor retains semantic identity for gray/weakly chromatic
    // seeds; it is not a claim of exact chroma matching.
    const qreal requestChroma = std::max(chroma, qreal(12));
    const quint16 roleTag = role == QLatin1String("error") ? 1 : role == QLatin1String("warning") ? 2 : 3;

    struct Attempt {
        SemanticGroup group;
        CandidateChecks checks;
        qreal toneDistance = 0;     // final base-tone distance from the seed tone
        qreal actualChroma = 0;
        QRgb rgb = 0;               // final composited base RGB8
        bool valid = false;         // every acceptance gate passed
    };
    QList<Attempt> tried;
    SemanticGroup chosen;
    int proposals[2] = {0, 0};      // [chromatic, neutral]

    const auto requestColor = [&](bool neutral, qreal tone) {
        // Every request starts from the original H/C values, never from an
        // already gamut-mapped object whose chroma an earlier attempt reduced.
        return neutral ? QColor::fromRgb(mcu::IntFromLstar(tone))
                       : QColor::fromRgb(mcu::Hct(anchor, requestChroma, tone).ToInt());
    };
    const auto propose = [&](bool neutral, const QColor &base) {
        Attempt attempt;
        {
            const TraceAggregate proposal(TraceScope::AggPaletteProposal,
                                          quint16(roleTag * 2 + (neutral ? 1 : 0)));
            attempt.group = finalizeGroup(colors, supplied, motion, role, base, true, canvas, content, floor, labelTarget);
            attempt.checks = checkCandidate(attempt.group, supplied, reserved, canvas, content, floor, anchor, neutral);
        }
        ++proposals[neutral ? 1 : 0];
        const QColor finalBase = QColor::fromRgb(TokenSchema::composite(
            attempt.group.colors.value(role).value<QColor>(), content).rgb());
        attempt.rgb = finalBase.rgb();
        attempt.toneDistance = std::abs(mcu::LstarFromArgb(attempt.rgb) - seedTone);
        attempt.actualChroma = mcu::Hct(attempt.rgb).get_chroma();
        attempt.valid = attempt.checks.family && attempt.checks.readable && attempt.checks.separated;
        tried.append(attempt);
    };
    // Closest final base tone to the seed tone; exact ties break to larger
    // actual base chroma, then lower RGB integer.
    const auto closer = [](const Attempt &a, const Attempt &b) {
        if (a.toneDistance != b.toneDistance)
            return a.toneDistance < b.toneDistance;
        if (a.actualChroma != b.actualChroma)
            return a.actualChroma > b.actualChroma;
        return a.rgb < b.rgb;
    };
    const auto branch = [&](bool neutral) {
        const QColor directRequest = requestColor(neutral, seedTone);
        propose(neutral, directRequest);
        const Attempt direct = tried.constLast();
        if (direct.valid) {
            chosen = direct.group;
            return true;
        }
        // Tone repairs read the direct proposal's frozen blocker range; with no
        // separation blockers they step a fixed 16 tones from the seed tone.
        qreal lower = seedTone - 16, upper = seedTone + 16;
        if (!direct.checks.blockers.isEmpty()) {
            const auto range = std::minmax_element(direct.checks.blockers.cbegin(), direct.checks.blockers.cend());
            lower = *range.first - 16;
            upper = *range.second + 16;
        }
        lower = std::clamp(lower, qreal(0), qreal(100));
        upper = std::clamp(upper, qreal(0), qreal(100));
        QSet<qreal> requestTones{seedTone};
        QSet<QRgb> generated{directRequest.rgb()};
        QList<int> feasible;
        for (const qreal tone : {lower, upper}) {
            // Duplicated request tones or generated RGB values buy no attempts.
            if (requestTones.contains(tone))
                continue;
            requestTones.insert(tone);
            const QColor request = requestColor(neutral, tone);
            if (generated.contains(request.rgb()))
                continue;
            generated.insert(request.rgb());
            propose(neutral, request);
            if (tried.constLast().valid)
                feasible.append(tried.size() - 1);
        }
        if (feasible.isEmpty())
            return false;
        int best = feasible.constFirst();
        for (const int index : feasible)
            if (closer(tried.at(index), tried.at(best)))
                best = index;
        chosen = tried.at(best).group;
        return true;
    };

    bool accepted = branch(neutralDanger);
    if (!accepted && !neutralDanger)
        accepted = branch(true);
    if (accepted) {
        qCDebug(paletteLog).nospace() << "role=" << role << " chromaticProposals=" << proposals[0]
            << " neutralProposals=" << proposals[1] << " tried=" << tried.size()
            << " exhausted=false elapsedNs=" << timer.nsecsElapsed();
        return chosen;
    }

    // Exhaustion is not rejection: retain a deterministic best-effort attempt
    // (family-valid first, then maximum minimum separation, then the declared
    // final-tone/chroma/RGB tie-break) and report the bounded failure honestly.
    Q_ASSERT(!tried.isEmpty());
    int best = 0;
    for (int i = 1; i < tried.size(); ++i) {
        const Attempt &a = tried.at(i), &b = tried.at(best);
        if (a.checks.family != b.checks.family) {
            if (a.checks.family)
                best = i;
        } else if (a.checks.minimumDistance != b.checks.minimumDistance) {
            if (a.checks.minimumDistance > b.checks.minimumDistance)
                best = i;
        } else if (closer(a, b)) {
            best = i;
        }
    }
    chosen = tried.at(best).group;
    QStringList failedGates;
    if (!tried.at(best).checks.family)
        failedGates.append(QStringLiteral("family"));
    if (!tried.at(best).checks.separated)
        failedGates.append(QStringLiteral("separated"));
    if (!tried.at(best).checks.readableFull)
        failedGates.append(QStringLiteral("readable-full"));
    if (!tried.at(best).checks.readableRgb8)
        failedGates.append(QStringLiteral("readable-rgb8"));
    const int maximum = neutralDanger ? 3 : 6;
    auto entry = TokenSchema::diagnostic(QStringLiteral("tokens.colors.") + role,
        QStringLiteral("palette-generation-exhausted"),
        QStringLiteral("Bounded palette generation tried %1 of at most %2 base proposals for %3 without "
                       "passing every gate; retained a deterministic best-effort candidate failing: %4. "
                       "These bounded proposals failed; this is not proof that no feasible palette exists.")
            .arg(tried.size()).arg(maximum).arg(role, failedGates.join(QStringLiteral(", "))));
    entry.insert(QStringLiteral("role"), role);
    entry.insert(QStringLiteral("tried"), tried.size());
    entry.insert(QStringLiteral("maximum"), maximum);
    entry.insert(QStringLiteral("failedGates"), failedGates);
    diagnostics->append(entry);
    qCDebug(paletteLog).nospace() << "role=" << role << " chromaticProposals=" << proposals[0]
        << " neutralProposals=" << proposals[1] << " tried=" << tried.size()
        << " exhausted=true elapsedNs=" << timer.nsecsElapsed();
    return chosen;
}

void diagnoseCollisions(const QList<PaletteFill> &fills, QVariantList *diagnostics)
{
    QSet<QString> seen;
    for (qsizetype i = 0; i < fills.size(); ++i) {
        for (qsizetype j = i + 1; j < fills.size(); ++j) {
            const auto &a = fills[i], &b = fills[j];
            const qreal target = separationTarget(a, b);
            if (target == 0)
                continue;
            const qreal distance = fillDistance(a, b);
            if (distance >= target)
                continue;
            const QString key = a.identity + QLatin1Char('/') + b.identity + QLatin1Char('/')
                + QString::number(a.visible.rgb()) + QLatin1Char('/') + QString::number(b.visible.rgb());
            if (seen.contains(key))
                continue;
            seen.insert(key);
            const QString first = QStringLiteral("tokens.colors.") + a.role;
            const QString second = QStringLiteral("tokens.colors.") + b.role;
            auto entry = TokenSchema::diagnostic(first + QLatin1Char('/') + b.role, QStringLiteral("palette-collision"),
                QStringLiteral("Palette distinction distance %1 between %2 and %3 is below the %4 target; explicit colors are retained. This is a palette design measurement, not text contrast.")
                    .arg(distance, 0, 'f', 3).arg(first, second).arg(target));
            entry.insert(QStringLiteral("paths"), QStringList{first, second});
            entry.insert(QStringLiteral("distance"), distance);
            entry.insert(QStringLiteral("target"), target);
            diagnostics->append(entry);
        }
    }
}

} // namespace

QVariantMap TokenSchema::definitions()
{
    static const QVariantMap schema = [] {
        QVariantMap colors, metrics, typography, motion, icons;
#define IA_SCHEMA_COLOR(name, light, dark) colors.insert(QStringLiteral(#name), definition(QStringLiteral("color")));
        IA_COLOR_TOKENS(IA_SCHEMA_COLOR)
#undef IA_SCHEMA_COLOR
#define IA_SCHEMA_METRIC(name, value, min, max) metrics.insert(QStringLiteral(#name), definition(QStringLiteral("real"), min, max));
        IA_METRIC_TOKENS(IA_SCHEMA_METRIC)
#undef IA_SCHEMA_METRIC
        typography.insert(QStringLiteral("family"), definition(QStringLiteral("family")));
#define IA_SCHEMA_SIZE(name, value, min, max) typography.insert(QStringLiteral(#name), definition(QStringLiteral("real"), min, max));
        IA_TYPE_SIZE_TOKENS(IA_SCHEMA_SIZE)
#undef IA_SCHEMA_SIZE
#define IA_SCHEMA_WEIGHT(name, value, min, max) typography.insert(QStringLiteral(#name), definition(QStringLiteral("integer"), min, max));
        IA_TYPE_WEIGHT_TOKENS(IA_SCHEMA_WEIGHT)
#undef IA_SCHEMA_WEIGHT
#define IA_SCHEMA_MOTION_INT(name, value, min, max) motion.insert(QStringLiteral(#name), definition(QStringLiteral("integer"), min, max));
        IA_MOTION_INT_TOKENS(IA_SCHEMA_MOTION_INT)
#undef IA_SCHEMA_MOTION_INT
#define IA_SCHEMA_MOTION_REAL(name, value, min, max) motion.insert(QStringLiteral(#name), definition(QStringLiteral("real"), min, max));
        IA_MOTION_REAL_TOKENS(IA_SCHEMA_MOTION_REAL)
#undef IA_SCHEMA_MOTION_REAL
        icons.insert(QStringLiteral("strokeWidth"), definition(QStringLiteral("real"), 0.25, 16));
#define IA_SCHEMA_URL(name, file) icons.insert(QStringLiteral(#name), definition(QStringLiteral("url")));
        IA_ICON_URL_TOKENS(IA_SCHEMA_URL)
#undef IA_SCHEMA_URL
        return QVariantMap{{QStringLiteral("colors"), colors}, {QStringLiteral("metrics"), metrics},
                           {QStringLiteral("typography"), typography}, {QStringLiteral("motion"), motion},
                           {QStringLiteral("icons"), icons}};
    }();
    return schema;
}

QVariantMap TokenSchema::diagnostic(const QString &path, const QString &code,
                                  const QString &message, const QString &severity)
{
    return {{QStringLiteral("path"), path}, {QStringLiteral("code"), code},
            {QStringLiteral("message"), message}, {QStringLiteral("severity"), severity}};
}

bool TokenSchema::validate(const QString &group, const QString &name, const QVariant &value,
                           QVariant *normalized, QVariantList *diagnostics, const QString &path, bool resolvedValue)
{
    const QString location = path.isEmpty() ? QStringLiteral("tokens.") + group + QLatin1Char('.') + name : path;
    const auto entry = definitions().value(group).toMap().value(name).toMap();
    const auto invalid = [&](const QString &code, const QString &message) {
        if (diagnostics)
            diagnostics->append(diagnostic(location, code, message));
        return false;
    };
    if (entry.isEmpty())
        return invalid(QStringLiteral("unknown-field"), QStringLiteral("Unknown token; ignored."));
    const QString type = entry.value(QStringLiteral("type")).toString();
    QVariant result;
    if (type == QLatin1String("color")) {
        QColor color;
        if (value.metaType().id() == QMetaType::QColor)
            color = value.value<QColor>();
        else if (value.metaType().id() == QMetaType::QString)
            color = QColor(value.toString());
        if (!color.isValid())
            return invalid(QStringLiteral("invalid-value"), QStringLiteral("Expected a valid QColor or color string."));
        if (!std::isfinite(color.redF()) || !std::isfinite(color.greenF())
            || !std::isfinite(color.blueF()) || !std::isfinite(color.alphaF())
            || color.redF() < 0 || color.redF() > 1 || color.greenF() < 0 || color.greenF() > 1
            || color.blueF() < 0 || color.blueF() > 1 || color.alphaF() < 0 || color.alphaF() > 1)
            return invalid(QStringLiteral("invalid-value"), QStringLiteral("Color channels must be finite and within [0, 1]."));
        result = color.toRgb();
    } else if (type == QLatin1String("real") || type == QLatin1String("integer")) {
        const bool integer = type == QLatin1String("integer");
        double low = entry.value(QStringLiteral("minimum")).toDouble();
        double high = entry.value(QStringLiteral("maximum")).toDouble();
        // Local values are already scaled. Their accepted range must include
        // every effective default, including a same-as-default assignment.
        if (resolvedValue && group == QLatin1String("typography") && name == QLatin1String("controlSize")) {
            low *= 0.5;
            high *= 3;
        }
        if (resolvedValue && group == QLatin1String("metrics") && name == QLatin1String("controlHeight"))
            high = 4096;
        if (!numberInRange(value, low, high, integer))
            return invalid(QStringLiteral("invalid-value"),
                           QStringLiteral("Expected a finite %1 in [%2, %3]; strings and booleans are not numbers.")
                               .arg(type).arg(low).arg(high));
        result = integer ? QVariant(value.toInt()) : QVariant(value.toDouble());
    } else if (type == QLatin1String("family")) {
        if (value.metaType().id() != QMetaType::QString || value.toString().trimmed().isEmpty()
            || value.toString().size() > 256 || value.toString().contains(QChar::Null))
            return invalid(QStringLiteral("invalid-value"), QStringLiteral("Expected a nonempty font family (at most 256 characters)."));
        result = value.toString().trimmed();
    } else if (type == QLatin1String("url")) {
        if (value.metaType().id() != QMetaType::QString && value.metaType().id() != QMetaType::QUrl)
            return invalid(QStringLiteral("invalid-value"), QStringLiteral("Expected an absolute asset URL."));
        const QUrl url = value.metaType().id() == QMetaType::QUrl ? value.toUrl() : QUrl(value.toString(), QUrl::StrictMode);
        if (!url.isValid() || url.isEmpty() || url.isRelative()
            || !QStringList{QStringLiteral("qrc"), QStringLiteral("file"), QStringLiteral("https"),
                            QStringLiteral("http"), QStringLiteral("data")}.contains(url.scheme()))
            return invalid(QStringLiteral("invalid-value"), QStringLiteral("Asset URL must use qrc, file, https, http, or data."));
        result = url;
    }
    if (normalized)
        *normalized = result;
    return true;
}

QColor TokenSchema::blend(const QColor &base, const QColor &toward, qreal amount)
{
    amount = std::clamp(amount, qreal(0), qreal(1));
    const auto mix = [amount](qreal a, qreal b) { return a + (b - a) * amount; };
    return QColor::fromRgbF(mix(base.redF(), toward.redF()), mix(base.greenF(), toward.greenF()),
                           mix(base.blueF(), toward.blueF()), mix(base.alphaF(), toward.alphaF()));
}

QColor TokenSchema::feedbackSurface(const QColor &background, const QColor &foreground, qreal amount)
{
    const QColor black(Qt::black), white(Qt::white);
    const QColor toward = contrastRatio(foreground, white) >= contrastRatio(foreground, black) ? white : black;
    return blend(background, toward, amount);
}

QColor TokenSchema::composite(const QColor &foreground, const QColor &background)
{
    const qreal alpha = foreground.alphaF() + background.alphaF() * (1 - foreground.alphaF());
    if (alpha == 0)
        return QColor(Qt::transparent);
    const auto over = [&](qreal f, qreal b) {
        return (f * foreground.alphaF() + b * background.alphaF() * (1 - foreground.alphaF())) / alpha;
    };
    return QColor::fromRgbF(over(foreground.redF(), background.redF()),
                           over(foreground.greenF(), background.greenF()),
                           over(foreground.blueF(), background.blueF()), alpha);
}

qreal TokenSchema::contrastRatio(const QColor &foreground, const QColor &background)
{
    // Callers flatten their actual surface first. White is the documented
    // final reference only when an application makes even its canvas translucent.
    const QColor surface = composite(background, QColor(Qt::white));
    const qreal a = luminance(composite(foreground, surface));
    const qreal b = luminance(surface);
    return (std::max(a, b) + 0.05) / (std::min(a, b) + 0.05);
}

QColor TokenSchema::contrastingText(const QColor &seed, const QList<QColor> &backgrounds,
                                   const QColor &canvas, qreal target)
{
    const TraceAggregate aggregated(TraceScope::AggContrastingText, 0);
    if (!seed.isValid() || backgrounds.isEmpty() || !std::isfinite(target) || target < 1 || target > 21)
        return {};
    const QColor backdrop = composite(canvas, QColor(Qt::white));
    const QColor opaqueSeed = QColor::fromRgb(composite(seed, backdrop).rgb());
    const mcu::Hct hct(opaqueSeed.rgb());
    // CAM16 assigns small chroma to even RGB gray. It is not intended hue.
    const qreal chroma = seed.red() == seed.green() && seed.green() == seed.blue() ? 0 : hct.get_chroma();
    // Prepare each actual background once and retain full-precision and RGB8
    // luminances; candidate measurement reuses them within this call.
    QList<qreal> surfaceLuminances;
    QList<qreal> luminances;
    for (const QColor &background : backgrounds) {
        if (!background.isValid())
            return {};
        const QColor surface = composite(background, backdrop);
        const qreal surfaceLuminance = luminance(surface);
        surfaceLuminances.append(surfaceLuminance);
        surfaceLuminances.append(luminance(QColor::fromRgb(surface.rgb())));
        luminances.append(surfaceLuminance * 100);
    }
    const auto minimumContrast = [&](const QColor &foreground) {
        qreal minimum = 21;
        // Every generated foreground and the flattened seed is opaque. Surface
        // luminance is invariant across the candidate tones in this invocation.
        const qreal foregroundLuminance = luminance(foreground);
        for (const qreal backgroundLuminance : surfaceLuminances) {
            minimum = std::min(minimum, (std::max(foregroundLuminance, backgroundLuminance) + 0.05)
                / (std::min(foregroundLuminance, backgroundLuminance) + 0.05));
        }
        return minimum;
    };
    const auto fastReturn = [](const QColor &result) {
        const TraceAggregate fast(TraceScope::AggForegroundFast, 0);
        return result;
    };
    if (minimumContrast(opaqueSeed) >= target
        && (chroma != 0 || (opaqueSeed.red() == opaqueSeed.green() && opaqueSeed.green() == opaqueSeed.blue())))
        return fastReturn(opaqueSeed);

    // Cheap direct proposals before constructing interval-probe arrays. MCU's
    // algebraic exterior solutions use extrema across the full-precision and
    // RGB8 background representations; literal endpoints cover the cases where
    // MCU's safety margin returns -1 although the endpoint meets the target.
    qreal minimumTone = std::numeric_limits<qreal>::infinity();
    qreal maximumTone = -std::numeric_limits<qreal>::infinity();
    for (const qreal surfaceLuminance : surfaceLuminances) {
        const qreal tone = mcu::LstarFromY(surfaceLuminance * 100);
        minimumTone = std::min(minimumTone, tone);
        maximumTone = std::max(maximumTone, tone);
    }
    QList<QColor> fastProposals;
    if (const qreal tone = mcu::Darker(minimumTone, target); tone >= 0)
        fastProposals.append(QColor::fromRgb(mcu::Hct(hct.get_hue(), chroma, tone).ToInt()));
    if (const qreal tone = mcu::Lighter(maximumTone, target); tone >= 0)
        fastProposals.append(QColor::fromRgb(mcu::Hct(hct.get_hue(), chroma, tone).ToInt()));
    fastProposals.append(QColor(Qt::black));
    fastProposals.append(QColor(Qt::white));
    QColor bestFast;
    qreal bestFastDistance = std::numeric_limits<qreal>::infinity();
    bool fastReadable = false;
    for (const QColor &candidate : fastProposals) {
        // Judge the actual quantized color; a requested tone is not the output.
        if (minimumContrast(candidate) < target)
            continue;
        const qreal distance = std::abs(mcu::LstarFromArgb(candidate.rgb()) - hct.get_tone());
        if (!fastReadable || distance < bestFastDistance
            || (distance == bestFastDistance && candidate.rgb() < bestFast.rgb())) {
            bestFast = candidate;
            bestFastDistance = distance;
            fastReadable = true;
        }
    }
    if (fastReadable)
        return fastReturn(bestFast);

    // General fallback for mixed dark/light backgrounds, narrow feasible bands,
    // gamut/quantization edges and impossible targets. Its interval intersection,
    // interior probes and balanced-gap candidates are preserved unchanged.
    const TraceAggregate fallbackScope(TraceScope::AggForegroundFallback, 0);
    QList<qreal> tones{0, 100, hct.get_tone()};
    QList<QPair<qreal, qreal>> intervals{{0, 100}};
    for (const qreal y : luminances) {
        const qreal tone = mcu::LstarFromY(y);
        for (const qreal candidate : {mcu::Darker(tone, target), mcu::Lighter(tone, target)}) {
            if (candidate >= 0)
                tones.append(candidate);
        }
        // Each surface permits a darker OR lighter luminance interval. Keep
        // the intersection, including middle-tone solutions between surfaces.
        const qreal dark = (y + 5) / target - 5;
        const qreal light = target * (y + 5) - 5;
        QList<QPair<qreal, qreal>> remaining;
        for (const auto &[low, high] : intervals) {
            if (low <= std::min(high, dark))
                remaining.append({low, std::min(high, dark)});
            if (std::max(low, light) <= high)
                remaining.append({std::max(low, light), high});
        }
        intervals = std::move(remaining);
    }
    for (const auto &[low, high] : intervals) {
        const qreal lowTone = mcu::LstarFromY(low), highTone = mcu::LstarFromY(high);
        tones.append(std::clamp(hct.get_tone(), lowTone, highTone));
        // Narrow intervals may be smaller than the upstream 0.4-tone safety
        // margin. Probe their interior, then judge the quantized RGB result.
        for (int step = 0; step <= 16; ++step)
            tones.append(lowTone + (highTone - lowTone) * step / 16);
    }
    std::sort(luminances.begin(), luminances.end());
    for (qsizetype i = 1; i < luminances.size(); ++i) {
        // If the requested ratio is impossible, the maximin candidate in each
        // gap balances contrast with its two nearest bounding surfaces.
        tones.append(mcu::LstarFromY(std::sqrt((luminances[i - 1] + 5) * (luminances[i] + 5)) - 5));
    }
    QColor best = chroma == 0 ? QColor::fromRgb(mcu::Hct(hct.get_hue(), 0, hct.get_tone()).ToInt()) : opaqueSeed;
    qreal bestRatio = minimumContrast(best);
    qreal bestDistance = std::numeric_limits<qreal>::infinity();
    bool readable = false;
    for (const qreal tone : tones) {
        const QColor candidate = QColor::fromRgb(mcu::Hct(hct.get_hue(), chroma, tone).ToInt());
        const qreal ratio = minimumContrast(candidate);
        const qreal distance = std::abs(mcu::LstarFromArgb(candidate.rgb()) - hct.get_tone());
        if (ratio >= target ? (!readable || distance < bestDistance) : (!readable && ratio > bestRatio)) {
            best = candidate;
            bestRatio = ratio;
            bestDistance = distance;
            readable = ratio >= target;
        }
    }
    return best;
}

void TokenSchema::checkContrast(QVariantList *diagnostics, const QString &path,
                                const QColor &foreground, const QColor &background, qreal target)
{
    const qreal actual = contrastRatio(foreground, background);
    if (actual + 0.001 >= target)
        return;
    auto entry = diagnostic(path, QStringLiteral("low-contrast"),
                            QStringLiteral("Foreground contrast %1:1 is below the %2:1 target; supplied colors are retained and derived text is best-effort.")
                                .arg(actual, 0, 'f', 2).arg(target));
    entry.insert(QStringLiteral("ratio"), actual);
    entry.insert(QStringLiteral("target"), target);
    diagnostics->append(entry);
}

ResolvedAppearance TokenSchema::resolve(const QVariantMap &input, const QString &fontFamily)
{
    auto result = prepare(input, fontFamily);
    if (!result.accepted)
        return result;
    result = calculatePalette(std::move(result));
    resolveNoncolors(&result);
    return result;
}

ResolvedAppearance TokenSchema::prepare(const QVariantMap &input, const QString &fontFamily)
{
    ResolvedAppearance result;
    const auto reject = [&](const QString &path, const QString &message) {
        result.accepted = false;
        result.diagnostics.append(diagnostic(path, QStringLiteral("rejected-input"), message, QStringLiteral("error")));
    };
    if (input.contains(QStringLiteral("schemaVersion"))
        && !numberInRange(input.value(QStringLiteral("schemaVersion")), 1, 1, true)) {
        reject(QStringLiteral("schemaVersion"), QStringLiteral("Only numeric schemaVersion 1 is supported; previous snapshot retained."));
        return result;
    }
    const QVariant tokenInput = input.value(QStringLiteral("tokens"));
    if (input.contains(QStringLiteral("tokens")) && tokenInput.metaType().id() != QMetaType::QVariantMap) {
        reject(QStringLiteral("tokens"), QStringLiteral("tokens must be an object; previous snapshot retained."));
        return result;
    }
    const auto schema = definitions();
    const auto suppliedGroups = tokenInput.toMap();
    for (auto it = suppliedGroups.cbegin(); it != suppliedGroups.cend(); ++it) {
        if (schema.contains(it.key()) && it.value().metaType().id() != QMetaType::QVariantMap) {
            reject(QStringLiteral("tokens.") + it.key(), QStringLiteral("A token group must be an object; previous snapshot retained."));
        }
    }
    if (!result.accepted)
        return result;

    const QSet<QString> envelope{QStringLiteral("schemaVersion"), QStringLiteral("scheme"), QStringLiteral("density"),
                                QStringLiteral("fontScale"), QStringLiteral("contrast"), QStringLiteral("reducedMotion"),
                                QStringLiteral("tokens")};
    for (auto it = input.cbegin(); it != input.cend(); ++it) {
        if (!envelope.contains(it.key()))
            result.diagnostics.append(diagnostic(it.key(), QStringLiteral("unknown-field"), QStringLiteral("Unknown input field; ignored.")));
    }
    const auto readEnum = [&](const QString &key, const QStringList &allowed, QString *destination) {
        if (!input.contains(key))
            return;
        const auto value = input.value(key);
        if (value.metaType().id() == QMetaType::QString && allowed.contains(value.toString()))
            *destination = value.toString();
        else
            result.diagnostics.append(diagnostic(key, QStringLiteral("invalid-value"), QStringLiteral("Expected one of: ") + allowed.join(QStringLiteral(", "))));
    };
    readEnum(QStringLiteral("scheme"), {QStringLiteral("light"), QStringLiteral("dark")}, &result.scheme);
    readEnum(QStringLiteral("density"), {QStringLiteral("compact"), QStringLiteral("touch")}, &result.density);
    readEnum(QStringLiteral("contrast"), {QStringLiteral("normal"), QStringLiteral("high")}, &result.contrast);
    if (input.contains(QStringLiteral("fontScale"))) {
        if (numberInRange(input.value(QStringLiteral("fontScale")), 0.5, 3))
            result.fontScale = input.value(QStringLiteral("fontScale")).toDouble();
        else
            result.diagnostics.append(diagnostic(QStringLiteral("fontScale"), QStringLiteral("invalid-value"), QStringLiteral("Expected a finite number in [0.5, 3].")));
    }
    if (input.contains(QStringLiteral("reducedMotion"))) {
        if (input.value(QStringLiteral("reducedMotion")).metaType().id() == QMetaType::Bool)
            result.reducedMotion = input.value(QStringLiteral("reducedMotion")).toBool();
        else
            result.diagnostics.append(diagnostic(QStringLiteral("reducedMotion"), QStringLiteral("invalid-value"), QStringLiteral("Expected a boolean.")));
    }

    result.tokens = AirmailProfiles::profile(result.scheme, fontFamily);
    if (result.contrast == QLatin1String("high")) {
        const bool dark = result.scheme == QLatin1String("dark");
        auto colors = result.tokens.value(QStringLiteral("colors")).toMap();
        const QColor text(dark ? Qt::white : Qt::black);
        for (const auto *name : {"text", "secondaryText", "placeholderText", "outline", "separator"})
            colors.insert(QString::fromLatin1(name), text);
        colors.insert(QStringLiteral("selection"), QColor(dark ? "#363A40" : "#DDE2E7"));
        colors.insert(QStringLiteral("inactiveSelection"), QColor(dark ? "#303237" : "#E7EAEE"));
        result.tokens.insert(QStringLiteral("colors"), colors);
    }
    for (auto it = suppliedGroups.cbegin(); it != suppliedGroups.cend(); ++it) {
        if (!schema.contains(it.key())) {
            result.diagnostics.append(diagnostic(QStringLiteral("tokens.") + it.key(), QStringLiteral("unknown-field"), QStringLiteral("Unknown token group; ignored.")));
            continue;
        }
        auto group = result.tokens.value(it.key()).toMap();
        const auto values = it.value().toMap();
        for (auto field = values.cbegin(); field != values.cend(); ++field) {
            QVariant normalized;
            if (validate(it.key(), field.key(), field.value(), &normalized, &result.diagnostics)) {
                group.insert(field.key(), normalized);
                result.explicitTokens.insert(it.key() + QLatin1Char('.') + field.key());
            }
        }
        result.tokens.insert(it.key(), group);
    }
    return result;
}

ResolvedAppearance TokenSchema::calculatePalette(ResolvedAppearance result)
{
    const TraceSpan span(TraceScope::PaletteCalculate, nullptr);
    // Hue anchors always come from the selected profile, before explicit input.
    const auto semanticHueSeeds = AirmailProfiles::profile(result.scheme, {}).value(QStringLiteral("colors")).toMap();
    auto colors = result.tokens.value(QStringLiteral("colors")).toMap();
    auto motion = result.tokens.value(QStringLiteral("motion")).toMap();
    const auto color = [&](const QString &name) { return colors.value(name).value<QColor>(); };
    const auto derive = [&](const QString &name, const QColor &value) {
        if (!result.explicitTokens.contains(QStringLiteral("colors.") + name))
            colors.insert(name, value);
    };
    const qreal target = result.contrast == QLatin1String("high") ? 7 : 5;
    const qreal labelTarget = LabelContrastTarget;
    const QColor canvas = color(QStringLiteral("canvas"));
    const QColor content = composite(color(QStringLiteral("content")), composite(canvas, QColor(Qt::white)));
    QMap<QString, SemanticGroup> finalGroups;
    QList<PaletteFill> reserved;
    const auto install = [&](const SemanticGroup &group) {
        for (auto it = group.colors.cbegin(); it != group.colors.cend(); ++it)
            colors.insert(it.key(), it.value());
        finalGroups.insert(group.identity, group);
        reserved.append(groupFills(group, result.explicitTokens, content));
    };
    install(finalizeGroup(colors, result.explicitTokens, motion, QStringLiteral("accent"),
        color(QStringLiteral("accent")), false, canvas, content, target, labelTarget));
    for (const auto *role : {"error", "warning", "success"}) {
        const QString name = QString::fromLatin1(role);
        if (explicitColor(result.explicitTokens, name))
            install(finalizeGroup(colors, result.explicitTokens, motion, name, color(name), false, canvas, content, target, labelTarget));
    }
    // Reserve state-only inputs from all still-implicit groups before selecting
    // danger: even a later caution hover participates, without using its placeholder base.
    for (const auto *role : {"error", "warning"}) {
        const QString name = QString::fromLatin1(role), action = actionFor(name);
        if (finalGroups.contains(name))
            continue;
        for (const auto &state : {name + QStringLiteral("Hover"), name + QStringLiteral("Pressed"),
                 action + QStringLiteral("Surface"), action + QStringLiteral("Hover"), action + QStringLiteral("Pressed")}) {
            if (explicitColor(result.explicitTokens, state))
                reserved.append(paletteFill(name, state, color(state), content, false,
                    state.endsWith(QLatin1String("Surface")), true));
        }
    }
    const QColor visibleAccent = QColor::fromRgb(composite(color(QStringLiteral("accent")), content).rgb());
    const mcu::Hct paletteSeed(visibleAccent.rgb());
    const qreal seedChroma = visibleAccent.red() == visibleAccent.green() && visibleAccent.green() == visibleAccent.blue()
        ? 0 : paletteSeed.get_chroma();
    for (const auto *role : {"error", "warning", "success"}) {
        const QString name = QString::fromLatin1(role);
        if (!finalGroups.contains(name)) {
            const qreal anchor = mcu::Hct(semanticHueSeeds.value(name).value<QColor>().rgb()).get_hue();
            install(selectGroup(colors, result.explicitTokens, motion, name, paletteSeed, seedChroma,
                anchor, reserved, canvas, content, target, labelTarget, &result.diagnostics));
        }
    }
    QList<PaletteFill> finalFills;
    for (const auto *role : {"accent", "error", "warning", "success"})
        finalFills.append(groupFills(finalGroups.value(QString::fromLatin1(role)), result.explicitTokens, content));
    diagnoseCollisions(finalFills, &result.diagnostics);
    if (result.explicitTokens.contains(QStringLiteral("colors.control"))) {
        derive(QStringLiteral("controlHover"), blend(color(QStringLiteral("control")), color(QStringLiteral("text")), motion.value(QStringLiteral("hoverBlend")).toDouble()));
        derive(QStringLiteral("controlPressed"), blend(color(QStringLiteral("control")), color(QStringLiteral("text")), motion.value(QStringLiteral("pressedBlend")).toDouble()));
    }
    derive(QStringLiteral("focus"), contrastingText(color(QStringLiteral("accent")), {color(QStringLiteral("content"))}, canvas, 3));
    derive(QStringLiteral("accentText"), contrastingText(color(QStringLiteral("accent")), {color(QStringLiteral("content"))}, canvas, labelTarget));
    derive(QStringLiteral("link"), color(QStringLiteral("accentText")));
    result.tokens.insert(QStringLiteral("colors"), colors);

    const auto check = [&](const QString &foreground, const QString &background, qreal required, bool onContent = false) {
        const QColor backdrop = background == QLatin1String("canvas") ? QColor(Qt::white) : onContent ? content : canvas;
        checkContrast(&result.diagnostics, QStringLiteral("tokens.colors.") + foreground + QLatin1Char('/') + background,
                      color(foreground), composite(color(background), backdrop), required);
    };
    for (const auto *surface : {"canvas", "content", "popup", "control", "controlHover", "controlPressed", "selection", "inactiveSelection"})
        check(QStringLiteral("text"), QString::fromLatin1(surface), target);
    for (const auto *text : {"secondaryText", "placeholderText", "link", "accentText", "errorText", "warningText", "successText"})
        check(QString::fromLatin1(text), QStringLiteral("content"), target);
    for (const auto *role : {"error", "warning", "success"}) {
        const QString name = QString::fromLatin1(role);
        check(name + QStringLiteral("Text"), name + QStringLiteral("Surface"), target);
    }
    for (const auto *background : {"accent", "accentHover", "accentPressed"})
        check(QStringLiteral("onAccent"), QString::fromLatin1(background), target, true);
    for (const auto *background : {"error", "errorHover", "errorPressed"})
        check(QStringLiteral("onError"), QString::fromLatin1(background), target, true);
    for (const auto *background : {"warning", "warningHover", "warningPressed"})
        check(QStringLiteral("onWarning"), QString::fromLatin1(background), target, true);
    for (const auto *role : {"primary", "destructive", "caution"}) {
        const QString name = QString::fromLatin1(role);
        for (const auto *state : {"Surface", "Hover", "Pressed"})
            check(name + QStringLiteral("Text"), name + QString::fromLatin1(state), target, true);
        check(name + QStringLiteral("Outline"), name + QStringLiteral("Surface"), 3, true);
    }
    check(QStringLiteral("tooltipText"), QStringLiteral("tooltipBackground"), target);
    check(QStringLiteral("inverseText"), QStringLiteral("inverseSurface"), target);
    check(QStringLiteral("inverseSecondary"), QStringLiteral("inverseSurface"), target);
    check(QStringLiteral("outline"), QStringLiteral("content"), 3);
    check(QStringLiteral("focus"), QStringLiteral("content"), 3);
    if (canvas.alphaF() < 1)
        result.diagnostics.append(diagnostic(QStringLiteral("tokens.colors.canvas"), QStringLiteral("translucent-canvas"),
                                            QStringLiteral("Contrast uses white behind a translucent canvas; verify the actual host background.")));
    return result;
}

void TokenSchema::resolveNoncolors(ResolvedAppearance *prepared,
                                  const ResolvedAppearance *previousInput,
                                  const ResolvedAppearance *previousOutput)
{
    auto &result = *prepared;
    const auto unchanged = [&](const QString &group) {
        return previousInput && previousOutput
            && result.tokens.value(group) == previousInput->tokens.value(group);
    };
    const QString metricGroup = QStringLiteral("metrics");
    if (unchanged(metricGroup) && result.density == previousInput->density
        && result.contrast == previousInput->contrast) {
        result.tokens.insert(metricGroup, previousOutput->tokens.value(metricGroup));
    } else {
        auto metrics = result.tokens.value(metricGroup).toMap();
        if (result.density == QLatin1String("touch")) {
            for (const auto *role : {"controlHeight", "toolHeight", "rowHeight", "targetSize"}) {
                const QString name = QString::fromLatin1(role);
                metrics.insert(name, std::max(qreal(44), metrics.value(name).toDouble()));
            }
        }
        if (result.contrast == QLatin1String("high")) {
            metrics.insert(QStringLiteral("borderWidth"), std::max(qreal(2), metrics.value(QStringLiteral("borderWidth")).toDouble()));
            metrics.insert(QStringLiteral("focusWidth"), std::max(qreal(3), metrics.value(QStringLiteral("focusWidth")).toDouble()));
        }
        result.tokens.insert(metricGroup, metrics);
    }
    const QString typeGroup = QStringLiteral("typography");
    if (unchanged(typeGroup) && result.fontScale == previousInput->fontScale) {
        result.tokens.insert(typeGroup, previousOutput->tokens.value(typeGroup));
    } else {
        auto typography = result.tokens.value(typeGroup).toMap();
#define IA_SCALE_SIZE(name, defaultValue, min, max) typography.insert(QStringLiteral(#name), typography.value(QStringLiteral(#name)).toDouble() * result.fontScale);
        IA_TYPE_SIZE_TOKENS(IA_SCALE_SIZE)
#undef IA_SCALE_SIZE
        result.tokens.insert(typeGroup, typography);
    }
    const QString motionGroup = QStringLiteral("motion");
    if (unchanged(motionGroup) && result.reducedMotion == previousInput->reducedMotion) {
        result.tokens.insert(motionGroup, previousOutput->tokens.value(motionGroup));
    } else {
        auto motion = result.tokens.value(motionGroup).toMap();
        if (result.reducedMotion) {
            for (const auto *name : {"feedbackDuration", "popupDuration", "busyDuration"})
                motion.insert(QString::fromLatin1(name), 0);
        }
        result.tokens.insert(motionGroup, motion);
    }
    const QString iconGroup = QStringLiteral("icons");
    if (unchanged(iconGroup))
        result.tokens.insert(iconGroup, previousOutput->tokens.value(iconGroup));
}

} // namespace InterActive
