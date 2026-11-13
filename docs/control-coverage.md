# Control Coverage

Controls implemented so far.
All listed controls use Qt templates and the shared IA appearance resolver.
Ordinary Qt Controls are not an IA fallback.

| # | Family | Implemented For The Overview |
|---|---|---|
| 1 | Actions and navigation | IAButton, IAToolButton, IAToolBar, IAToolSeparator, IATabBar, IATabButton |
| 2 | Text and forms | IALabel, IATextField |
| 3 | Choices | IACheckBox, IARadioButton, IASwitch (leading/trailing), IASegmentedControl, IASegmentedButton |
| 4 | Lists and scrolling | IAItemDelegate, IAScrollView, IAScrollBar |
| 5 | Values | IASlider, IAProgressBar |
| 6 | Surfaces and overlays | IAPane, IAFrame, IAMenu, IAMenuItem, IAMenuSeparator, IAPopup, IADialog, IADialogButtonBox, standalone IAToolTip |
| 7 | Compositions | IAFieldRow, IASettingsRow, IAStatusBanner, IAEmptyState |

Menu delegates, submenu arrows/checkmarks, dialog footer buttons, scroll bars,
focus treatment, and source/name icons are supplied by the library rather than
page-local replacements. Foundation owns the neutral SVG fixtures and rendering
helpers. See [test coverage](playground.md#test-coverage) for observed outcomes:
implementation presence is not runtime proof.

Planned controls: IARoundButton, IATextArea, IAComboBox, IASpinBox,
IACheckDelegate, IARadioDelegate, IASwitchDelegate,
IAScrollIndicator, IARangeSlider, IABusyIndicator, IAApplicationWindow,
IAPage, IAGroupBox, IAMenuBar, IAMenuBarItem and the attached-tooltip helper.
Also planned: the five further gallery pages (Actions, Forms, Values, Lists,
Overlays), a relocated installed-consumer proof, full verification on a current
Qt release, and accessibility checks. The current suites do not establish full
library or gallery completion.
