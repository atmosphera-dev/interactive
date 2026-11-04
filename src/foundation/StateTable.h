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
    Q_PROPERTY(QColor fillColor READ fillColor CONSTANT FINAL)
    Q_PROPERTY(QColor trackColor READ trackColor CONSTANT FINAL)
    Q_PROPERTY(QColor placeholderTextColor READ placeholderTextColor CONSTANT FINAL)
public:
    StateColors() = default;
    StateColors(QColor background, QColor foreground, QColor border, QColor focus,
                QColor fill = {}, QColor track = {}, QColor placeholder = {})
        : m_background(std::move(background)), m_foreground(std::move(foreground)),
          m_border(std::move(border)), m_focus(std::move(focus)), m_fill(std::move(fill)),
          m_track(std::move(track)), m_placeholder(std::move(placeholder)) {}
    QColor backgroundColor() const { return m_background; }
    QColor foregroundColor() const { return m_foreground; }
    QColor borderColor() const { return m_border; }
    QColor focusColor() const { return m_focus; }
    QColor fillColor() const { return m_fill; }
    QColor trackColor() const { return m_track; }
    QColor placeholderTextColor() const { return m_placeholder; }
    bool operator==(const StateColors &other) const
    {
        return m_background == other.m_background && m_foreground == other.m_foreground
            && m_border == other.m_border && m_focus == other.m_focus
            && m_fill == other.m_fill && m_track == other.m_track && m_placeholder == other.m_placeholder;
    }
private:
    QColor m_background, m_foreground, m_border, m_focus, m_fill, m_track, m_placeholder;
};

// A cheap owning value, not another QObject per control. Reading the facade's
// stateTable property establishes the binding dependency before the array lookup.
class INTERACTIVE_FOUNDATION_EXPORT StateTable
{
    Q_GADGET
    QML_VALUE_TYPE(stateTable)
    Q_PROPERTY(QColor selectionColor READ selectionColor CONSTANT FINAL)
    Q_PROPERTY(QColor selectedTextColor READ selectedTextColor CONSTANT FINAL)
    Q_PROPERTY(QColor linkColor READ linkColor CONSTANT FINAL)
public:
    StateTable() = default;
    explicit StateTable(std::shared_ptr<const StateTableData> data) : m_data(std::move(data)) {}
    Q_INVOKABLE InterActive::StateColors colors(InterActive::Presentation::State state) const;
    QColor selectionColor() const;
    QColor selectedTextColor() const;
    QColor linkColor() const;
    bool operator==(const StateTable &other) const;
    bool operator!=(const StateTable &other) const { return !(*this == other); }
private:
    std::shared_ptr<const StateTableData> m_data;
};

} // namespace InterActive
