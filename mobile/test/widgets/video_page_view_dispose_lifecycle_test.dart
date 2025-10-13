// ABOUTME: Tests for VideoPageView dispose lifecycle to ensure clean shutdown
// ABOUTME: Verifies that dispose() doesn't access ref after widget unmount

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/widgets/video_page_view.dart';

void main() {
  group('VideoPageView Dispose Lifecycle', () {
    testWidgets('should cleanly dispose without ref access errors when navigating away',
        (WidgetTester tester) async {
      // Arrange: Create a test video
      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: 'test-video-1',
        pubkey: 'test-pubkey',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
      );

      // Build widget with ProviderScope
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: [testVideo],
                enableLifecycleManagement: true,
              ),
            ),
          ),
        ),
      );

      // Let the widget initialize completely
      await tester.pumpAndSettle();

      // Act: Navigate away to trigger dispose
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Navigated away')),
            ),
          ),
        ),
      );

      // Let dispose complete
      await tester.pumpAndSettle();

      // Assert: Test passes if no exception was thrown during dispose
      // The old implementation would throw:
      // "Bad state: Using 'ref' when a widget is about to or has been unmounted is unsafe"
    });

    testWidgets('should clear active video when disposed',
        (WidgetTester tester) async {
      // Arrange
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: 'test-video-2',
        pubkey: 'test-pubkey',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
      );

      // Build widget
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPageView(
                videos: [testVideo],
                enableLifecycleManagement: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify active video is set
      final activeVideoBeforeDispose = container.read(activeVideoProvider);
      expect(activeVideoBeforeDispose.currentVideoId, equals('test-video-2'));

      // Act: Dispose by navigating away
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Navigated away')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Active video should be cleared
      final activeVideoAfterDispose = container.read(activeVideoProvider);
      expect(activeVideoAfterDispose.currentVideoId, isNull);
    });

    testWidgets('should handle multiple rapid navigation cycles without errors',
        (WidgetTester tester) async {
      // Arrange
      final now = DateTime.now();
      final testVideo = VideoEvent(
        id: 'test-video-3',
        pubkey: 'test-pubkey',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: now,
        videoUrl: 'https://example.com/video.mp4',
      );

      // Act: Rapidly mount and unmount the widget
      for (int i = 0; i < 5; i++) {
        // Mount
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: VideoPageView(
                  videos: [testVideo],
                  enableLifecycleManagement: true,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Unmount
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(child: Text('Away')),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      // Assert: Should complete without throwing exceptions
      await tester.pumpAndSettle();
    });
  });
}
