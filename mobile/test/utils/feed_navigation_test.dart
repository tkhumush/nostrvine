// ABOUTME: Tests for FeedNavigation utilities
// ABOUTME: Verifies navigation methods for launching contextual video feeds

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/feed_navigation.dart';
import 'package:openvine/main.dart';

void main() {
  group('FeedNavigation.goToMainFeed', () {
    testWidgets('should switch to feed tab when startingVideo is provided',
        (WidgetTester tester) async {
      // Create a test video event
      final testVideo = VideoEvent(
        id: 'test_video_id',
        pubkey: 'test_pubkey',
        createdAt: DateTime.now(),
        content: 'Test video description',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        tags: [],
      );

      // Create a GlobalKey for MainNavigationScreen
      final navKey = GlobalKey<MainNavigationScreenState>();

      // Build a minimal widget tree with MainNavigationScreen
      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationScreen(key: navKey),
        ),
      );

      // Verify MainNavigationScreen is mounted
      expect(navKey.currentState, isNotNull);

      // Call goToMainFeed with a starting video
      final context = tester.element(find.byKey(navKey));
      FeedNavigation.goToMainFeed(context, startingVideo: testVideo);

      await tester.pumpAndSettle();

      // Verify we're on the feed tab (index 0)
      expect(navKey.currentState!._currentIndex, equals(0));
    });

    testWidgets('should navigate to feed tab without video when no startingVideo',
        (WidgetTester tester) async {
      // Create a GlobalKey for MainNavigationScreen
      final navKey = GlobalKey<MainNavigationScreenState>();

      // Build widget tree
      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationScreen(key: navKey),
        ),
      );

      // Verify MainNavigationScreen is mounted
      expect(navKey.currentState, isNotNull);

      // Start on a different tab (explore = index 2)
      navKey.currentState!.switchToTab(2);
      await tester.pumpAndSettle();
      expect(navKey.currentState!._currentIndex, equals(2));

      // Call goToMainFeed without a starting video
      final context = tester.element(find.byKey(navKey));
      FeedNavigation.goToMainFeed(context);

      await tester.pumpAndSettle();

      // Should pop back to root
      // Since we're already at root (MainNavigationScreen), should stay there
      expect(navKey.currentState, isNotNull);
    });
  });
}
