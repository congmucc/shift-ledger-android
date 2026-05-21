# UI Handoff — Compact Ledger Final Baseline

This note supersedes the old iOS-neutral handoff wording. The current source of truth is now:

1. `DESIGN.md` — final product design baseline.
2. `.design-preview/compact-ledger-ui.html` — approved HTML visual mockup.
3. Flutter implementation under `lib/src/ui/` — current app UI.

`PROTOTYPE.html` is obsolete and should not be recreated or used as a reference.

## Current direction

- Compact mobile utility UI.
- White / soft gray surface system.
- Blue = normal work / primary, green = overtime, indigo = night, orange = note, red = abnormal or destructive.
- Main pages use short titles: `今日`, `日历`, `汇总`, `设置`.
- Android/mobile is the target; web preview is only for inspection.

## Required verification

Before calling UI work complete, run:

```bash
flutter analyze
flutter test --reporter compact
```

For visual inspection, compare:

```bash
python3 -m http.server 4312 --directory .design-preview
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 4300
```
