// SPDX-License-Identifier: LGPL-3.0-or-later
#include "StateTable.h"
#include "PaletteState_p.h"

namespace InterActive {

StateColors StateTable::colors(Presentation::State state) const
{
    if (!m_data || state < Presentation::Rest || state > Presentation::Disabled)
        return {};
    return m_data->states[size_t(state)];
}

bool StateTable::operator==(const StateTable &other) const
{
    return m_data == other.m_data
        || (m_data && other.m_data && m_data->states == other.m_data->states);
}

} // namespace InterActive
