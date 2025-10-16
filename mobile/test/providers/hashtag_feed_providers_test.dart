// ABOUTME: Tests for hashtag feed provider reactivity
// ABOUTME: Verifies that hashtag provider rebuilds when VideoEventService updates

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/router_location_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_prewarmer.dart';

/// Fake VideoEventService for testing reactive behavior
class FakeVideoEventService extends ChangeNotifier
    implements VideoEventService {
  final Map<String, List<VideoEvent>> _hashtagBuckets = {};
  final Map<String, List<VideoEvent>> _authorBuckets = {};

  // Track subscription calls for verification
  final List<List<String>> subscribedHashtags = [];
  final List<String> subscribedAuthors = [];

  @override
  List<VideoEvent> hashtagVideos(String tag) {
    final videos = _hashtagBuckets[tag] ?? [];
    print('DEBUG: hashtagVideos($tag) returning ${videos.length} videos. Buckets: ${_hashtagBuckets.keys.toList()}');
    return videos;
  }

  @override
  List<VideoEvent> authorVideos(String pubkeyHex) =>
      _authorBuckets[pubkeyHex] ?? [];

  @override
  Future<void> subscribeToHashtagVideos(List<String> hashtags,
      {int limit = 100}) async {
    subscribedHashtags.add(hashtags);
  }

  @override
  Future<void> subscribeToUserVideos(String pubkey, {int limit = 50}) async {
    subscribedAuthors.add(pubkey);
  }

  // Test helper: emit events for a hashtag
  void emitHashtagVideos(String tag, List<VideoEvent> videos) {
    _hashtagBuckets[tag] = videos;
    notifyListeners();
  }

  // Test helper: emit events for an author
  void emitAuthorVideos(String pubkeyHex, List<VideoEvent> videos) {
    _authorBuckets[pubkeyHex] = videos;
    notifyListeners();
  }

  // Stub implementations for required interface methods
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('HashtagFeedProvider', () {
    late FakeVideoEventService fakeService;
    late ProviderContainer container;

    setUp(() {
      fakeService = FakeVideoEventService();
    });

    tearDown(() {
      container.dispose();
    });

    test('returns empty state when route type is not hashtag', () {
      // Arrange: Route context is home, not hashtag
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(const RouteContext(type: RouteType.home));
          }),
        ],
      );

      // Act
      final result = container.read(videosForHashtagRouteProvider);

      // Assert
      expect(result.hasValue, isTrue);
      expect(result.value!.videos, isEmpty);
      expect(result.value!.hasMoreContent, isFalse);
    });

    test('returns empty state when hashtag is empty', () {
      // Arrange: Route is hashtag but tag is empty
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          pageContextProvider.overrideWith((ref) {
            return Stream.value(const RouteContext(
              type: RouteType.hashtag,
              hashtag: '',
            ));
          }),
        ],
      );

      // Act
      final result = container.read(videosForHashtagRouteProvider);

      // Assert
      expect(result.hasValue, isTrue);
      expect(result.value!.videos, isEmpty);
    });

    test('selects videos from pre-populated hashtag bucket', () async {
      // Arrange: Override router location to /hashtag/bitcoin/0
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          routerLocationStreamProvider.overrideWithValue(
            Stream.value('/hashtag/bitcoin/0'),
          ),
        ],
      );

      // Wait for stream to emit and provider to initialize
      await pumpEventQueue();

      // Establish listener to ensure provider is watching for changes
      final subscription = container.listen(
        videosForHashtagRouteProvider,
        (_, __) {},
      );

      // Pre-populate the fake service AFTER container is created
      // This triggers notifyListeners() which updates the select()
      fakeService.emitHashtagVideos('bitcoin', [
        VideoEvent(
          id: 'btc1',
          pubkey: 'author1',
          createdAt: 1000,
          content: 'Bitcoin video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/btc1.mp4',
        ),
      ]);

      // Wait for notification to propagate
      await pumpEventQueue();

      // Act: Read provider (selects from populated bucket)
      final result = container.read(videosForHashtagRouteProvider);

      // Cleanup
      subscription.close();

      // Assert: Should show the populated video
      expect(result.hasValue, isTrue);
      expect(result.value!.videos.length, equals(1));
      expect(result.value!.videos[0].id, equals('btc1'));
    });

    test('shows videos from service hashtag bucket', () async {
      // Arrange: Create container first
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          routerLocationStreamProvider.overrideWithValue(
            Stream.value('/hashtag/nostr/0'),
          ),
        ],
      );

      // Wait for stream to emit and provider to initialize
      await pumpEventQueue();

      // Establish listener to ensure provider is watching for changes
      final subscription = container.listen(
        videosForHashtagRouteProvider,
        (_, __) {},
      );

      // Pre-populate service AFTER listener is established
      fakeService.emitHashtagVideos('nostr', [
        VideoEvent(
          id: 'nostr1',
          pubkey: 'author1',
          createdAt: 1000,
          content: 'First nostr video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/nostr1.mp4',
        ),
        VideoEvent(
          id: 'nostr2',
          pubkey: 'author2',
          createdAt: 2000,
          content: 'Second nostr video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/nostr2.mp4',
        ),
      ]);

      // Wait for notification to propagate
      await pumpEventQueue();

      // Act
      final result = container.read(videosForHashtagRouteProvider);

      // Cleanup
      subscription.close();

      // Assert: Should show both videos from the bucket
      expect(result.hasValue, isTrue);
      expect(result.value!.videos.length, equals(2));
      expect(result.value!.videos[0].id, equals('nostr1'));
      expect(result.value!.videos[1].id, equals('nostr2'));
    });

    test('only shows videos for the specific hashtag', () async {
      // Arrange: Create container first
      // Route is /hashtag/nostr
      container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(fakeService),
          videoPrewarmerProvider.overrideWithValue(NoopPrewarmer()),
          routerLocationStreamProvider.overrideWithValue(
            Stream.value('/hashtag/nostr/0'),
          ),
        ],
      );

      // Wait for stream to emit and provider to initialize
      await pumpEventQueue();

      // Establish listener to ensure provider is watching for changes
      final subscription = container.listen(
        videosForHashtagRouteProvider,
        (_, __) {},
      );

      // Populate service with videos for multiple hashtags AFTER listener is established
      fakeService.emitHashtagVideos('nostr', [
        VideoEvent(
          id: 'nostr1',
          pubkey: 'author1',
          createdAt: 1000,
          content: 'Nostr video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/nostr1.mp4',
        ),
      ]);

      fakeService.emitHashtagVideos('bitcoin', [
        VideoEvent(
          id: 'btc1',
          pubkey: 'author2',
          createdAt: 2000,
          content: 'Bitcoin video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/btc1.mp4',
        ),
      ]);

      // Wait for notification to propagate
      await pumpEventQueue();

      // Act
      final result = container.read(videosForHashtagRouteProvider);

      // Cleanup
      subscription.close();

      // Assert: Should only show nostr video, not bitcoin
      expect(result.value!.videos.length, equals(1));
      expect(result.value!.videos[0].id, equals('nostr1'));
      expect(result.value!.videos[0].content, contains('Nostr'));
    });
  });
}
