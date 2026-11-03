// SPDX-License-Identifier: LGPL-3.0-or-later
#include "LabelContrastTrial.h"
#include "cpp/cam/hct.h"
#include "cpp/contrast/contrast.h"
#include "cpp/utils/utils.h"
#include <algorithm>
#include <cmath>
#include <limits>

namespace InterActivePlayground {
namespace {
namespace mcu = material_color_utilities;

qreal luminance(const QColor &color)
{
    const auto linear = [](qreal c) { return c <= 0.04045 ? c / 12.92 : std::pow((c + 0.055) / 1.055, 2.4); };
    return 0.2126 * linear(color.redF()) + 0.7152 * linear(color.greenF()) + 0.0722 * linear(color.blueF());
}

qreal ratioOfLuminances(qreal a, qreal b)
{
    return (std::max(a, b) + 0.05) / (std::min(a, b) + 0.05);
}

QColor atTone(qreal hue, qreal chroma, qreal tone)
{
    // The HCT solver may reduce chroma to fit sRGB; the result is RGB8.
    return QColor::fromRgb(mcu::Hct(hue, chroma, tone).ToInt());
}
} // namespace

TrialLabel trialLabel(TrialRule rule, const QColor &fill, const QList<QColor> &surfaces, qreal target)
{
    if (!fill.isValid() || surfaces.isEmpty() || !std::isfinite(target) || target < 1 || target > 21)
        return {};
    QList<qreal> surfaceLuminances;
    surfaceLuminances.reserve(surfaces.size());
    qreal minimumTone = std::numeric_limits<qreal>::infinity();
    qreal maximumTone = -std::numeric_limits<qreal>::infinity();
    for (const QColor &surface : surfaces) {
        if (!surface.isValid())
            return {};
        const qreal y = luminance(surface);
        surfaceLuminances.append(y);
        const qreal tone = mcu::LstarFromY(y * 100);
        minimumTone = std::min(minimumTone, tone);
        maximumTone = std::max(maximumTone, tone);
    }
    const auto measure = [&surfaceLuminances](const QColor &label) {
        const qreal labelLuminance = luminance(label);
        qreal minimum = std::numeric_limits<qreal>::infinity();
        for (const qreal surfaceLuminance : surfaceLuminances)
            minimum = std::min(minimum, ratioOfLuminances(labelLuminance, surfaceLuminance));
        return TrialLabel{label, minimum};
    };

    const QColor opaqueFill = QColor::fromRgb(fill.rgb());
    const mcu::Hct hct(opaqueFill.rgb());
    // As in Foundation: CAM16 gives RGB gray a small residual chroma that is not intent.
    const bool gray = opaqueFill.red() == opaqueFill.green() && opaqueFill.green() == opaqueFill.blue();
    const qreal hue = hct.get_hue();
    const qreal chroma = gray ? 0 : hct.get_chroma();

    if (rule == TrialRule::StrongestHue) {
        // target is only the reported floor; it does not affect the choice.
        const TrialLabel dark = measure(atTone(hue, chroma, 10));
        const TrialLabel light = measure(atTone(hue, chroma, 97));
        return light.minimumRatio > dark.minimumRatio ? light : dark;
    }

    // Foundation's fast path at a fixed target; no interval fallback.
    QList<QColor> proposals{opaqueFill};
    if (const qreal tone = mcu::Darker(minimumTone, target); tone >= 0)
        proposals.append(atTone(hue, chroma, tone));
    if (const qreal tone = mcu::Lighter(maximumTone, target); tone >= 0)
        proposals.append(atTone(hue, chroma, tone));
    proposals.append(QColor(Qt::black));
    proposals.append(QColor(Qt::white));

    TrialLabel closest;
    qreal closestDistance = std::numeric_limits<qreal>::infinity();
    bool passing = false;
    TrialLabel strongest;
    for (const QColor &proposal : proposals) {
        const TrialLabel candidate = measure(proposal);
        if (!strongest.label.isValid() || candidate.minimumRatio > strongest.minimumRatio)
            strongest = candidate;
        if (candidate.minimumRatio < target)
            continue;
        const qreal distance = std::abs(mcu::LstarFromArgb(proposal.rgb()) - hct.get_tone());
        if (!passing || distance < closestDistance
            || (distance == closestDistance && proposal.rgb() < closest.label.rgb())) {
            closest = candidate;
            closestDistance = distance;
            passing = true;
        }
    }
    return passing ? closest : strongest;
}

} // namespace InterActivePlayground
