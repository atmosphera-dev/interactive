// SPDX-License-Identifier: LGPL-3.0-or-later
#pragma once

#include <QColor>
#include <QList>

// Temporary playground-only comparison of two label rules for solid fills.
// Foundation's contrastingText is unchanged; this is removed once a rule is chosen.
namespace InterActivePlayground {

struct TrialLabel {
    QColor label;
    qreal minimumRatio = 0;
};

enum class TrialRule { StrongestHue, ClosestPassing };

// surfaces: the opaque resting, hover and pressed fills. minimumRatio is the
// lowest WCAG ratio of the RGB8 label across them. An invalid input returns {}.
TrialLabel trialLabel(TrialRule rule, const QColor &fill, const QList<QColor> &surfaces, qreal target);

} // namespace InterActivePlayground
