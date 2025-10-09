// ABOUTME: Tests that videos are properly paused when app is backgrounded or locked
// ABOUTME: Ensures proper lifecycle management to prevent battery drain from background playback

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/widgets/app_lifecycle_handler.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  setUp(() {
    // Tests run with default logging - no setup needed
  });

  group('App Lifecycle Video Pause Tests', () {
    testWidgets('App going to background clears active video', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Setup: Create a test video and set it as active
      final testVideoId = 'test-video-123';
      container.read(activeVideoProvider.notifier).setActiveVideo(testVideoId);

      // Verify setup
      expect(
        container.read(activeVideoProvider).currentVideoId,
        equals(testVideoId),
      );

      // Mount app lifecycle handler
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AppLifecycleHandler(
                child: Text('Test'),
              ),
            ),
          ),
        ),
      );

      // Action: Simulate app going to background
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Assert: Active video should be cleared
      expect(
        container.read(activeVideoProvider).currentVideoId,
        isNull,
        reason: 'Active video should be cleared when app is backgrounded',
      );

      // Clean up pending timers from BackgroundActivityManager
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('App going to inactive state clears active video', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testVideoId = 'test-video-456';
      container.read(activeVideoProvider.notifier).setActiveVideo(testVideoId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AppLifecycleHandler(
                child: Text('Test'),
              ),
            ),
          ),
        ),
      );

      // Action: Simulate app going to inactive (e.g., system dialog appears)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Assert: Active video should be cleared
      expect(
        container.read(activeVideoProvider).currentVideoId,
        isNull,
        reason: 'Active video should be cleared when app becomes inactive',
      );
    });

    testWidgets('App going to hidden state clears active video', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testVideoId = 'test-video-789';
      container.read(activeVideoProvider.notifier).setActiveVideo(testVideoId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AppLifecycleHandler(
                child: Text('Test'),
              ),
            ),
          ),
        ),
      );

      // Action: Simulate app going to hidden (iOS-specific state)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();

      // Assert: Active video should be cleared
      expect(
        container.read(activeVideoProvider).currentVideoId,
        isNull,
        reason: 'Active video should be cleared when app is hidden',
      );
    });

    testWidgets('App resuming does not auto-set active video', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testVideoId = 'test-video-resume';

      // Setup: Set active video, then background app
      container.read(activeVideoProvider.notifier).setActiveVideo(testVideoId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AppLifecycleHandler(
                child: Text('Test'),
              ),
            ),
          ),
        ),
      );

      // Background the app
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Verify active video was cleared
      expect(container.read(activeVideoProvider).currentVideoId, isNull);

      // Action: Resume app
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // Assert: Active video should still be null (not auto-resumed)
      expect(
        container.read(activeVideoProvider).currentVideoId,
        isNull,
        reason: 'Active video should not be automatically set when app resumes',
      );
    });

    testWidgets('Multiple lifecycle changes maintain cleared state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testVideoId = 'test-video-multiple';
      container.read(activeVideoProvider.notifier).setActiveVideo(testVideoId);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AppLifecycleHandler(
                child: Text('Test'),
              ),
            ),
          ),
        ),
      );

      // Cycle through multiple lifecycle states
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(container.read(activeVideoProvider).currentVideoId, isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(container.read(activeVideoProvider).currentVideoId, isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(container.read(activeVideoProvider).currentVideoId, isNull);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(container.read(activeVideoProvider).currentVideoId, isNull);

      // Clean up pending timers
      await tester.pump(const Duration(seconds: 31));
    });
  });
}
