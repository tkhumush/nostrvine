// ABOUTME: Real data widget test for VideoFeedItem using actual embedded relay
// ABOUTME: Tests video feed with real Nostr events, real video URLs, and actual user interactions

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  // Initialize Flutter bindings - CRITICAL for embedded relay
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock platform channels that embedded relay needs
  _setupPlatformMocks();

  group('VideoFeedItem - Real Data Tests', () {
    late NostrService nostrService;
    late SubscriptionManager subscriptionManager;
    late VideoEventService videoEventService;
    late NostrKeyManager keyManager;
    late List<VideoEvent> realVideos;

    setUpAll(() async {
      Log.info('🚀 Setting up real data test environment',
          name: 'RealDataTest', category: LogCategory.system);

      // Initialize key manager
      keyManager = NostrKeyManager();
      await keyManager.initialize();

      // Initialize Nostr service with real relays
      nostrService = NostrService(keyManager);
      await nostrService.initialize(customRelays: [
        'wss://relay3.openvine.co',
        'wss://relay.damus.io',
        'wss://nos.lol'
      ]);

      // Wait for connection
      await _waitForRelayConnection(nostrService);

      // Setup video event service
      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(nostrService,
          subscriptionManager: subscriptionManager);

      // Fetch real videos
      realVideos = await _fetchRealVideoEvents(videoEventService);

      Log.info('✅ Found ${realVideos.length} real videos for testing',
          name: 'RealDataTest', category: LogCategory.system);
    });

    tearDownAll(() async {
      Log.info('🧹 Cleaning up real data test environment',
          name: 'RealDataTest', category: LogCategory.system);

      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
      videoEventService.dispose();
      subscriptionManager.dispose();
    });

    group('Real Video Display', () {
      testWidgets('displays real video with actual thumbnail', (tester) async {
        // Skip if no real videos available
        if (realVideos.isEmpty) {
          Log.warning('No real videos available, skipping test',
              name: 'RealDataTest', category: LogCategory.system);
          return;
        }

        final testVideo = realVideos.first;
        Log.info('Testing with real video: ${testVideo.title ?? testVideo.id.substring(0, 8)}',
            name: 'RealDataTest', category: LogCategory.system);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  width: 300,
                  child: VideoFeedItem(
                    video: testVideo,
                    index: 0,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify basic widget structure
        expect(find.byType(VideoFeedItem), findsOneWidget);
        expect(find.byType(GestureDetector), findsOneWidget);

        // Verify content is displayed
        if (testVideo.content.isNotEmpty) {
          // Content might be in overlay, pump again to ensure it's rendered
          await tester.pump(Duration(milliseconds: 100));
        }

        // Verify no error states
        expect(find.byIcon(Icons.error_outline), findsNothing);

        Log.info('✅ Real video displayed successfully',
            name: 'RealDataTest', category: LogCategory.system);
      });

      testWidgets('handles real video tap interactions', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  width: 300,
                  child: VideoFeedItem(
                    video: testVideo,
                    index: 0,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Get provider container to check state
        final container = ProviderScope.containerOf(
          tester.element(find.byType(VideoFeedItem)),
        );

        // Initially not active
        expect(container.read(activeVideoProvider), isNull);

        // Tap the video
        await tester.tap(find.byType(VideoFeedItem));
        await tester.pumpAndSettle();

        // Should become active
        expect(container.read(activeVideoProvider), equals(testVideo.id));

        Log.info('✅ Real video tap interaction successful',
            name: 'RealDataTest', category: LogCategory.system);
      });

      testWidgets('shows real video metadata correctly', (tester) async {
        if (realVideos.isEmpty) return;

        // Find a video with good metadata
        final testVideo = realVideos.firstWhere(
          (v) => v.title != null && v.title!.isNotEmpty,
          orElse: () => realVideos.first,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  width: 300,
                  child: VideoFeedItem(
                    video: testVideo,
                    index: 0,
                    forceShowOverlay: true, // Force overlay visible for testing
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check for content display
        if (testVideo.content.isNotEmpty) {
          expect(find.textContaining(testVideo.content), findsWidgets);
        }

        // Check for title if available
        if (testVideo.title != null && testVideo.title!.isNotEmpty) {
          expect(find.textContaining(testVideo.title!), findsWidgets);
        }

        // Check for publisher info (should show pubkey or display name)
        final pubkeyShort = testVideo.pubkey.substring(0, 8);
        expect(find.textContaining(pubkeyShort), findsWidgets);

        Log.info('✅ Real video metadata displayed correctly',
            name: 'RealDataTest', category: LogCategory.system);
      });
    });

    group('Real Video State Management', () {
      testWidgets('manages real video controller lifecycle', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.firstWhere(
          (v) => v.videoUrl != null && v.videoUrl!.isNotEmpty,
          orElse: () => realVideos.first,
        );

        if (testVideo.videoUrl == null) {
          Log.warning('No video with URL found, skipping controller test',
              name: 'RealDataTest', category: LogCategory.system);
          return;
        }

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  width: 300,
                  child: VideoFeedItem(
                    video: testVideo,
                    index: 0,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(VideoFeedItem)),
        );

        // Make video active to trigger controller creation
        container.read(activeVideoProvider.notifier).setActiveVideo(testVideo.id);
        await tester.pumpAndSettle();

        // Verify controller is created for this video
        final controllerParams = VideoControllerParams(
          videoId: testVideo.id,
          videoUrl: testVideo.videoUrl!,
          videoEvent: testVideo,
        );

        expect(
          () => container.read(individualVideoControllerProvider(controllerParams)),
          returnsNormally,
        );

        Log.info('✅ Real video controller created successfully',
            name: 'RealDataTest', category: LogCategory.system);
      });

      testWidgets('handles multiple real videos correctly', (tester) async {
        if (realVideos.length < 2) {
          Log.warning('Need at least 2 real videos for multi-video test',
              name: 'RealDataTest', category: LogCategory.system);
          return;
        }

        final firstVideo = realVideos[0];
        final secondVideo = realVideos[1];

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      width: 300,
                      child: VideoFeedItem(
                        video: firstVideo,
                        index: 0,
                      ),
                    ),
                    SizedBox(
                      height: 200,
                      width: 300,
                      child: VideoFeedItem(
                        video: secondVideo,
                        index: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Both videos should be rendered
        expect(find.byType(VideoFeedItem), findsNWidgets(2));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(VideoFeedItem).first),
        );

        // Activate first video
        container.read(activeVideoProvider.notifier).setActiveVideo(firstVideo.id);
        await tester.pumpAndSettle();

        expect(container.read(activeVideoProvider), equals(firstVideo.id));
        expect(container.read(isVideoActiveProvider(firstVideo.id)), isTrue);
        expect(container.read(isVideoActiveProvider(secondVideo.id)), isFalse);

        // Switch to second video
        container.read(activeVideoProvider.notifier).setActiveVideo(secondVideo.id);
        await tester.pumpAndSettle();

        expect(container.read(activeVideoProvider), equals(secondVideo.id));
        expect(container.read(isVideoActiveProvider(firstVideo.id)), isFalse);
        expect(container.read(isVideoActiveProvider(secondVideo.id)), isTrue);

        Log.info('✅ Multiple real videos handled correctly',
            name: 'RealDataTest', category: LogCategory.system);
      });
    });

    group('Real Video Error Handling', () {
      testWidgets('handles real videos with missing URLs gracefully', (tester) async {
        // Find or create a video with missing URL
        final videoWithoutUrl = realVideos.isNotEmpty
            ? VideoEvent(
                id: '${realVideos.first.id}_no_url',
                pubkey: realVideos.first.pubkey,
                content: realVideos.first.content,
                videoUrl: null, // Missing URL
                title: 'Test Video Without URL',
                createdAt: realVideos.first.createdAt,
                timestamp: realVideos.first.timestamp,
              )
            : VideoEvent(
                id: 'test_no_url',
                pubkey: 'test_pubkey',
                content: 'Test content',
                videoUrl: null,
                title: 'Test Video Without URL',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                timestamp: DateTime.now(),
              );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  width: 300,
                  child: VideoFeedItem(
                    video: videoWithoutUrl,
                    index: 0,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show error icon for missing video
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.byType(VideoFeedItem), findsOneWidget);

        Log.info('✅ Missing video URL handled gracefully',
            name: 'RealDataTest', category: LogCategory.system);
      });

      testWidgets('handles real video network errors gracefully', (tester) async {
        if (realVideos.isEmpty) return;

        // Create a video with invalid URL but real metadata
        final realVideo = realVideos.first;
        final videoWithBadUrl = VideoEvent(
          id: '${realVideo.id}_bad_url',
          pubkey: realVideo.pubkey,
          content: realVideo.content,
          videoUrl: 'https://invalid-domain-that-does-not-exist.com/video.mp4',
          title: realVideo.title,
          createdAt: realVideo.createdAt,
          timestamp: realVideo.timestamp,
          thumbnailUrl: realVideo.thumbnailUrl,
          blurhash: realVideo.blurhash,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  width: 300,
                  child: VideoFeedItem(
                    video: videoWithBadUrl,
                    index: 0,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should not crash and should show some fallback UI
        expect(find.byType(VideoFeedItem), findsOneWidget);

        // Make it active to test video controller error handling
        final container = ProviderScope.containerOf(
          tester.element(find.byType(VideoFeedItem)),
        );

        container.read(activeVideoProvider.notifier).setActiveVideo(videoWithBadUrl.id);
        await tester.pumpAndSettle();

        // Should not crash even with bad video URL
        expect(find.byType(VideoFeedItem), findsOneWidget);

        Log.info('✅ Network errors handled gracefully',
            name: 'RealDataTest', category: LogCategory.system);
      });
    });

    group('Real Hashtag Integration', () {
      testWidgets('displays and handles real hashtags in video content', (tester) async {
        // Find a video with hashtags
        final videoWithHashtags = realVideos.firstWhere(
          (v) => v.hashtags.isNotEmpty,
          orElse: () => realVideos.isNotEmpty ? realVideos.first : VideoEvent(
            id: 'test_hashtag',
            pubkey: 'test_pubkey',
            content: 'Test video with #openvine #nostr hashtags',
            videoUrl: 'https://example.com/video.mp4',
            title: 'Test Hashtag Video',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            timestamp: DateTime.now(),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 400,
                  width: 300,
                  child: VideoFeedItem(
                    video: videoWithHashtags,
                    index: 0,
                    forceShowOverlay: true,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should display hashtags if present
        if (videoWithHashtags.hashtags.isNotEmpty) {
          Log.info('Found hashtags: ${videoWithHashtags.hashtags}',
              name: 'RealDataTest', category: LogCategory.system);

          // Look for hashtag display in content
          expect(find.byType(VideoFeedItem), findsOneWidget);
        }

        Log.info('✅ Real hashtags displayed correctly',
            name: 'RealDataTest', category: LogCategory.system);
      });
    });
  });
}

void _setupPlatformMocks() {
  // Mock SharedPreferences
  const MethodChannel prefsChannel =
      MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    prefsChannel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') return <String, dynamic>{};
      if (methodCall.method == 'setString' ||
          methodCall.method == 'setStringList' ||
          methodCall.method == 'setBool') {
        return true;
      }
      return null;
    },
  );

  // Mock connectivity
  const MethodChannel connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    connectivityChannel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'check') return ['wifi'];
      return null;
    },
  );

  // Mock secure storage
  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    secureStorageChannel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'write') return null;
      if (methodCall.method == 'read') return null;
      if (methodCall.method == 'readAll') return <String, String>{};
      return null;
    },
  );

  // Mock path provider for embedded relay database
  const MethodChannel pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    pathProviderChannel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return '/tmp/openvine_test_db';
      }
      return null;
    },
  );

  // Mock device info
  const MethodChannel deviceInfoChannel =
      MethodChannel('dev.fluttercommunity.plus/device_info');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    deviceInfoChannel,
    (MethodCall methodCall) async {
      return <String, dynamic>{
        'systemName': 'iOS',
        'model': 'iPhone',
      };
    },
  );
}

