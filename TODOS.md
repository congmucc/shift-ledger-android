# Shift Ledger TODOs

## Release readiness

- [ ] Verify three real Android walkthroughs before calling the design loop fully device-proven:
  - record today's shift;
  - find an overtime/night-shift day from the calendar;
  - export or back up data.
  - Why: widget tests and Web preview prove structure and regressions, but final Android confidence still needs one emulator or physical-device pass.

## Completed product decisions

- [x] Whole-day delete has an undo/recent-deleted recovery path.
  - Done: deleting a full day creates a recent-deleted restore point, shows snackbar undo, and exposes a Settings recovery sheet.

- [x] WebDAV status is modeled as unconnected, connected, auto-backup on, needs reauthorization, latest failure.
  - Done: Settings and the WebDAV sheet derive visible status from WebDAV config plus auto-backup status fields.

- [x] Home keeps only the three primary quick actions.
  - Done: Home exposes `补今天 / 查日历 / 看汇总`; export, templates, backups, and rules stay in their owning pages.

- [x] Compact UI palette replaced the old warm-paper prototype palette.
  - Done: `DESIGN.md`, `.design-preview/compact-ledger-ui.html`, Flutter theme, and widget tests now use the compact color semantics.

- [x] Calendar header action is text-labeled.
  - Done: the calendar header uses `补一段` with a stable key instead of an icon-only `+`.
