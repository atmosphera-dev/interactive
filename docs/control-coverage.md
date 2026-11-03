# Control Coverage

This is the first mixed-control overview, not the complete library/gallery.
All listed controls use Qt templates and the shared IA appearance resolver.
Ordinary Qt Controls are not an IA fallback.

| # | Family | Implemented For The Overview |
|---|---|---|
| 1 | Actions and navigation | IAButton, IAToolButton, IAToolBar, IAToolSeparator, IATabBar, IATabButton |
| 2 | Text and forms | IALabel, IATextField |
| 3 | Choices | IACheckBox, IARadioButton, IASwitch |
| 4 | Lists and scrolling | IAItemDelegate, IAScrollView, IAScrollBar |
| 5 | Values | IASlider, IAProgressBar |
| 6 | Surfaces and overlays | IAPane, IAFrame, IAMenu, IAMenuItem, IAMenuSeparator, IAPopup, IADialog, IADialogButtonBox, standalone IAToolTip |
| 7 | Compositions | IAFieldRow, IASettingsRow, IAStatusBanner, IAEmptyState |

Menu delegates, submenu arrows/checkmarks, dialog footer buttons, scroll bars,
focus treatment, and source/name icons are supplied by the library rather than
page-local replacements. Foundation owns the neutral SVG fixtures and rendering
helpers. See the verification manifest for observed outcomes, not this inventory
alone: implementation presence is not runtime proof.

The approved remaining pool includes IARoundButton, IATextArea, IAComboBox,
IASpinBox, IASegmentedSelector, IACheckDelegate, IARadioDelegate,
IASwitchDelegate, IAScrollIndicator, IARangeSlider, IABusyIndicator,
IAApplicationWindow, IAPage, IAGroupBox, IAMenuBar, IAMenuBarItem, and the
attached-tooltip helper. The five additional gallery pages, relocated installed
consumer, current-Qt full verification, and accessibility gates also remain.
Their scope has not been removed or downgraded. Work pauses for the first visual
review before completing that pool. The current overview suites do not establish
full library or gallery completion.
