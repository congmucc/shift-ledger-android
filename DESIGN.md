---
version: alpha
name: Shift Ledger
description: "A warm, local-first personal work-hour ledger for shift workers: calendar-first, numerically trustworthy, and private. The system should feel like a careful paper ledger with modern mobile clarity, not an enterprise attendance console."

colors:
  paper: "#F8F1E7"
  surface: "#FFFCF6"
  surface-soft: "#EFE2D1"
  surface-raised: "#FFF8EE"
  hairline: "#DFD1BF"
  hairline-strong: "#CDBBA7"
  ink: "#17130F"
  charcoal: "#273C35"
  muted: "#6F665C"
  stone: "#A99B8B"
  on-accent: "#FFFFFF"
  work-amber: "#B8652F"
  work-amber-soft: "#E9C29B"
  overtime-moss: "#2F765C"
  overtime-moss-soft: "#98C7AC"
  night-slate: "#273C35"
  night-slate-soft: "#8EA39A"
  warning-copper: "#8F4D18"
  error-brick: "#9D3D32"
  info-blue: "#5D7182"
  rest-tint: "#E8DFD2"
  issue-tint: "#D9917B"

typography:
  display-metric:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 46px
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: -0.04em
    fontFeature: "tnum"
  headline-lg:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 28px
    fontWeight: 750
    lineHeight: 1.15
    letterSpacing: -0.02em
  headline-md:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 22px
    fontWeight: 700
    lineHeight: 1.22
    letterSpacing: -0.01em
  title-sm:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 17px
    fontWeight: 700
    lineHeight: 1.32
  body-md:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 15px
    fontWeight: 400
    lineHeight: 1.55
  body-strong:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 15px
    fontWeight: 650
    lineHeight: 1.45
  label-md:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 13px
    fontWeight: 650
    lineHeight: 1.35
  caption:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 12px
    fontWeight: 500
    lineHeight: 1.35
  numeric-sm:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 13px
    fontWeight: 650
    lineHeight: 1.25
    fontFeature: "tnum"
  micro:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: 10px
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: 0.02em

rounded:
  none: "0px"
  xs: "6px"
  sm: "10px"
  md: "14px"
  lg: "18px"
  xl: "24px"
  xxl: "30px"
  full: "9999px"

spacing:
  xxs: "4px"
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "20px"
  xl: "24px"
  xxl: "32px"
  section: "40px"
  page-margin: "16px"
  touch-target: "44px"

components:
  app-shell:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
  page-title:
    textColor: "{colors.ink}"
    typography: "{typography.headline-lg}"
  metric-primary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.display-metric}"
    rounded: "{rounded.xl}"
    padding: "{spacing.xl}"
    border: "1px solid {colors.hairline}"
  card-ledger:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.xl}"
    padding: "{spacing.lg}"
    border: "1px solid {colors.hairline}"
  card-soft-band:
    backgroundColor: "{colors.surface-soft}"
    textColor: "{colors.charcoal}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: "{spacing.md}"
  work-entry-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: "{spacing.md}"
    border: "1px solid {colors.hairline}"
  calendar-day:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.ink}"
    typography: "{typography.numeric-sm}"
    rounded: "{rounded.sm}"
    padding: "{spacing.xs}"
  calendar-day-work:
    backgroundColor: "{colors.work-amber-soft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
  calendar-day-overtime:
    backgroundColor: "{colors.overtime-moss-soft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
  calendar-day-night:
    backgroundColor: "{colors.night-slate-soft}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
  button-primary:
    backgroundColor: "{colors.warning-copper}"
    textColor: "{colors.on-accent}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.full}"
    padding: "12px 18px"
    height: "{spacing.touch-target}"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.full}"
    padding: "12px 18px"
    border: "1px solid {colors.hairline-strong}"
  button-danger:
    backgroundColor: "{colors.error-brick}"
    textColor: "{colors.on-accent}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.full}"
    padding: "12px 18px"
  center-add-button:
    backgroundColor: "{colors.charcoal}"
    textColor: "{colors.on-accent}"
    rounded: "{rounded.full}"
    size: "56px"
  text-input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: "12px 14px"
    border: "1px solid {colors.hairline}"
    height: "{spacing.touch-target}"
  text-input-focused:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    border: "2px solid {colors.work-amber}"
  chip-work:
    backgroundColor: "{colors.work-amber-soft}"
    textColor: "{colors.ink}"
    typography: "{typography.caption}"
    rounded: "{rounded.full}"
    padding: "5px 10px"
  chip-overtime:
    backgroundColor: "{colors.overtime-moss-soft}"
    textColor: "{colors.ink}"
    typography: "{typography.caption}"
    rounded: "{rounded.full}"
    padding: "5px 10px"
  chip-night:
    backgroundColor: "{colors.night-slate}"
    textColor: "{colors.on-accent}"
    typography: "{typography.caption}"
    rounded: "{rounded.full}"
    padding: "5px 10px"
  bottom-nav:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.muted}"
    typography: "{typography.caption}"
    rounded: "{rounded.xl}"
    padding: "8px 14px"
    border: "1px solid {colors.hairline}"
