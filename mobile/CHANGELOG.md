# Changelog

All notable changes to the OpenVine mobile app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added - Real End-to-End Upload and Publishing Tests (2025-10-14)

#### Tests
- **Added comprehensive E2E tests for video upload → thumbnail → Nostr publishing with REAL services** - Validates complete flow with no mocks
  - Tests use actual Blossom server at `https://blossom.divine.video`
  - Tests publish to real Nostr relays (`wss://relay3.openvine.co`, `wss://relay.damus.io`)
  - Generates real MP4 videos using ffmpeg for testing
  - Validates BUD-01 authentication (Nostr kind 24242 events)
  - Confirms thumbnail extraction and upload
  - Verifies NIP-71 kind 34236 event creation and broadcasting
  - Tests CDN accessibility and video streaming

#### Test Coverage
- Created `integration_test/upload_publish_real_e2e_test.dart`:
  - **Test 1**: Complete upload → publish flow validation
    - Generates 5-second test video with ffmpeg (640x480, blue color)
    - Uploads video and thumbnail to Blossom CDN
    - Creates signed Nostr event with video metadata
    - Publishes to multiple relays and verifies success
    - Validates upload state transitions (readyToPublish → published)
  - **Test 2**: CDN video retrieval verification
    - Confirms uploaded videos are immediately accessible
    - Validates HTTP 200 response and proper content-type headers
    - Tests video streaming compatibility

#### Technical Details
- Uses `IntegrationTestWidgetsFlutterBinding` for real network requests (not `TestWidgetsFlutterBinding`)
- Authenticates test users with generated Nostr keypairs via `AuthService.importFromHex()`
- Initializes NostrService with custom relay list for publishing
- Generates test videos dynamically with ffmpeg (no committed test files)
- Falls back to minimal MP4 if ffmpeg unavailable
- Disables macOS sandbox in `DebugProfile.entitlements` to allow ffmpeg execution
- Test timeout: 5 minutes (allows for real network operations)

#### Test Results
- ✅ All tests passing (2/2)
- ✅ Video upload to Blossom CDN working
- ✅ Thumbnail extraction and upload working
- ✅ Nostr event publishing to relays working
- ✅ CDN video retrieval working (HTTP 200)
- ✅ Complete state management verified

#### Production Readiness
- Upload → publish flow validated with real services
- BUD-01 authentication working correctly
- NIP-71 event format correct and accepted by relays
- CDN serving files with proper headers for video streaming
- No mocks - tests use actual production infrastructure

### Fixed - Tab Visibility Listener for Video Clearing (2025-10-13)

#### Bug Fixes
- **Added tab visibility listeners to clear active video when switching tabs** - Prevents video playback in background tabs
  - `MainScreen` now listens for tab changes and clears active video when navigating away from video feeds
  - Ensures videos stop playing when user switches to Profile, Camera, or Explore tabs
  - Uses `_currentTabIndex` tracking to detect tab navigation events
  - Calls `VideoOverlayManager.clearActiveVideo()` on tab switches away from video content

#### Technical Details
- Modified `lib/screens/main_screen.dart`:
  - Added tab visibility tracking in `_onTabSelected()` method
  - Detects navigation away from Home and Explore tabs (indices 0 and 2)
  - Clears active video controller to stop background playback
  - Logs tab changes for debugging video lifecycle issues

### Added - Phase 1 App Lifecycle Video Pause Tests (2025-10-13)

#### Tests
- **Added comprehensive app lifecycle video pause tests** - Validates video behavior during app state changes
  - Tests video pause/resume on app backgrounding and foregrounding
  - Validates proper WidgetsBindingObserver registration and cleanup
  - Ensures VideoOverlayManager responds correctly to lifecycle events
  - Confirms video state transitions through pause, resume, and inactive states

#### Technical Details
- Created `test/integration/app_lifecycle_video_pause_test.dart`:
  - Tests observer registration in VideoOverlayManager
  - Validates video pause when app enters background (AppLifecycleState.paused)
  - Confirms video resume when app returns to foreground (AppLifecycleState.resumed)
  - Tests cleanup on VideoOverlayManager disposal
  - Uses proper async/await patterns for lifecycle state changes

### Fixed - Video Playback During Camera Recording (2025-10-08)

#### Bug Fixes
- **Fixed videos playing in background during camera recording** - Videos now fully disposed when opening camera
  - `VideoStopNavigatorObserver` now detects camera screen navigation and disposes all video controllers
  - Previous behavior only cleared active video, allowing background playback to continue
  - Camera screen navigation now triggers `VideoOverlayManager.disposeAllControllers()`
  - Ensures complete cleanup of video state when entering camera mode

#### Technical Details
- Modified `lib/services/video_stop_navigator_observer.dart`:
  - Added import for `video_overlay_manager_provider.dart`
  - Lines 27-44: Added camera screen detection logic
  - Checks if route name contains "Camera" to identify camera navigation
  - Calls `disposeAllControllers()` for camera routes vs `clearActiveVideo()` for other routes
  - Logs differentiate between disposal actions for debugging

