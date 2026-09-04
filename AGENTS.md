# Project instructions

## SwiftUI control tooltips

- Every interactive control in the app must have a concise tooltip. This includes buttons, menus, pickers, toggles, sliders, text fields, clickable tabs, and clickable file or search-result rows.
- Use `.controlTooltip(description, shortcut:)` for app controls. Describe the resulting action, not the icon or implementation.
- When a control has a working keyboard shortcut—whether declared with `.keyboardShortcut`, handled by `KeyboardEventMonitor`, or exposed through the function-key bar—include the user-facing key notation in the tooltip's `shortcut` argument.
- Do not advertise an unwired shortcut. Keep tooltip shortcut text synchronized with `KeyboardEventMonitor`, app commands, `ShortcutGuideView`, and the README keyboard reference.
- Noninteractive labels, status indicators, and decorative images do not need tooltips.
