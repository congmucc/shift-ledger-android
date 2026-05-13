# Calendar Picker Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Use mature Flutter libraries and thin shared wrappers to improve calendar today semantics, picker UI, file saving, and large text-scale resilience.

**Architecture:** `table_calendar` owns the calendar grid mechanics; Flutter `CupertinoDatePicker` owns wheel-style date/time/day selection; `flutter_file_dialog` owns Android/iOS save dialogs. Project code keeps only business presentation models, shared picker wrappers, and UI density/accessibility rules.

**Tech Stack:** Flutter, table_calendar, CupertinoDatePicker, flutter_file_dialog, widget tests.

---

### Task 1: Dependencies and governance
- [x] Add `table_calendar` for calendar grid rendering.
- [x] Add `flutter_file_dialog` for Android/iOS system save dialogs based on ACTION_CREATE_DOCUMENT on Android.
- [x] Add project-level `AGENTS.md` requiring official/library-first implementation and large-font adaptation.

### Task 2: Tests first
- [ ] Add widget coverage for today navigation and marker visibility.
- [ ] Add large text-scale smoke coverage for calendar layout.
- [ ] Add service coverage for injected external file saver.

### Task 3: Shared wrappers
- [ ] Create reusable picker wrappers around `CupertinoDatePicker` for date, time, and month day.
- [ ] Create compact metric/card APIs for dense calendar/summary contexts.

### Task 4: Calendar UI
- [ ] Replace manual grid with `TableCalendar`.
- [ ] Add today navigation.
- [ ] Replace dominant-color ordering with non-exclusive markers for work/overtime/night/note.

### Task 5: Save/export
- [ ] Route CSV and JSON backup export through `flutter_file_dialog` in production.
- [ ] Keep app-scoped write path for injected test directories and private restore support.
- [ ] Improve cancellation/error copy.

### Task 6: Verify
- [ ] Run `dart format .`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
