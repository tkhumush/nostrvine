// ABOUTME: TDD test for video lifecycle during tab switches
// ABOUTME: Ensures videos are paused and disposed when tabs become inactive

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';

void main() {
  group('Video Tab Switch Lifecycle', () {
    testWidgets('MUST clear active video when switching away from video tabs',
        (WidgetTester tester) async {
      // GIVEN: A video tab is active with a video playing
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set tab 0 (home feed) as active
      container.read(tabVisibilityProvider.notifier).setActiveTab(0);

      // Set an active video
      container.read(activeVideoProvider.notifier).setActiveVideo('test-video-1');

      // Verify video is active
      final initialActive = container.read(activeVideoProvider);
      expect(initialActive.currentVideoId, equals('test-video-1'));

      // WHEN: User switches to a non-video tab (activity tab = index 1)
      container.read(tabVisibilityProvider.notifier).setActiveTab(1);

      // Pump all pending microtasks and timers
      await tester.pumpAndSettle();

      // THEN: Active video MUST be cleared to prevent background playback
      final afterSwitch = container.read(activeVideoProvider);
      expect(
        afterSwitch.currentVideoId,
        isNull,
        reason: 'Active video must be cleared when switching away from video tab',
      );
    });

    testWidgets('MUST clear active video when switching from explore to other tabs',
        (WidgetTester tester) async {
      // GIVEN: Explore tab is active with a video playing
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set tab 2 (explore) as active
      container.read(tabVisibilityProvider.notifier).setActiveTab(2);

      // Set an active video
      container.read(activeVideoProvider.notifier).setActiveVideo('test-video-2');

      // Verify video is active
      final initialActive = container.read(activeVideoProvider);
      expect(initialActive.currentVideoId, equals('test-video-2'));

      // WHEN: User switches to activity tab
      container.read(tabVisibilityProvider.notifier).setActiveTab(1);

      // Pump all pending microtasks and timers
      await tester.pumpAndSettle();

      // THEN: Active video MUST be cleared
      final afterSwitch = container.read(activeVideoProvider);
      expect(
        afterSwitch.currentVideoId,
        isNull,
        reason: 'Active video must be cleared when leaving explore tab',
      );
    });

    testWidgets('MUST allow video playback when switching between video tabs',
        (WidgetTester tester) async {
      // GIVEN: Home feed is active with a video
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tabVisibilityProvider.notifier).setActiveTab(0);
      container.read(activeVideoProvider.notifier).setActiveVideo('home-video');

      // WHEN: User switches to explore tab (another video tab)
      container.read(tabVisibilityProvider.notifier).setActiveTab(2);

      // Pump all pending microtasks and timers
      await tester.pumpAndSettle();

      // Active video should be cleared to allow explore tab to set its own video
      final afterSwitch = container.read(activeVideoProvider);
      expect(
        afterSwitch.currentVideoId,
        isNull,
        reason: 'Active video cleared to allow new tab to set active video',
      );

      // New tab can now set its own active video
      container.read(activeVideoProvider.notifier).setActiveVideo('explore-video');
      final exploreActive = container.read(activeVideoProvider);
      expect(exploreActive.currentVideoId, equals('explore-video'));
    });
  });
}
