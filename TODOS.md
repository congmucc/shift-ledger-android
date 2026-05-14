# Shift Ledger TODOs

## Design closure backlog

- [ ] Verify three real Android walkthroughs before calling the design loop complete: record today's shift, find overtime/night-shift day, and export or back up data.
  - Why: these are the trust paths for a personal work ledger; text-level widget tests do not prove the app feels safe on device.
  - Depends on: Android emulator or physical-device QA pass.

- [x] Add an undo or recent-deleted recovery path after deleting a full day.
  - Why: hiding the destructive action reduces mis-taps, but recovery is what protects wage evidence if deletion still happens.
  - Done: whole-day delete now creates a recent-deleted restore point, shows snackbar undo, and exposes a Settings recovery sheet.

- [x] Replace WebDAV copy-only status with a small backup status model: unconnected, connected, auto-backup on, needs reauthorization, latest failure.
  - Why: backup confidence depends on knowing the current state, not only opening the configuration sheet.
  - Done: Settings and the WebDAV sheet now derive visible status from WebDAV config plus auto-backup status fields.

- [x] Re-evaluate whether Home needs a low-emphasis “more actions” path for export, templates, or non-today entry.
  - Why: the first screen should stay quiet, but ledger users may still need discoverable secondary actions.
  - Done: Home keeps only three primary chips and adds a low-emphasis “更多” bottom sheet for export, templates/settings, and non-today entry.
