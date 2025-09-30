# OpenVine Video Playback Cleanup & TDD Plan

## Goals
- Remove single-controller architecture completely and all references.
- Adopt a single, consistent per-item controller architecture using Riverpod Families.
- Eliminate duplicate classes/functions that implement similar responsibilities.
- Enforce visibility-based lifecycle so only visible videos play and resources are reclaimed.
- Drive changes via TDD to prevent regressions and ensure correctness.

## Architecture Decision (ADR)
- Keep: `individual_video_providers.dart` family (`individualVideoController`) for per-item `VideoPlayerController` with `autoDispose`.
- Keep: `VideoVisibilityManager` (centralized visibility + auto-play decisions), via `app_providers.dart`.
- Remove: Single-controller service + unified widget (global controller) and its providers.
- Remove: Consolidated per-item controller/widget duplicates that overlap with the Riverpod Family approach.

Rationale: This preserves smooth scrolling and state, avoids global switching delays, and aligns with Riverpod-first design.

## Removal Scope (Single-Controller + Duplicates)
Delete the following (and their references/imports):
- `mobile/lib/widgets/unified_video_player_widget.dart` — DONE
- `mobile/lib/services/single_video_controller_service.dart` — DONE
- `mobile/lib/providers/single_video_providers.dart` — DONE
- `mobile/lib/providers/single_video_providers.g.dart` — DONE
- `mobile/lib/providers/single_video_providers.freezed.dart` — DONE

Also remove per-item duplicates in favor of the Riverpod Family:
- `mobile/lib/services/video_playback_controller.dart` — DONE
- `mobile/lib/widgets/video_playback_widget.dart` — DONE

And controller-caching anti-pattern:
- `mobile/lib/services/lazy_video_loading_service.dart` — DONE

Pending cleanup (conflicting helpers to retire or rewire to individual providers):
- none (video_playback_providers removed)

Notes:
- If any consumer remains after refactor, temporarily guard deletions behind the TDD refactor until all usages are replaced.

## Provider Unification (No Duplicates)
- Canonical active video: `activeVideoProvider` in `individual_video_providers.dart`.
- Canonical check: `isVideoActiveProvider(String videoId)` in `individual_video_providers.dart`.
- Remove/rename duplicates with same intent (e.g., `isVideoActive` in other files).
- Retire `video_playback_providers.dart` helpers that conflict (current video, active checks) or rewire them to defer to the canonical active/visibility providers.

## Refactor Targets
- `mobile/lib/widgets/video_feed_item.dart`
  - Remove usage of `UnifiedVideoPlayerWidget`.
  - Render a `VideoPlayer` using the controller from `individualVideoControllerProvider(params)`.
  - Use `VisibilityDetector` + `VideoVisibilityManager` and `activeVideoProvider` to control play/pause.
  - Ensure tap toggles play/pause only on its own controller; never create controllers for inactive items.

- `mobile/lib/widgets/pure/video_feed_screen.dart`
  - Keep `PageView` scroll; on page change update active video id and visible set.
  - Prewarm only neighbor items (±1) by reading their providers with `ref.keepAlive()` grace, do not exceed 3–5 concurrent controllers.

- `mobile/lib/widgets/video_frame_thumbnail.dart`
  - Replace `VideoPlayerController`-based thumbnails with image thumbnails (server-provided preferred). If not available, use a non-player extraction approach (e.g., `video_thumbnail` package) under a service; do not spin controllers for thumbnails.

## TDD Plan
Add tests first, make them fail, then implement.

1) Providers (unit tests)
- Active video: when `setActiveVideo(idA)` is called, `isVideoActive(idA)` is true and others false.
- Disposal: providers for scrolled-away items are disposed (`ref.onDispose` invoked). Use a harness to simulate visibility changes and expect disposal.
- Concurrency cap: at most N controllers alive (configurable; target ≤5) given a visible index and neighbors. Verify by tracking created/disposed instances through a test shim.

2) Widgets (widget tests)
- Feed item plays when visible and active; pauses when scrolled off or when another item becomes active.
- Only one video plays at a time while two items are partially visible (enforce single active via `activeVideoProvider`).
- Tap toggles play/pause for active item; tapping an inactive item makes it active and starts playback if initialized.

3) Regression tests (integration-lite/widget)
- No background playback: when navigating away or changing active, previous controllers are paused and disposed.
- No black frames during quick scrolls: inactive items show placeholder/thumbnail without creating controllers.

