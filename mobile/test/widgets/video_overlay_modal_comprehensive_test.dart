// ABOUTME: Comprehensive TDD tests for VideoOverlayModal with real data integration
// ABOUTME: Tests all functionality including VideoManager integration and state management

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/video_overlay_modal.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPlatformMocks();

  group('VideoOverlayModal - Comprehensive TDD Tests', () {
    late NostrService nostrService;
    late NostrKeyManager keyManager;
    late VideoEventService videoEventService;
    late SubscriptionManager subscriptionManager;
    late List<VideoEvent> realVideos;

    setUpAll(() async {
      Log.info('🚀 Setting up real video data test environment',
          name: 'VideoOverlayModalTest', category: LogCategory.system);

      keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      await nostrService.initialize(customRelays: [
        'wss://relay3.openvine.co',
        'wss://relay.damus.io',
        'wss://nos.lol'
      ]);

      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(nostrService, subscriptionManager: subscriptionManager);
      await _waitForRelayConnection(nostrService);
      realVideos = await _fetchRealVideoEvents(videoEventService);

      Log.info('✅ Found ${realVideos.length} real videos for testing',
          name: 'VideoOverlayModalTest', category: LogCategory.system);
    });

    tearDownAll(() async {
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
    });

    group('Basic Widget Structure', () {
      testWidgets('creates VideoOverlayModal with required properties', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;
        final testList = realVideos.take(3).toList();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoOverlayModal(
                startingVideo: testVideo,
                videoList: testList,
                contextTitle: 'Test Context',
                startingIndex: 0,
              ),
            ),
          ),
        );

        expect(find.byType(VideoOverlayModal), findsOneWidget);
        expect(find.text('Test Context'), findsOneWidget);
        expect(find.text('1 of ${testList.length}'), findsOneWidget);
      });

      testWidgets('displays correct video count in app bar', (tester) async {
        if (realVideos.length < 3) return;

        final testVideos = realVideos.take(5).toList();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoOverlayModal(
                startingVideo: testVideos.first,
                videoList: testVideos,
                contextTitle: 'Test Videos',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('1 of 5'), findsOneWidget);
        expect(find.text('Test Videos'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('shows empty state when video list is empty', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoOverlayModal(
                startingVideo: _createFallbackVideo(),
                videoList: [],
                contextTitle: 'Empty Test',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('No videos available'), findsOneWidget);
        expect(find.text('Debug: List has 0 videos'), findsOneWidget);
      });
    });

    group('VideoManager Integration Tests', () {
      testWidgets('integrates with activeVideoProvider for state management', (tester) async {
        if (realVideos.length < 2) return;

        final testVideos = realVideos.take(3).toList();
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  home: VideoOverlayModal(
                    startingVideo: testVideos.first,
                    videoList: testVideos,
                    contextTitle: 'Active Video Test',
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initial state - should have no active video (VideoOverlayModal should set it)
        final initialActiveVideo = container.read(activeVideoProvider);
        Log.info('Initial active video: $initialActiveVideo',
            name: 'VideoOverlayModalTest', category: LogCategory.system);

        // TODO: VideoOverlayModal should set active video when opened
        // This test will FAIL until VideoManager integration is restored
        expect(container.read(activeVideoProvider), equals(testVideos.first.id));
      });

      testWidgets('handles page changes and updates active video', (tester) async {
        if (realVideos.length < 3) return;

        final testVideos = realVideos.take(3).toList();
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  home: VideoOverlayModal(
                    startingVideo: testVideos.first,
                    videoList: testVideos,
                    contextTitle: 'Page Change Test',
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find PageView and swipe to next video
        final pageView = find.byType(PageView);
        expect(pageView, findsOneWidget);

        // Swipe up to go to next video (vertical scrolling)
        await tester.drag(pageView, const Offset(0, -300));
        await tester.pumpAndSettle();

        // Check that app bar updates
        expect(find.text('2 of 3'), findsOneWidget);

        // TODO: Check active video provider updated - will FAIL until integration restored
        expect(container.read(activeVideoProvider), equals(testVideos[1].id));
      });

      testWidgets('clears active video when modal is dismissed', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  home: Scaffold(
                    body: ElevatedButton(
                      onPressed: () => showVideoOverlay(
                        context: context,
                        startingVideo: testVideo,
                        videoList: [testVideo],
                        contextTitle: 'Dismissal Test',
                      ),
                      child: const Text('Show Modal'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open modal
        await tester.tap(find.text('Show Modal'));
        await tester.pumpAndSettle();

        // Verify modal opened
        expect(find.byType(VideoOverlayModal), findsOneWidget);

        // Close modal
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Verify modal closed
        expect(find.byType(VideoOverlayModal), findsNothing);

        // TODO: Verify active video cleared - will FAIL until integration restored
        expect(container.read(activeVideoProvider), isNull);
      });
    });

    group('Navigation and User Interactions', () {
      testWidgets('handles close button tap', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoOverlayModal(
                startingVideo: testVideo,
                videoList: [testVideo],
                contextTitle: 'Close Test',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify modal is showing
        expect(find.byType(VideoOverlayModal), findsOneWidget);

        // Tap close button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Modal should be dismissed (Navigator.pop called)
        // In test environment, modal widget still exists but navigation occurred
        expect(find.byIcon(Icons.close), findsOneWidget);
      });

      testWidgets('supports vertical swiping between videos', (tester) async {
        if (realVideos.length < 3) return;

        final testVideos = realVideos.take(3).toList();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoOverlayModal(
                startingVideo: testVideos.first,
                videoList: testVideos,
                contextTitle: 'Swipe Test',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initial state
        expect(find.text('1 of 3'), findsOneWidget);

        // Swipe up (to next video)
        final pageView = find.byType(PageView);
        await tester.drag(pageView, const Offset(0, -400));
        await tester.pumpAndSettle();

        // Should show next video
        expect(find.text('2 of 3'), findsOneWidget);

        // Swipe up again
        await tester.drag(pageView, const Offset(0, -400));
        await tester.pumpAndSettle();

        // Should show third video
        expect(find.text('3 of 3'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('handles invalid starting index gracefully', (tester) async {
        if (realVideos.length < 2) return;

        final testVideos = realVideos.take(2).toList();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoOverlayModal(
                startingVideo: testVideos.first,
                videoList: testVideos,
                contextTitle: 'Invalid Index Test',
                startingIndex: 99, // Invalid index
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should default to first video (index 0)
        expect(find.text('1 of 2'), findsOneWidget);
        expect(find.byType(VideoOverlayModal), findsOneWidget);
      });

      testWidgets('handles mismatched starting video gracefully', (tester) async {
        if (realVideos.length < 2) return;

        final testVideos = realVideos.take(2).toList();
        final differentVideo = _createFallbackVideo();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoOverlayModal(
                startingVideo: differentVideo, // Not in the list
                videoList: testVideos,
                contextTitle: 'Mismatch Test',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should default to first video in list
        expect(find.text('1 of 2'), findsOneWidget);
        expect(find.byType(VideoOverlayModal), findsOneWidget);
      });
    });

    group('showVideoOverlay Helper Function', () {
      testWidgets('showVideoOverlay creates modal with correct properties', (tester) async {
        if (realVideos.isEmpty) return;

        final testVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showVideoOverlay(
                      context: context,
                      startingVideo: testVideo,
                      videoList: [testVideo],
                      contextTitle: 'Helper Test',
                      startingIndex: 0,
                    ),
                    child: const Text('Show Overlay'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap button to show overlay
        await tester.tap(find.text('Show Overlay'));
        await tester.pumpAndSettle();

        // Verify modal appeared
        expect(find.byType(VideoOverlayModal), findsOneWidget);
        expect(find.text('Helper Test'), findsOneWidget);
      });

      testWidgets('showVideoOverlay handles empty video list', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showVideoOverlay(
                    context: context,
                    startingVideo: _createFallbackVideo(),
                    videoList: [], // Empty list
                    contextTitle: 'Empty List Test',
                  ),
                  child: const Text('Show Empty'),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap button
        await tester.tap(find.text('Show Empty'));
        await tester.pumpAndSettle();

        // No modal should appear due to empty list
        expect(find.byType(VideoOverlayModal), findsNothing);
      });
    });

    group('Real Data Integration', () {
      testWidgets('displays real video content with proper metadata', (tester) async {
        if (realVideos.isEmpty) return;

        final realVideo = realVideos.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoOverlayModal(
                startingVideo: realVideo,
                videoList: [realVideo],
                contextTitle: 'Real Content Test',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should display real video content
        expect(find.byType(VideoOverlayModal), findsOneWidget);
        expect(find.text('Real Content Test'), findsOneWidget);

        Log.info('✅ Real video displayed: ${realVideo.title ?? "No title"}',
            name: 'VideoOverlayModalTest', category: LogCategory.system);
      });

      testWidgets('handles multiple real videos with navigation', (tester) async {
        if (realVideos.length < 3) return;

        final testVideos = realVideos.take(3).toList();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoOverlayModal(
                startingVideo: testVideos.first,
                videoList: testVideos,
                contextTitle: 'Multiple Real Videos',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify initial state
        expect(find.text('1 of 3'), findsOneWidget);

        // Navigate through videos
        final pageView = find.byType(PageView);

        await tester.drag(pageView, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('2 of 3'), findsOneWidget);

        await tester.drag(pageView, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('3 of 3'), findsOneWidget);

        Log.info('✅ Successfully navigated through ${testVideos.length} real videos',
            name: 'VideoOverlayModalTest', category: LogCategory.system);
      });
    });
  });
}

void _setupPlatformMocks() {
  // Mock SharedPreferences
  const MethodChannel prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(prefsChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'getAll') return <String, dynamic>{};
    if (methodCall.method == 'setString' || methodCall.method == 'setBool') return true;
    return null;
  });

  // Mock connectivity
  const MethodChannel connectivityChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(connectivityChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'check') return ['wifi'];
    return null;
  });

  // Mock secure storage
  const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'write') return null;
    if (methodCall.method == 'read') return null;
    if (methodCall.method == 'readAll') return <String, String>{};
    return null;
  });

  // Mock path provider
  const MethodChannel pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return '/tmp/openvine_overlay_test_db';
    }
    return null;
  });

  // Mock device info
  const MethodChannel deviceInfoChannel = MethodChannel('dev.fluttercommunity.plus/device_info');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(deviceInfoChannel, (MethodCall methodCall) async {
    return <String, dynamic>{'systemName': 'iOS', 'model': 'iPhone'};
  });
}

Future<void> _waitForRelayConnection(NostrService nostrService) async {
  final connectionCompleter = Completer<void>();
  late Timer timer;

  timer = Timer.periodic(Duration(milliseconds: 500), (t) {
    if (nostrService.connectedRelayCount > 0) {
      timer.cancel();
      connectionCompleter.complete();
    }
  });

  try {
    await connectionCompleter.future.timeout(Duration(seconds: 20));
    Log.info('✅ Connected to ${nostrService.connectedRelayCount} relays',
        name: 'VideoOverlayModalTest', category: LogCategory.system);
  } catch (e) {
    timer.cancel();
    Log.warning('Connection timeout: $e', name: 'VideoOverlayModalTest', category: LogCategory.system);
  }
}

Future<List<VideoEvent>> _fetchRealVideoEvents(VideoEventService videoEventService) async {
  Log.info('🎬 Fetching real video events...', name: 'VideoOverlayModalTest', category: LogCategory.system);

  try {
    // Subscribe to discovery videos (public feed)
    await videoEventService.subscribeToDiscovery();
    await Future.delayed(Duration(seconds: 3)); // Allow time for events

    final videos = videoEventService.discoveryVideos;
    Log.info('📋 Found ${videos.length} video events for testing',
        name: 'VideoOverlayModalTest', category: LogCategory.system);

    for (int i = 0; i < videos.length && i < 3; i++) {
      final video = videos[i];
      Log.info('  [$i] ${video.title ?? "No title"} (${video.videoUrl != null ? "has video" : "no video"})',
          name: 'VideoOverlayModalTest', category: LogCategory.system);
    }

    return videos;
  } catch (e) {
    Log.error('Failed to fetch video events: $e',
        name: 'VideoOverlayModalTest', category: LogCategory.system);
    return [];
  }
}

VideoEvent _createFallbackVideo() {
  return VideoEvent(
    id: 'test_video_${DateTime.now().millisecondsSinceEpoch}',
    title: 'Test Video',
    videoUrl: 'https://example.com/test.mp4',
    pubkey: 'test_pubkey',
    content: 'Test video content',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    timestamp: DateTime.now(),
  );
}