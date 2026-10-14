# Decisions

Every answer Ryan has given, so no question gets asked twice. Newest entries go at the bottom.

## Workspace

### Where does the spec come from?
- **Options:** Ryan adds the file / agent searches and fetches it / Ryan supplies a URL
- **Decision:** Ryan added `intercal.pdf`. It now lives at `spec/intercal.pdf`.
- **Date:** 2026-10-14

### What does workspace setup include?
- **Options:** plan + docs skeleton / project agent instructions (AGENTS.md) / Dart Dockerfile / Dart package scaffold
- **Decision:** plan + docs skeleton, Dart Dockerfile, Dart package scaffold. No project AGENTS.md.
- **Date:** 2026-10-14

### Which branch does setup work go on?
- **Options:** stay on `mega` / new branch off `main` / leave uncommitted
- **Decision:** stay on `mega`
- **Date:** 2026-10-14

### What is "INTERCAL on Interstates"?
- **Options:** Ryan explains / park it / look it up
- **Decision:** look it up. It's a web framework built on C-INTERCAL. What "adding" it means is still open (see `docs/PLAN.md`).
- **Date:** 2026-10-14

### Dart package name
- **Options:** `ciwapa` / `intercal`
- **Decision:** `ciwapa`
- **Date:** 2026-10-14

### Lint setup
- **Options:** `package:lints/recommended` / `very_good_analysis` / no lint package
- **Decision:** `package:lints/recommended`
- **Date:** 2026-10-14

### Commit `pubspec.lock`?
- **Options:** commit it / keep it ignored
- **Decision:** commit it. Removed it from `.gitignore`.
- **Date:** 2026-10-14

### Plain-text copy of the spec?
- **Options:** extract with pdftotext in Docker / keep the PDF only
- **Decision:** PDF only
- **Date:** 2026-10-14