Test utilities:
- Mock/fake `VideoPlayerController` using platform interface fakes or wrap controller creation behind a simple factory we can stub in tests.
- Visibility simulation: drive `VisibilityDetector` callbacks in tests using widget tester pumps and size/offset manipulations.

## Implementation Steps
1. Add provider + widget tests (failing initially) under `mobile/test/`.
2. Refactor `video_feed_item.dart` to use only `individualVideoControllerProvider` + `activeVideoProvider` + `VideoVisibilityManager`. (completed)
3. Remove unified single-controller code and references (files listed above). (completed)
4. Unify/rename or delete duplicate providers and helpers to avoid collisions. (completed; legacy `video_playback_providers*` removed)
5. Replace thumbnail strategy to avoid `VideoPlayerController` usage. (completed: removed VideoFrameThumbnail usage and file)
6. Cap concurrent controllers (±1 neighbors) with short keep-alive grace to avoid thrash. (implemented via prewarm manager; tune as needed)
7. Verify and fix analyzer warnings. (completed; analyzer clean)
8. Green tests; iterate to resolve any platform-specific flakiness. (in progress)
9. Remove legacy tests tied to deleted single-controller architecture. (completed)
9. Remove legacy tests tied to deleted single-controller architecture. (completed)

## Commands / Checks
- Analyze: `cd mobile && flutter analyze`
- Tests: `cd mobile && flutter test`
- Format: `cd mobile && dart format --set-exit-if-changed .`
- Codegen (if needed post-removals): `cd mobile && flutter pub run build_runner build --delete-conflicting-outputs`

## Risks & Mitigations
- iOS main-thread controller creation: keep main-thread creation in controller factory; avoid any background isolates for controller instantiation.
- Memory spikes: enforce concurrency caps and avoid thumbnail controllers.
- Race conditions on quick scroll: debounce active video updates, prefer visibility ≥0.5 threshold and short keep-alive.

## Definition of Done
- Single-controller code fully removed; no references remain; app builds. (code removed; references updated in `main.dart` and `video_feed_screen.dart`)
- No duplicated providers or functions for “active video” or visibility decisions. (retire `video_playback_providers*` or bridge to `individual_video_providers`)
- Only one active/playing video at any time; controllers are disposed for off-screen items.
- All new tests pass; analyzer clean.

## Progress
- [x] Create initial provider unit tests: ActiveVideoNotifier and VideoVisibilityManager (`mobile/test/active_video_notifier_test.dart`, `mobile/test/video_visibility_manager_test.dart`).
- [x] Per-item architecture in feed: `video_feed_item.dart` uses `individualVideoControllerProvider` + `activeVideoProvider`.
- [x] Removed single-controller code and updated references in app (`main.dart`, `video_feed_screen.dart`).
- [x] Add widget tests for single-active behavior and prewarm cap (`mobile/test/widgets/single_active_video_behavior_test.dart`, `mobile/test/unit/prewarm_manager_test.dart`).
- [x] Retire or rewire `video_playback_providers*` to individual providers (removed and consumers updated).
- [x] Replace `VideoFrameThumbnail` to avoid `VideoPlayerController` usage for thumbnails (fallback to placeholder; use network thumbnails/blurhash when available).
- [x] Cap concurrent controllers (±1 neighbors) with keep-alive grace (prewarm manager + keepAlive scheduling).
- [x] Analyze and fix lints (analyzer clean); ensure tests are green (running).
- [x] Remove legacy tests tied to deleted single-controller architecture (integration/services/widgets referring to single controller).

## Next Steps
- Tests: add high-value widget tests
  - PageView behavior: on page change, sets active video; only one active at a time.
  - Visibility threshold: integrate `VideoVisibilityManager` in `VideoFeedItem` and verify play/pause decisions respect thresholds and debounce.
  - Prewarm behavior: neighbors (±1) are prewarmed; controllers beyond cap are disposed after grace.
  - Lifecycle: when app/background or navigation away occurs, `activeVideoProvider` clears and controllers dispose.
- Pure feed unification: update `mobile/lib/widgets/pure/video_feed_screen.dart` to also prewarm neighbors using `prewarmManagerProvider` for consistency.
- Configurability: expose prewarm cap and grace via a small config/provider for easier tuning and test control.
- Instrumentation: add optional debug counters/logging for current active controllers to aid profiling during scroll tests.
- Documentation: remove or update any remaining docs referencing the single-controller or unified widget; add a short “Per-item Playback” note describing the family provider + visibility flow.
- CI hygiene: ensure `build_runner` codegen stays clean where used and add a format check gate if not present.
- [x] Remove legacy tests tied to deleted single-controller architecture (integration/services/widgets referring to single controller).