---

# Design System: Shift Ledger

## Overview

Shift Ledger 是一个私人“工时账本”设计系统。它记录个人每天到底上了哪些班、工作了多久、是否加班或夜班、这段周期应该拿多少钱；它不是企业考勤系统，也不是团队管理后台。

整体气质是 **暖色纸面、安静金融感、日历优先、数字可信、低压私密**。用户打开应用时应感觉自己在核对一本清楚可靠的个人账册：日期、分段、工时、加班、夜班和备注比炫酷装饰更重要；收入可以被计算和汇总，但不能压过“我哪天干了什么、干了多久”这个核心任务。

该 DESIGN.md 是跨平台视觉源文件：同一套令牌和规则应能指导 Flutter App、静态原型或后续其他端实现。不要写成 Android 专属、Web 专属或某个截图的复刻稿。

**Key characteristics:**
- Calendar-first ledger: 独立日历页是主结构，不是首页里的附属小组件。
- Workbench-first home: 首页回答“今天是否记完整、今天有哪些分段、本周期累计到哪里、接下来最常用动作是什么”。
- Numeric trust: 工时、出勤天数、加班时长、夜班次数和收入数字使用稳定、对齐的数字排版。
- Quiet warmth: 使用纸面、账本卡片和低饱和状态色，避免企业蓝白后台风。
- Private control: 备份、导出、恢复要显得安全、可控、可回退。

## Colors

The palette is built around warm paper surfaces and restrained ledger accents. Tokens are semantic; implementations should use the token names instead of copying arbitrary hex values into components.