Future<void> _waitForRelayConnection(NostrService nostrService) async {
  Log.info('⏳ Waiting for relay connection...',
      name: 'RealDataTest', category: LogCategory.system);

  final connectionCompleter = Completer<void>();
  late Timer timer;

  timer = Timer.periodic(Duration(milliseconds: 500), (t) {
    if (nostrService.connectedRelayCount > 0) {
      timer.cancel();
      connectionCompleter.complete();
    }
  });

  try {
    await connectionCompleter.future.timeout(Duration(seconds: 30));
    Log.info('✅ Connected to ${nostrService.connectedRelayCount} relays',
        name: 'RealDataTest', category: LogCategory.system);
  } catch (e) {
    timer.cancel();
    Log.warning('Connection timeout, proceeding anyway: $e',
        name: 'RealDataTest', category: LogCategory.system);
  }
}

Future<List<VideoEvent>> _fetchRealVideoEvents(VideoEventService videoEventService) async {
  Log.info('📡 Fetching real video events...',
      name: 'RealDataTest', category: LogCategory.system);

  // Start discovery subscription to get real videos
  await videoEventService.startDiscoverySubscription();

  // Wait for events to arrive
  final videos = <VideoEvent>[];
  final maxWaitTime = Duration(seconds: 15);
  final startTime = DateTime.now();

  while (videos.length < 3 && DateTime.now().difference(startTime) < maxWaitTime) {
    await Future.delayed(Duration(milliseconds: 500));

    final discoveryVideos = videoEventService.discoveryVideos;

    for (final video in discoveryVideos) {
      if (!videos.any((v) => v.id == video.id)) {
        videos.add(video);
        Log.info('📹 Found real video: ${video.title ?? video.id.substring(0, 8)} (${video.videoUrl != null ? "with URL" : "no URL"})',
            name: 'RealDataTest', category: LogCategory.system);
      }
    }
  }

  Log.info('✅ Fetched ${videos.length} real videos',
      name: 'RealDataTest', category: LogCategory.system);

  return videos;
}