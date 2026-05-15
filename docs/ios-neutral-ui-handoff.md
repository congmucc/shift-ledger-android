# Shift Ledger iOS Neutral UI Handoff

## Purpose

This document is for the next AI/developer implementing the visual redesign. The user selected **B. iOS Neutral** from the HTML mockups. Do not use the old warm paper-ledger palette.

Primary source of truth: `DESIGN.md`.

Visual reference created in this session:

- `.superpowers/brainstorm/74314-1778821651/content/color-full-html-v1.html`

If `.superpowers/` is not available, recreate from `DESIGN.md` rather than guessing.

## Selected Direction

**iOS Neutral**:

- White and very light gray backgrounds.
- Clean white or near-white cards.
- iOS-like blue for primary actions.
- iOS-like green for success, overtime, and positive values.
- Indigo for night shift.
- Orange for warning states.
- Red for destructive/error states.
- Low shadows, clear borders, high readability.

The UI should feel like a modern mobile utility app, not a warm paper notebook, not an enterprise admin dashboard, and not a playful tracker.

## Important User Feedback

The previous proposal had a flawed homepage summary with fixed two metric cells such as `普通 / 加班`. The user pointed out this breaks when a day has normal work plus multiple overtime segments.

Implementation must support:

- normal work only;
- normal work + one overtime;
- normal work + multiple overtime segments;
- multiple normal segments;
- night shift;
- allowances, deductions, and notes;
- no record state.

Do not assume one day has at most one overtime segment.

## Color Tokens To Implement

Replace the existing warm palette in `lib/src/ui/theme.dart` with iOS Neutral tokens. Suggested mapping:

| New semantic token | Hex | Purpose |
| --- | --- | --- |
| `background` | `#FFFFFF` | Main app background |
| `canvas` | `#F9FAFB` | Secondary screen background |
| `surface` | `#FAFAFA` | Cards and grouped sections |
| `surfaceRaised` | `#FFFFFF` | Elevated cards, sheets, dialogs |
| `hairline` | `#E5E7EB` | Default border/divider |
| `hairlineStrong` | `#D1D5DB` | Selected border / stronger divider |
| `ink` | `#111827` | Primary text and numbers |
| `muted` | `#6B7280` | Secondary text |
| `subtle` | `#9CA3AF` | Weak secondary text |
| `primaryBlue` | `#007AFF` | Primary actions, selected state, add button |
| `primaryBlueSoft` | `#E5F1FF` | Soft selected and normal-work backgrounds |
| `successGreen` | `#34C759` | Success, overtime, positive values |
| `successGreenSoft` | `#DCFCE7` | Soft overtime/success chip backgrounds |
| `nightIndigo` | `#5856D6` | Night shift |
| `nightIndigoSoft` | `#EDE9FE` | Soft night-shift backgrounds |
| `warningOrange` | `#FF9500` | Warnings and waiting states |
| `warningOrangeSoft` | `#FFF7ED` | Soft warning backgrounds |
| `errorRed` | `#FF3B30` | Errors/destructive actions |
| `errorRedSoft` | `#FEE2E2` | Soft destructive backgrounds |

If keeping old token names for compatibility, remap them semantically:

- `paper` → `#FFFFFF` or `#F9FAFB`
- `surface` → `#FAFAFA`
- `surfaceRaised` → `#FFFFFF`
- `workAmber` → blue normal-work role, not amber
- `overtimeMoss` → green overtime role
- `nightSlate` → indigo night role
- `warningCopper` → `#007AFF` for primary actions, or introduce a new token name
- `errorBrick` → `#FF3B30`
- `infoBlue` → `#007AFF`

Prefer renaming tokens only if the change remains small and safe. Otherwise keep compatibility aliases and update visual values.

## Implementation Scope

### 1. Theme

File: `lib/src/ui/theme.dart`

- Replace warm paper palette with iOS Neutral palette.
- Set scaffold background to white or very light gray.
- Use Material color scheme with blue primary, green secondary/success, red error.
- Keep `ShiftLedgerCJK` font family and fallback.

### 2. Shared Components

File: `lib/src/ui/widgets.dart`

- `LedgerCard`: white/near-white surface, gray border, low or no shadow, 20-24dp radius.
- `MetricCard`: stronger number hierarchy, neutral card background.
- `WorkEntryTile`: left status rail should use blue/green/indigo depending on normal/overtime/night.
- Any status chips should support wrapping and semantic color roles.

### 3. Homepage

File: `lib/src/ui/pages/home_page.dart`

Key requirement: homepage summary must be dynamic.

Do:

- Large `今日已记录` card with total hours as main visual anchor.
- Use wrap-style chips for summary categories, e.g. `普通 7.5h`, `加班 1.0h`, `加班 2.0h`, `夜班 1次`.
- Show real segment list below the chips.
- Keep primary actions to `补一段` and `看日历` or similarly focused actions.

Do not:

- Use fixed two-column metric cells for `普通 / 加班`.
- Assume only one overtime segment.
- Hide details when there are more than two segments.

### 4. Calendar

File: `lib/src/ui/pages/calendar_page.dart`

- Calendar container should be white/neutral, not warm paper.
- Normal work: soft blue.
- Overtime: soft green.
- Night shift: soft indigo.
- Today: blue outline.
- Selected day: stronger blue outline with white fill.
- Notes: dot/icon plus accessible semantics.
- Do not rely only on color.

### 5. Summary

File: `lib/src/ui/pages/summary_page.dart`

- Core metric cards use neutral cards and strong dark numbers.
- Bars/charts use blue for normal work, green for overtime, indigo for night, orange for warnings.
- Income/positive values can use green, but do not overuse green for decoration.

### 6. Settings

File: `lib/src/ui/pages/settings_page.dart`

- White/gray grouped sections.
- Clear section headings.
- Status chips for connected/waiting/failed states.
- Avoid dense warm cards.

### 7. Shell / Bottom Navigation

File: `lib/src/ui/shell.dart`

- Bottom nav should be white or `surfaceRaised` with gray border.
- Center add button should use `primaryBlue` with white plus.
- Selected tab should use blue text or soft-blue pill.
- Touch targets remain at least 44dp.

### 8. Edit Sheet / Pickers

Files:

- `lib/src/ui/edit_entry_sheet.dart`
- `lib/src/ui/pickers.dart`

- Bottom sheets use white raised surface.
- Fields use neutral borders and grouped cards.
- Primary save button blue.
- Destructive actions red and confirmed.

## Acceptance Checklist

- App no longer has a warm yellow/cream global background.
- Main backgrounds are white or very light gray.
- Primary action color is iOS-like blue.
- Overtime is green and supports multiple overtime segments.
- Night shift is indigo.
- Calendar and homepage do not rely only on color to communicate status.
- Text contrast remains readable, especially muted text.
- Touch targets remain at least 44dp.
- `flutter analyze` passes.
- Existing tests pass, or failures are explained.
- Web preview is launched after changes so the user can inspect UI.

## Suggested Verification Commands

```bash
flutter analyze
flutter test
flutter run -d chrome
```

If Chrome/web target is unavailable, run the closest available Flutter web target and report the exact limitation.

## Out of Scope

- Do not add new features.
- Do not change data model or storage.
- Do not redesign navigation structure beyond visual styling.
- Do not introduce dark mode unless explicitly requested.
- Do not create a new design abstraction layer unless needed to keep the current change safe.
