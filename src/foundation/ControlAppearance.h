// SPDX-License-Identifier: LGPL-3.0-or-later
#pragma once

#include "Appearance.h"
#include "Presentation.h"
#include <QFont>
#include <QPointer>

#define IA_CONTROL_COLOR_PROPERTIES(X) \
    X(QColor, backgroundColor, BackgroundColor, colors, control) \
    X(QColor, fillColor, FillColor, colors, accent) \
    X(QColor, foregroundColor, ForegroundColor, colors, text) \
    X(QColor, hoverBackgroundColor, HoverBackgroundColor, colors, controlHover) \
    X(QColor, pressedBackgroundColor, PressedBackgroundColor, colors, controlPressed) \
    X(QColor, disabledBackgroundColor, DisabledBackgroundColor, colors, disabledSurface) \
    X(QColor, disabledForegroundColor, DisabledForegroundColor, colors, disabledText) \
    X(QColor, inactiveBackgroundColor, InactiveBackgroundColor, colors, inactiveSelection) \
    X(QColor, inactiveForegroundColor, InactiveForegroundColor, colors, text) \
    X(QColor, selectedBackgroundColor, SelectedBackgroundColor, colors, selection) \
    X(QColor, selectedForegroundColor, SelectedForegroundColor, colors, text) \
    X(QColor, borderColor, BorderColor, colors, outline) \
    X(QColor, disabledBorderColor, DisabledBorderColor, colors, outline) \
    X(QColor, focusColor, FocusColor, colors, focus)

#define IA_CONTROL_NONCOLOR_PROPERTIES(X) \
    X(qreal, controlRadius, ControlRadius, metrics, controlRadius) \
    X(QString, fontFamily, FontFamily, typography, family) \
    X(qreal, fontPixelSize, FontPixelSize, typography, controlSize) \
    X(int, fontWeight, FontWeight, typography, controlWeight) \
    X(qreal, minimumHeight, MinimumHeight, metrics, controlHeight) \
    X(qreal, horizontalPadding, HorizontalPadding, metrics, horizontalPadding) \
    X(qreal, verticalPadding, VerticalPadding, metrics, verticalPadding) \
    X(qreal, spacing, Spacing, metrics, spacing)

#define IA_CONTROL_PROPERTIES(X) \
    IA_CONTROL_COLOR_PROPERTIES(X) \
    IA_CONTROL_NONCOLOR_PROPERTIES(X)

namespace InterActive {

struct ControlAppearancePrivate;

class INTERACTIVE_FOUNDATION_EXPORT ControlAppearance : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(InterActive::Appearance *source READ source WRITE setSource NOTIFY sourceChanged FINAL)
    Q_PROPERTY(QString family READ family WRITE setFamily NOTIFY familyChanged FINAL)
    Q_PROPERTY(InterActive::Presentation::Tone tone READ tone WRITE setTone NOTIFY toneChanged FINAL)
    Q_PROPERTY(InterActive::Presentation::Validation validation READ validation WRITE setValidation NOTIFY validationChanged FINAL)
#define IA_LOCAL_PROPERTY(type, name, upper, group, token) \
    Q_PROPERTY(type name READ name WRITE set##upper RESET reset##upper NOTIFY name##Changed FINAL)
    IA_CONTROL_PROPERTIES(IA_LOCAL_PROPERTY)
#undef IA_LOCAL_PROPERTY
    Q_PROPERTY(QFont resolvedFont READ resolvedFont NOTIFY resolvedFontChanged FINAL)
    Q_PROPERTY(QVariantList diagnostics READ diagnostics NOTIFY diagnosticsChanged FINAL)
public:
    explicit ControlAppearance(QObject *parent = nullptr);
    ~ControlAppearance() override;
    Appearance *source() const { return m_source.data(); }
    void setSource(Appearance *source);
    QString family() const { return m_family; }
    void setFamily(const QString &family);
    Presentation::Tone tone() const { return m_tone; }
    void setTone(Presentation::Tone tone);
    Presentation::Validation validation() const { return m_validation; }
    void setValidation(Presentation::Validation validation);
#define IA_LOCAL_METHODS(type, name, upper, group, token) \
    type name() const; \
    void set##upper(const type &value); \
    void reset##upper();
    IA_CONTROL_PROPERTIES(IA_LOCAL_METHODS)
#undef IA_LOCAL_METHODS
    QFont resolvedFont() const { return m_font; }
    QVariantList diagnostics() const { return m_diagnostics; }
    Q_INVOKABLE void resetOverrides();
signals:
    void resolvedChanged();
    void sourceChanged();
    void familyChanged();
    void toneChanged();
    void validationChanged();
    void resolvedFontChanged();
    void diagnosticsChanged();
#define IA_LOCAL_SIGNAL(type, name, upper, group, token) void name##Changed();
    IA_CONTROL_PROPERTIES(IA_LOCAL_SIGNAL)
#undef IA_LOCAL_SIGNAL
private:
    void setOverride(const QString &name, const QString &group, const QString &token, const QVariant &value);
    void resetOverride(const QString &name);
    void resolve();
    QPointer<Appearance> m_source;
    QMetaObject::Connection m_sourceChanged;
    QMetaObject::Connection m_sourceDestroyed;
    const ResolvedAppearance m_defaults;
    std::unique_ptr<ControlAppearancePrivate> m_private;
    QString m_family = QStringLiteral("button");
    Presentation::Tone m_tone = Presentation::Auto;
    Presentation::Validation m_validation = Presentation::None;
    QVariantMap m_overrides;
    QVariantMap m_values;
    QVariantMap m_invalidInputs;
    QVariantList m_diagnostics;
    QFont m_font;
};

} // namespace InterActive
