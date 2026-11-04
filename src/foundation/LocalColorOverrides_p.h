// SPDX-License-Identifier: LGPL-3.0-or-later
#pragma once
#include "PaletteState_p.h"
#include <functional>

namespace InterActive {

class LocalColorOverrides
{
public:
    void install(const PaletteState &palette, const ControlColorMapping &mapping,
                 const QVariantMap &overrides, bool coupleBorder, const void *owner, quint64 revision);
    QColor color(ControlColor property, const PaletteState &palette, const ControlColorMapping &mapping) const;
    std::shared_ptr<const ControlFindings> findings() const { return m_findings; }
private:
    struct Branch {
        QVariantList inputs;
        QColor result;
        bool valid = false;
        QColor evaluate(const QVariantList &next, const std::function<QColor()> &calculate,
                        const char *operation, const void *owner, quint64 revision);
    };
    struct Pair {
        QVariantList inputs;
        QVariantList findings;
        bool valid = false;
    };
    Branch m_resting, m_hover, m_pressed, m_foreground, m_selected, m_inactive;
    std::array<Pair, 6> m_pairs;
    QVariantMap m_values;
    std::shared_ptr<const ControlFindings> m_findings;
};

} // namespace InterActive
