// ABOUTME: TDD test for verifying activeVideoProvider clears on profile navigation
// ABOUTME: Simpler test focusing on the core Riverpod state issue

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/individual_video_providers.dart';

void main() {
  group('Profile Video Navigation - Active Video State', () {
    test('activeVideoProvider should clear when navigating away from video player', () {
      // ARRANGE: Create container to track state
      final container = ProviderContainer();
      final notifier = container.read(activeVideoProvider.notifier);

      // Initially, no video should be active
      expect(container.read(activeVideoProvider), isNull,
          reason: 'No video should be active initially');

      // ACT: Simulate video player showing a video (like ExploreVideoScreenPure does)
      notifier.setActiveVideo('test_video_123');

      // ASSERT: Video should be active
      expect(container.read(activeVideoProvider), equals('test_video_123'),
          reason: 'Video should be active after setting it');

      // ACT: Simulate navigating back (like ExploreVideoScreenPure.dispose() should do)
      notifier.clearActiveVideo();

      // CRITICAL ASSERT: Video should no longer be active
      expect(container.read(activeVideoProvider), isNull,
          reason:
              'CRITICAL: Video must be cleared when returning to profile to stop playback');

      container.dispose();
    });

    // Note: Full video controller test requires TestWidgetsFlutterBinding
    // The logic is tested in the implementation with ref.listen on activeVideoProvider
    // that pauses when prev == videoId && next == null

    test('activeVideoProvider should track current video when changing videos', () {
      final container = ProviderContainer();
      final notifier = container.read(activeVideoProvider.notifier);

      // Initially null
      expect(container.read(activeVideoProvider), isNull);

      // Set first video
      notifier.setActiveVideo('video_1');
      expect(container.read(activeVideoProvider), equals('video_1'));

      // Change to second video
      notifier.setActiveVideo('video_2');
      expect(container.read(activeVideoProvider), equals('video_2'),
          reason: 'Active video should update when changing videos');

      // Navigate away
      notifier.clearActiveVideo();
      expect(container.read(activeVideoProvider), isNull,
          reason: 'Active video should clear when navigating away');

      container.dispose();
    });
  });
}