### Surface
- **Paper** (`{colors.paper}` — #F8F1E7): App background. It gives the product a warm ledger feel and avoids cold enterprise dashboards.
- **Surface** (`{colors.surface}` — #FFFCF6): Main cards, forms, bottom navigation, and settings groups.
- **Surface Soft** (`{colors.surface-soft}` — #EFE2D1): Group bands, empty states, calendar background bands, and secondary panels.
- **Surface Raised** (`{colors.surface-raised}` — #FFF8EE): Slightly lifted cells or nested areas that need to stand out without strong shadows.
- **Hairline** (`{colors.hairline}` — #DFD1BF): Default 1px dividers and card borders.
- **Hairline Strong** (`{colors.hairline-strong}` — #CDBBA7): Selected/active borders when fill color would be too heavy.

### Text
- **Ink** (`{colors.ink}` — #17130F): Titles, primary text, large numbers, and decisive values.
- **Charcoal** (`{colors.charcoal}` — #273C35): Primary dark action, important labels, and night-shift identity.
- **Muted** (`{colors.muted}` — #6F665C): Helper text, date ranges, secondary metadata.
- **Stone** (`{colors.stone}` — #A99B8B): Disabled states, placeholders, and low-priority hints.

### Work Semantics
- **Work Amber** (`{colors.work-amber}` — #B8652F): Primary action, regular shift identity, and warm emphasis.
- **Work Amber Soft** (`{colors.work-amber-soft}` — #E9C29B): Regular-shift calendar tint and chip background.
- **Overtime Moss** (`{colors.overtime-moss}` — #2F765C): Overtime, positive completion, and earned-extra emphasis.
- **Overtime Moss Soft** (`{colors.overtime-moss-soft}` — #98C7AC): Overtime calendar tint and chip background.
- **Night Slate** (`{colors.night-slate}` — #273C35): Night-shift identity and the center add button.
- **Night Slate Soft** (`{colors.night-slate-soft}` — #8EA39A): Night-shift calendar tint.
- **Warning Copper** (`{colors.warning-copper}` — #8F4D18): Primary button backgrounds, unusually long shifts, missing fields, or user-checkable states such as “时长偏长”.
- **Error Brick** (`{colors.error-brick}` — #9D3D32): Delete, overwrite restore, and destructive confirmations.
- **Info Blue** (`{colors.info-blue}` — #5D7182): Export, backup, Nutstore/WebDAV helper states. This is a tool color, not the brand color.

### Calendar Tints
Calendar color must be low-saturation and readable. A day can combine indicators: base fill for the dominant type, small dots/bars for additional segments, and a note mark when remarks exist.

- Regular work: `{colors.work-amber-soft}`
- Overtime: `{colors.overtime-moss-soft}`
- Night shift: `{colors.night-slate-soft}`
- Rest/no record: `{colors.rest-tint}`
- Needs user check: `{colors.issue-tint}`

## Typography

Typography uses platform system fonts to keep implementation lightweight and native-feeling. The design does not require paid fonts or heavy font assets.

- **Display metrics** use `{typography.display-metric}` with tabular figures for total hours, attendance days, overtime hours, and important money values.
- **Headlines** use `{typography.headline-lg}` or `{typography.headline-md}` with tight but readable spacing.
- **Body copy** uses `{typography.body-md}` for forms, notes, settings, and record details.
- **Labels and chips** use `{typography.label-md}` / `{typography.caption}` for compact metadata.
- **Small numeric values** use `{typography.numeric-sm}` so daily calendar cells and tables align visually.

Numeric rules:
- Use tabular figures for hours, money, multipliers, and totals.
- Work hours default to one decimal place, for example `8.5h`.
- Money may be rounded or shown with two decimals according to settings, but the same screen must be consistent.
- Overtime multipliers should read as `1.5x`, not as a long formula.

## Layout

The layout is mobile-first but platform-neutral. The same hierarchy should survive Flutter, web prototype, and later tablet/desktop adaptations.

### Navigation Model
Bottom navigation has five visual positions:
1. 首页 Home
2. 日历 Calendar
3. Center `+` Add Record
4. 汇总 Summary
5. 设置 Settings

The center add button is an action, not a normal tab. It opens an add/edit sheet where the user can choose date, apply a shift template, copy an existing day, add multiple segments, attach notes, and add allowance/deduction details.

### Page Hierarchy
- **Home:** A daily workbench: today status, today segments, current-period progress, and the most common next actions. It should not contain the full monthly calendar and should not behave like an income-first dashboard.
- **Calendar:** Independent calendar page with two month-level reading modes: calendar grid and rectangular list. The grid shows monthly summary, day-level hours, overtime/night indicators, note marks, and selected-day details. The list shows the same month as vertical day rows for faster scanning. Year/month switching should happen through a compact picker sheet that can show 12-month distribution without turning year view into a heavy page.
- **Summary:** Period totals for month, year, pay period, week, and custom range. It is for checking totals and exporting CSV: attendance days, total hours, regular hours, overtime days/hours, night shifts, allowances/deductions, and final income estimate. Summary metrics must support drill-down lists, such as attendance dates, note-bearing records, overtime dates, and abnormal records.
- **Settings:** Shift templates, one pay-rule entry with hourly/daily/monthly choices in the edit sheet, overtime/night rules, pay cycle, CSV export, local backup/restore, and Nutstore WebDAV backup/restore.

### Spacing
Use an 8px rhythm with 4px only for micro-adjustments. Phone page margins start at `{spacing.page-margin}`. Cards use 16–24px internal padding. Touch targets must be at least `{spacing.touch-target}`.

Avoid dense data tables. Prefer ledger cards, compact chips, and small comparison rows. If a value risks overflowing, reduce hierarchy or wrap the label; do not let numeric text escape its card.

Interactive layout rules:
- Every visible tap target must be at least 44×44px, including month arrows, calendar days, settings actions, chips, and compact icon buttons.
- Clickable year/month titles, calendar days, summary metric cards, day rows, and drill-down rows should be implemented as buttons or controls with equivalent semantics.
- Keyboard/focus states must be visible. Use a warm focus ring, for example `2px solid {colors.warning-copper}` with a 2px offset.
- Calendar and color-coded summaries must not rely on color alone. Use labels, marks, or accessible names such as “5月13日，9小时，2段，有备注”.

## Elevation & Depth

Depth is warm and soft, closer to stacked paper than floating glass. The system should rely on tonal layering, borders, and spacing before using shadows.

- Main cards sit on `{colors.paper}` with `{colors.surface}` fill and a thin `{colors.hairline}` border.
- Raised panels may use a soft warm shadow such as `0 14px 32px rgba(93, 62, 30, 0.10)`.
- Bottom navigation and add sheets may use stronger but still diffused shadows because they float above content.
- Calendar cells should not cast individual shadows; use tint, dots, and selected outline instead.
- Avoid glassmorphism, neon glow, hard black shadows, or decorative gradients.

## Shapes

The shape language is generous and approachable, like rounded paper slips and ledger labels.

- Cards use `{rounded.lg}` to `{rounded.xl}`.
- Metric cards can use `{rounded.xl}` for a calm, premium feel.
- Inputs use `{rounded.md}` and must look tappable, not like spreadsheet cells.
- Buttons and chips use `{rounded.full}` when they are actions or filters.
- Calendar cells use `{rounded.sm}` so a full month still feels orderly.
- Destructive confirmation surfaces use the same rounded language; only the color changes to `{colors.error-brick}`.

Do not mix sharp enterprise-table corners with soft ledger cards on the same screen.

## Components

### App Shell
Use `{components.app-shell}` for all main surfaces. The shell should make the app feel private and calm. Header areas can be sparse; do not crowd them with enterprise-style filters.

### Metric Cards
Use `{components.metric-primary}` for the most important local context: on the home page this is usually today recorded hours; on the summary page it is usually current-period total hours or net hours. Income may be shown, but it should not dominate the home screen over work-time facts.

Metric cards must keep labels and numbers inside the container. Use shorter labels, line breaks, or a smaller numeric token before allowing overflow.

### Work Entry Cards
Use `{components.work-entry-card}` for one day segment or a grouped day. A record card should show:
- date or selected day context
- start/end time and rest duration
- net hours
- type: regular, overtime, night
- note indicator or brief note
- optional income/allowance/deduction as secondary data

For one day with multiple segments, stack real time-range rows inside the day detail rather than pretending it is one continuous shift or labeling them as morning/afternoon. Most days may have one segment, but the edge case must remain editable. Existing records, single segments, notes, allowances, and deductions must expose full create/read/update/delete paths.

Editing one day should use a “date + segment list” model:
- the sheet shows the date once;
- each segment row has start/end time, break, type, optional note, optional allowance/deduction, edit, and delete;
- “新增分段” adds another row;
- “删除本段” deletes one segment;
- “删除当天记录” deletes the whole day and must be visually distinct.

Deletion uses destructive styling and a second confirmation, but still speaks like a personal ledger action, not an approval workflow.

### Calendar Day Cells
Use `{components.calendar-day}` as the base. Apply work/overtime/night variants by dominant segment type and add tiny dots/bars for secondary segment types. A note mark should be visually distinct from overtime/night marks.

Month switching is required, but it should use a year/month picker sheet rather than forcing a heavy year page into the main navigation. Calendar must support both grid view and list view for the selected month. Selecting a month updates the grid, list, selected-day details, and summary context together.

### Buttons
Use `{components.button-primary}` for the one strongest action on a sheet or screen. Use `{components.button-secondary}` for export, cancel, and non-destructive utilities. Use `{components.button-danger}` only for destructive actions such as deleting a record or restoring over existing data. Delete actions must be visible from record edit/detail contexts, not hidden in settings.

### Center Add Button
Use `{components.center-add-button}` in the bottom navigation center. It opens the add record sheet. It should be prominent but not oversized enough to cover content or look like a floating ad.

### Inputs
Use `{components.text-input}` and `{components.text-input-focused}`. Time and date inputs should favor pickers, wheels, chips, or templates over repeated manual typing. Money inputs must show units such as `元/小时`, `元/天`, `元/月`, or `元/次`. Pay settings should appear as one `计薪规则` entry in Settings; the edit sheet exposes the mutually exclusive choices 按小时 / 按天 / 按月, then shows the relevant amount and effective-date fields. Daily pay must also expose whether the daily rate is counted by attendance day or by shift count. Overtime base hourly rate should be visible when needed so daily/monthly rules remain auditable.

### Chips
Use chips for work type, overtime, night shift, filters, and template quick choices. Chips should feel like ledger annotations, not backend status codes.

### Summary Drill-Down
Summary cards are entry points, not dead totals. Attendance days, note days, overtime days, night shifts, long-duration records, allowances, and deductions should open compact date/record lists so users can verify where each number comes from. Use consistent affordance: a summary card opens a filtered list, a drill-down row opens the day or record detail, and the edit action lives inside the detail/edit sheet. Avoid approval-like wording; this is a personal ledger.

### Backup and Export Surfaces
Backup surfaces use normal cards with `{colors.info-blue}` as a helper accent. Nutstore/WebDAV fields should feel understandable and safe: address, account, app password, last backup time, and restore confirmation. Backups may restore address, account, and remote path, but must not restore the app password; after restore, show a short “需重新授权” state.

## Do's and Don'ts

### Do
- Do make the app feel like a personal ledger, not a corporate attendance system.
- Do keep app-facing titles short and production-like, such as “今日记录”, “工时日历”, “工时汇总”, and “设置”.
- Do keep calendar, day records, and time totals more prominent than income estimates.
- Do support one day with multiple visible segments.
- Do show month switching through a compact year/month picker, selected-day details, grid/list calendar modes, and compact month summaries.
- Do make summary cards, calendar days, and day-list rows clearly tappable with consistent row behavior.
- Do distinguish “删除本段” from “删除当天记录”.
- Do keep peer options visually equal width when they are alternatives, such as 按小时 / 按天 / 按月 inside the pay-rule edit sheet.
- Do keep overtime, night shift, notes, allowances, and deductions visually scannable.
- Do use tabular figures for all totals and money-like values.
- Do make CSV export, local backup/restore, and Nutstore backup/restore feel safe and reversible.

### Don't
- Don't copy the structure or UI of reference screenshots directly; use them only as product-function reference.
- Don't use default blue-white Material/enterprise-dashboard styling as the primary identity.
- Don't introduce GPS, face recognition, approval, team management, widgets, notifications, PDF reports, or system calendar sync into the visual system.
- Don't put a full monthly calendar on the home page if it weakens the today-first hierarchy.
- Don't make income estimate the largest home-screen object by default; the home hero should be today status or current-period work progress.
- Don't put design rationale or explanatory prototype copy inside the real app UI, such as “首页不是菜单” or “日历和列表都能回看”.
- Don't let stats numbers overflow cards; shorten, wrap, or resize before overflow happens.
- Don't use approval-like app-facing states. Prefer personal ledger wording like “时长偏长” or “核对这天”.
- Don't make small `div` elements act like buttons without button semantics, focus states, and accessible labels.
- Don't create decorative gradients, badges, achievements, or game-like reward visuals.