### Fixed - iOS Camera Permissions on Fresh App Launch (2025-10-08)

#### Bug Fixes
- **Fixed iOS camera permission detection on fresh app launch** - Permissions now correctly detected without requiring Settings visit
  - iOS `permission_handler` plugin has persistent caching bug that returns stale status across app launches
  - Solution: Bypass `permission_handler` entirely, attempt camera initialization directly
  - Native `AVCaptureDevice` checks real system permissions, not cached values
  - Works correctly for both returning from Settings AND fresh app launches

#### Root Cause
- `permission_handler` caches permission status in memory and persists it across app sessions
- Even after granting permissions in Settings, `Permission.camera.status` returns stale `false` value
- Calling `.request()` also returns cached status instead of checking actual system state
- Only way to get accurate status is to let native AVFoundation attempt initialization

#### Technical Details
- Modified `lib/screens/pure/universal_camera_screen_pure.dart`:
  - Lines 175-238: Updated `_performAsyncInitialization()` to bypass `permission_handler`
  - Attempts camera initialization first before checking cached permission status
  - If initialization succeeds → permissions already granted
  - If initialization fails with permission error → request permissions via dialog
  - After granting → retry initialization
  - Lines 84-135: Previously fixed `_recheckPermissions()` for Settings return flow

#### Manual Testing Protocol
- Fresh app launch with permissions already granted: Camera preview appears immediately
- Fresh app launch without permissions: Permission dialog appears, camera initializes after grant
- Returning from Settings after granting: Camera preview appears immediately (already fixed)
- No longer requires visiting Settings on every app launch

### Fixed - Thumbnail Generation on macOS (2025-10-08)

#### Bug Fixes
- **Fixed video thumbnail generation on macOS** - Hybrid approach ensures cross-platform compatibility
  - Primary strategy: `fc_native_video_thumbnail` plugin (fast, native performance)
  - Fallback strategy: FFmpeg (universal, works on ALL platforms)
  - macOS previously failed with `MissingPluginException` from plugin
  - Now successfully generates thumbnails via FFmpeg fallback

#### Implementation
- Modified `lib/services/video_thumbnail_service.dart`:
  - Lines 98-125: Try `fc_native_video_thumbnail` first
  - Lines 127-136: Fallback to FFmpeg on plugin failure
  - Lines 20-67: Added `_extractThumbnailWithFFmpeg()` method
  - FFmpeg command: Extract frame at 100ms, resize to 640x640, JPEG quality 2

#### Platform Support Matrix
| Platform | fc_native_video_thumbnail | FFmpeg | Result |
|----------|--------------------------|--------|--------|
| Android  | ✅ Works                 | ✅ Available | Uses plugin |
| iOS      | ✅ Works                 | ✅ Available | Uses plugin |
| macOS    | ❌ MissingPluginException | ✅ Works | Uses FFmpeg |
| Windows  | ✅ Should work           | ✅ Available | Uses plugin or FFmpeg |
| Linux    | ❓ Unknown              | ✅ Works | Uses FFmpeg |

#### Test Results
- Unit tests: 17/17 PASS (`test/services/video_thumbnail_service_test.dart`)
- Integration tests: 8/8 PASS (`test/services/video_event_publisher_embedded_thumbnail_test.dart`)
- E2E tests: 3/3 PASS (`test/integration/video_thumbnail_publish_e2e_test.dart`)

#### Documentation
- Created `THUMBNAIL_SOLUTION.md` with comprehensive implementation details
- Includes FFmpeg command reference, testing protocol, and future improvements

### Fixed - Home Feed Empty State (2025-10-04)

#### Bug Fixes
- **Fixed home feed showing empty state despite following users with videos** - Resolved provider disposal race condition
  - Changed `socialProvider` from `keepAlive: false` to `keepAlive: true`
  - Provider was being disposed during async initialization (fetching contact list and reactions)
  - Home feed now correctly receives following list (14 users) and loads their videos (33 videos loaded)
  - Social state (following list, likes, reposts) now persists in memory as app-wide state

#### Root Cause
- `socialProvider` used `@Riverpod(keepAlive: false)` which caused auto-disposal when not actively watched
- `homeFeedProvider` reads it with `ref.read()` which doesn't keep the provider alive
- During async operations (`fetchCurrentUserFollowList()`, `fetchAllUserReactions()`), provider would dispose
- Result: Following list never populated, home feed incorrectly showed "Your Feed, Your Choice" empty state

#### Technical Details
- Modified `lib/providers/social_providers.dart`:
  - Line 20: Changed `@Riverpod(keepAlive: false)` to `@Riverpod(keepAlive: true)`
  - Updated comment to reflect disposal prevention and state caching
- Regenerated `lib/providers/social_providers.g.dart`:
  - Line 29: `isAutoDispose: false` (previously `true`)
- Provider still receives updates via state mutations and `ref.invalidate()`
- `keepAlive: true` only prevents disposal, doesn't affect reactivity

### Fixed - Video Controller Memory Management (2025-10-03)

