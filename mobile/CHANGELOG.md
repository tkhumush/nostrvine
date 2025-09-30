# Changelog

All notable changes to the OpenVine mobile app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
