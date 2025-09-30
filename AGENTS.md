# Repository Guidelines

## Project Structure & Module Organization
- `mobile/`: Flutter app — source in `lib/`, tests in `test/` and `integration_test/`, assets in `assets/`.
- `backend/`: Cloudflare Workers (TypeScript) — source in `src/`, tests in `test/`, config in `wrangler.jsonc` and `.wrangler/`.
- `nostr_sdk/`: Dart package — source in `lib/`, tests in `test/`; also `docs/`, `website/`, `crawler/`.

## Build, Test, and Development Commands
- Mobile: `cd mobile && flutter pub get && flutter run` (launch), `flutter test` (unit/widget), `flutter analyze` (lints), `dart format --set-exit-if-changed .` (format), `./build_native.sh ios|macos [debug|release]`.
- Backend: `cd backend && npm install && npm run dev` (Wrangler dev), `npm test` (Vitest), `npm run deploy` (deploy worker), `npm run cf-typegen` (CF types), `./flush-analytics-simple.sh true|false` (preview/flush KV).

## Coding Style & Naming Conventions
- Dart/Flutter: 2-space indent; files `snake_case.dart`; classes/widgets `PascalCase`; members `camelCase`.
- TypeScript: Prettier per `.prettierrc`/`.editorconfig` (tabs, single quotes, semicolons, width 140). Files `kebab-case.ts`; tests `*.test.ts|*.spec.ts` under `backend/test/`.
- Keep files ≈200 lines and functions ≈30 lines. Never use `Future.delayed` in `mobile/lib/`.

## Testing Guidelines
- Mobile: `cd mobile && flutter test`; target ≥80% coverage (see `mobile/coverage_config.yaml`). Co-locate tests as `*_test.dart`.
- Backend: `cd backend && npm test` (Vitest in workers pool). Place tests under `backend/test/` with descriptive names.

## Commit & Pull Request Guidelines
- Commits: Conventional Commits (e.g., `feat:`, `fix:`, `docs:`). Scope when meaningful.
- PRs: clear description, linked issues, tests for new logic, screenshots/recordings for UI changes.
- Pre-flight: `flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test`, `npm test` (backend) pass locally.

## Agent-Specific Instructions
- Embedded Nostr Relay: use `ws://localhost:7447`. Do not connect to external relays directly; use `addExternalRelay()` (see `mobile/docs/NOSTR_RELAY_ARCHITECTURE.md`).
- Async: avoid arbitrary sleeps; prefer callbacks, `Completer`, streams, readiness signals.
- Quality gate: after any Dart change, run `flutter analyze` and fix findings.
- Security/Config: store secrets outside VCS; worker config in `backend/wrangler.jsonc`. Use `npm run cf-typegen` after bindings change.
