// SPDX-License-Identifier: LGPL-3.0-or-later
#pragma once

#include "Presentation.h"
#include <QColor>
#include <memory>

namespace InterActive {

struct StateTableData;

class INTERACTIVE_FOUNDATION_EXPORT StateColors
{
    Q_GADGET
    QML_VALUE_TYPE(stateColors)
    Q_PROPERTY(QColor backgroundColor READ backgroundColor CONSTANT FINAL)
    Q_PROPERTY(QColor foregroundColor READ foregroundColor CONSTANT FINAL)
    Q_PROPERTY(QColor borderColor READ borderColor CONSTANT FINAL)
    Q_PROPERTY(QColor focusColor READ focusColor CONSTANT FINAL)
public:
    StateColors() = default;
    StateColors(QColor background, QColor foreground, QColor border, QColor focus)
        : m_background(std::move(background)), m_foreground(std::move(foreground)),
          m_border(std::move(border)), m_focus(std::move(focus)) {}
    QColor backgroundColor() const { return m_background; }
    QColor foregroundColor() const { return m_foreground; }
    QColor borderColor() const { return m_border; }
    QColor focusColor() const { return m_focus; }
    bool operator==(const StateColors &other) const
    {
        return m_background == other.m_background && m_foreground == other.m_foreground
            && m_border == other.m_border && m_focus == other.m_focus;
    }
private:
    QColor m_background, m_foreground, m_border, m_focus;
};

// A cheap owning value, not another QObject per control. Reading the facade's
// stateTable property establishes the binding dependency before the array lookup.
class INTERACTIVE_FOUNDATION_EXPORT StateTable
{
    Q_GADGET
    QML_VALUE_TYPE(stateTable)
public:
    StateTable() = default;
    explicit StateTable(std::shared_ptr<const StateTableData> data) : m_data(std::move(data)) {}
    Q_INVOKABLE InterActive::StateColors colors(InterActive::Presentation::State state) const;
    bool operator==(const StateTable &other) const;
    bool operator!=(const StateTable &other) const { return !(*this == other); }
private:
    std::shared_ptr<const StateTableData> m_data;
};

} // namespace InterActive