#### Bug Fixes
- **Fixed video controller disposal when entering camera** - Improved memory management for camera transitions
  - Camera screen now force-disposes all video controllers on entry (prevents ghost videos)
  - Additional disposal before navigating to profile after recording
  - Ensures no stale video controllers exist during tab switches
  - Prevents background video playback when camera is active

#### Technical Details
- Modified `lib/screens/pure/universal_camera_screen_pure.dart`:
  - Lines 44-54: Force dispose all controllers in initState
  - Lines 807-809: Additional disposal before profile navigation
  - Improved cleanup prevents IndexedStack widget lifecycle issues

### Changed - iOS Build Process (2025-10-03)

#### Improvements
- **Auto-increment build number for release builds** - Ensures App Store compliance
  - Release builds (`./build_ios.sh release`) now automatically increment build number
  - Debug builds only increment when `--increment` flag is explicitly passed
  - Updated usage documentation to reflect new behavior

#### Technical Details
- Modified `build_ios.sh`:
  - Lines 14-22: Conditional auto-increment logic for release vs debug
  - Lines 136-143: Updated usage documentation

### Fixed - Home Feed Video Loading (2025-01-30)

#### Bug Fixes
- **Fixed home feed only loading 1 video** - Resolved race condition in video batch loading
  - Home feed provider now waits for complete video batch from relay instead of completing on first video
  - Implemented stability-based waiting: monitors video count and completes when stable for 300ms
  - Added 3-second maximum timeout as safety for slow connections
  - Uses proper event-driven pattern with Completer and ChangeNotifier listeners
- **Fixed home feed auto-refresh behavior**
  - Automatically refreshes when contact list changes (follow/unfollow)
  - Added 10-minute auto-refresh timer for background updates
  - Maintains proper keepAlive behavior to prevent unnecessary rebuilds
- **Fixed video swiping gesture conflicts**
  - Changed `enableLifecycleManagement` to `false` in home feed to match explore feed
  - Added missing `controller` parameter to VideoPageView for proper state management
- **Code quality improvements**
  - Removed unused imports and fields in home_feed_provider.dart
  - Fixed syntax error (trailing comma) in video_feed_screen.dart

#### Technical Details
- Modified `lib/providers/home_feed_provider.dart`:
  - Lines 126-163: Stability-based video loading with proper cleanup
  - Lines 80-93: Reactive listening for contact list changes
  - Lines 69-78: 10-minute auto-refresh timer
- Modified `lib/screens/video_feed_screen.dart`:
  - Added `controller: _pageController` to VideoPageView
  - Changed `enableLifecycleManagement: false`
- Enhanced debug logging in `lib/widgets/video_page_view.dart`

### Changed - Riverpod 3 Migration (2025-01-30)

#### Breaking Changes
- **Upgraded to Riverpod 3.0.0** - Complete migration from Riverpod 2.x
- **Upgraded to Freezed 3.2.3** - Added required `sealed` keyword to all state classes
- **Updated Firebase dependencies** - firebase_core ^4.1.1, firebase_crashlytics ^5.0.2, firebase_analytics ^12.0.2
- **Updated Flutter Lints** - ^6.0.0 for latest linting rules

#### Fixed
- All freezed state classes now use `sealed` keyword required by Freezed 3.x
  - `AnalyticsState`, `SocialState`, `UserProfileState`, `VideoFeedState`
  - `VideoMetadata`, `VideoContent`, `SingleVideoState`, `VideoContentBufferState`, `CurationState`
- Fixed provider access patterns for Riverpod 3
  - Changed `videoOverlayManagerProvider.notifier` to `videoOverlayManagerProvider`
  - Updated `searchStateProvider` references in tests
- Fixed Hive imports to use `hive_ce` package
- Updated UserProfile constructor calls with required parameters (`rawData`, `createdAt`, `eventId`)
- Regenerated all `.g.dart` and `.freezed.dart` files with Riverpod 3 generators

#### Dependencies Updated
- firebase_core: ^3.15.1 → ^4.1.1
- firebase_crashlytics: ^4.1.2 → ^5.0.2
- firebase_analytics: ^11.3.5 → ^12.0.2
- flutter_launcher_icons: ^0.13.1 → ^0.14.4
- flutter_lints: ^5.0.0 → ^6.0.0
- Plus 44 transitive dependency updates

#### Production Code Status
- ✅ **0 compilation errors** in production code
- ✅ App compiles and runs successfully with Riverpod 3
- ✅ All state management patterns updated
- ✅ All providers properly generated

#### Test Status
- 370 test errors remaining (down from 408)
  - 341 in TODO test files (intentionally incomplete)
  - 27 in visual regression tests (require golden_toolkit)
  - ~2 in core integration/unit tests
- Production code unaffected by test errors

#### Technical Details
- Dart SDK constraint updated: `>=3.8.0 <4.0.0` (required for json_serializable 6.8.0)
- Legacy Riverpod 2 providers maintained compatibility via `package:flutter_riverpod/legacy.dart`
- Build runner successfully generates 120+ files
- All Riverpod 3 code generation working correctly
