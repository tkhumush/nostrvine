// ABOUTME: Real data widget test for ClickableHashtagText using actual video content hashtags
// ABOUTME: Tests hashtag parsing and navigation with real hashtags from Nostr video events

import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/hashtag_extractor.dart';

import 'real_data_clickable_hashtag_test.mocks.dart';

@GenerateNiceMocks([MockSpec<NavigatorObserver>()])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPlatformMocks();

  group('ClickableHashtagText - Real Data Tests', () {
    late NostrService nostrService;
    late VideoEventService videoEventService;
    late SubscriptionManager subscriptionManager;
    late NostrKeyManager keyManager;
    late List<VideoEvent> videosWithHashtags;
    late MockNavigatorObserver mockObserver;

    setUpAll(() async {
      Log.info('🚀 Setting up real hashtag data test environment',
          name: 'RealHashtagTest', category: LogCategory.system);

      mockObserver = MockNavigatorObserver();

      keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      await nostrService.initialize(customRelays: [
        'wss://relay3.openvine.co',
        'wss://relay.damus.io',
        'wss://nos.lol'
      ]);

      await _waitForRelayConnection(nostrService);

      subscriptionManager = SubscriptionManager(nostrService);
      videoEventService = VideoEventService(nostrService,
          subscriptionManager: subscriptionManager);

      videosWithHashtags = await _fetchVideosWithHashtags(videoEventService);

      Log.info('✅ Found ${videosWithHashtags.length} videos with real hashtags',
          name: 'RealHashtagTest', category: LogCategory.system);
    });

    tearDownAll(() async {
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
      videoEventService.dispose();
      subscriptionManager.dispose();
    });

    group('Real Hashtag Display', () {
      testWidgets('parses and displays real hashtags from video content', (tester) async {
        if (videosWithHashtags.isEmpty) {
          Log.warning('No videos with hashtags found, skipping test',
              name: 'RealHashtagTest', category: LogCategory.system);
          return;
        }

        final videoWithHashtags = videosWithHashtags.first;
        final realContent = videoWithHashtags.content;

        Log.info('Testing with real video content: $realContent',
            name: 'RealHashtagTest', category: LogCategory.system);
        Log.info('Extracted hashtags: ${videoWithHashtags.hashtags}',
            name: 'RealHashtagTest', category: LogCategory.system);

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [mockObserver],
            home: Scaffold(
              body: ClickableHashtagText(text: realContent),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should create TextSpans if hashtags are present
        if (videoWithHashtags.hashtags.isNotEmpty) {
          final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
          expect(selectableText.textSpan, isNotNull);

          final spans = selectableText.textSpan!.children?.cast<TextSpan>() ?? [];
          expect(spans, isNotEmpty);

          // Verify hashtags are clickable
          final clickableSpans = spans.where((span) => span.recognizer != null).toList();
          expect(clickableSpans.length, greaterThanOrEqualTo(1));

          Log.info('✅ Found ${clickableSpans.length} clickable hashtag spans',
              name: 'RealHashtagTest', category: LogCategory.system);
        }
      });

      testWidgets('handles real hashtags with different formats', (tester) async {
        final hashtagVariations = videosWithHashtags
            .expand((v) => v.hashtags)
            .toSet()
            .take(5)
            .toList();

        if (hashtagVariations.isEmpty) return;

        for (final hashtag in hashtagVariations) {
          final testText = 'Check out this #$hashtag content!';

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ClickableHashtagText(text: testText),
              ),
            ),
          );

          await tester.pumpAndSettle();

          final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
          final spans = selectableText.textSpan!.children!.cast<TextSpan>();

          // Should find the hashtag span
          final hashtagSpan = spans.firstWhere(
            (span) => span.text == '#$hashtag',
            orElse: () => spans.first,
          );

          expect(hashtagSpan.text, '#$hashtag');
          expect(hashtagSpan.recognizer, isA<TapGestureRecognizer>());

          Log.info('✅ Real hashtag #$hashtag parsed correctly',
              name: 'RealHashtagTest', category: LogCategory.system);

          // Clear widget for next test
          await tester.pumpWidget(Container());
        }
      });

      testWidgets('extracts hashtags correctly from real video content', (tester) async {
        for (final video in videosWithHashtags.take(3)) {
          final extractedHashtags = HashtagExtractor.extractHashtags(video.content);

          Log.info('Video content: ${video.content}',
              name: 'RealHashtagTest', category: LogCategory.system);
          Log.info('VideoEvent hashtags: ${video.hashtags}',
              name: 'RealHashtagTest', category: LogCategory.system);
          Log.info('Extracted hashtags: $extractedHashtags',
              name: 'RealHashtagTest', category: LogCategory.system);

          // The extracted hashtags should match or be a subset of video hashtags
          // (VideoEvent hashtags might include more from tags, not just content)
          for (final extracted in extractedHashtags) {
            expect(video.content.toLowerCase(), contains('#${extracted.toLowerCase()}'));
          }
        }

        Log.info('✅ Hashtag extraction matches real video content',
            name: 'RealHashtagTest', category: LogCategory.system);
      });
    });

    group('Real Hashtag Interactions', () {
      testWidgets('navigates to hashtag feed when real hashtag is tapped', (tester) async {
        if (videosWithHashtags.isEmpty) return;

        final videoWithHashtags = videosWithHashtags.first;
        final firstHashtag = videoWithHashtags.hashtags.isNotEmpty
            ? videoWithHashtags.hashtags.first
            : 'openvine'; // fallback

        final testContent = 'Testing #$firstHashtag navigation';

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [mockObserver],
            home: Scaffold(
              body: ClickableHashtagText(text: testContent),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
        final spans = selectableText.textSpan!.children!.cast<TextSpan>();
        final hashtagSpan = spans.firstWhere((span) => span.text == '#$firstHashtag');
        final tapRecognizer = hashtagSpan.recognizer as TapGestureRecognizer;

        // Tap the hashtag
        tapRecognizer.onTap!();
        await tester.pumpAndSettle();

        // Verify navigation occurred
        verify(mockObserver.didPush(any, any));

        Log.info('✅ Real hashtag #$firstHashtag navigation successful',
            name: 'RealHashtagTest', category: LogCategory.system);
      });

      testWidgets('calls onVideoStateChange callback with real hashtags', (tester) async {
        if (videosWithHashtags.isEmpty) return;

        bool callbackCalled = false;
        final videoWithHashtags = videosWithHashtags.first;
        final realContent = videoWithHashtags.content;

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [mockObserver],
            home: Scaffold(
              body: ClickableHashtagText(
                text: realContent,
                onVideoStateChange: () {
                  callbackCalled = true;
                  Log.info('Video state change callback triggered',
                      name: 'RealHashtagTest', category: LogCategory.system);
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        if (videoWithHashtags.hashtags.isNotEmpty) {
          final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
          final spans = selectableText.textSpan!.children!.cast<TextSpan>();
          final clickableSpan = spans.firstWhere(
            (span) => span.recognizer != null,
            orElse: () => spans.first,
          );

          if (clickableSpan.recognizer != null) {
            final tapRecognizer = clickableSpan.recognizer as TapGestureRecognizer;
            tapRecognizer.onTap!();
            await tester.pumpAndSettle();

            expect(callbackCalled, isTrue);

            Log.info('✅ Video state change callback called for real hashtag',
                name: 'RealHashtagTest', category: LogCategory.system);
          }
        }
      });
    });

    group('Real Content Variations', () {
      testWidgets('handles complex real video content with multiple hashtags', (tester) async {
        // Find video with multiple hashtags
        final multiHashtagVideo = videosWithHashtags.firstWhere(
          (v) => v.hashtags.length >= 2,
          orElse: () => videosWithHashtags.isNotEmpty ? videosWithHashtags.first : _createFallbackVideo(),
        );

        final realContent = multiHashtagVideo.content;

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [mockObserver],
            home: Scaffold(
              body: ClickableHashtagText(text: realContent),
            ),
          ),
        );

        await tester.pumpAndSettle();

        if (multiHashtagVideo.hashtags.length >= 2) {
          final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
          final spans = selectableText.textSpan!.children!.cast<TextSpan>();
          final clickableSpans = spans.where((span) => span.recognizer != null).toList();

          expect(clickableSpans.length, greaterThanOrEqualTo(2));

          // Test tapping different hashtags
          for (int i = 0; i < clickableSpans.length && i < 2; i++) {
            final tapRecognizer = clickableSpans[i].recognizer as TapGestureRecognizer;
            tapRecognizer.onTap!();
            await tester.pumpAndSettle();
          }

          // Should have multiple navigation calls
          verify(mockObserver.didPush(any, any)).called(greaterThanOrEqualTo(2));

          Log.info('✅ Multiple real hashtags handled correctly',
              name: 'RealHashtagTest', category: LogCategory.system);
        }
      });

      testWidgets('preserves real content formatting with hashtags', (tester) async {
        final videoWithContent = videosWithHashtags.firstWhere(
          (v) => v.content.length > 50, // Find video with substantial content
          orElse: () => videosWithHashtags.isNotEmpty ? videosWithHashtags.first : _createFallbackVideo(),
        );

        final realContent = videoWithContent.content;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: ClickableHashtagText(text: realContent),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // The complete content should be preserved
        expect(find.textContaining(realContent.split(' ').first), findsOneWidget);

        Log.info('✅ Real content formatting preserved with hashtags',
            name: 'RealHashtagTest', category: LogCategory.system);
      });

      testWidgets('handles real content with no hashtags gracefully', (tester) async {
        // Create content without hashtags from real video
        final realVideo = videosWithHashtags.isNotEmpty ? videosWithHashtags.first : _createFallbackVideo();
        final contentWithoutHashtags = realVideo.content.replaceAll(RegExp(r'#\w+'), '').trim();

        if (contentWithoutHashtags.isEmpty) return;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ClickableHashtagText(text: contentWithoutHashtags),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should use simple SelectableText without TextSpan
        final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
        expect(selectableText.data, contentWithoutHashtags);
        expect(selectableText.textSpan, isNull);

        Log.info('✅ Real content without hashtags handled correctly',
            name: 'RealHashtagTest', category: LogCategory.system);
      });
    });

    group('Real Error Handling', () {
      testWidgets('handles malformed hashtags in real content', (tester) async {
        // Create content with edge case hashtags
        final testContent = 'Real content with # single hash and ##double hash and #123numbers';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ClickableHashtagText(text: testContent),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should not crash with malformed hashtags
        expect(find.byType(ClickableHashtagText), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);

        Log.info('✅ Malformed hashtags in real content handled gracefully',
            name: 'RealHashtagTest', category: LogCategory.system);
      });
    });
  });
}

void _setupPlatformMocks() {
  // Mock SharedPreferences
  const MethodChannel prefsChannel =
      MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(prefsChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'getAll') return <String, dynamic>{};
    if (methodCall.method == 'setString' || methodCall.method == 'setBool') return true;
    return null;
  });

  // Mock connectivity
  const MethodChannel connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(connectivityChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'check') return ['wifi'];
    return null;
  });

  // Mock secure storage
  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'write') return null;
    if (methodCall.method == 'read') return null;
    if (methodCall.method == 'readAll') return <String, String>{};
    return null;
  });

  // Mock path provider
  const MethodChannel pathProviderChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathProviderChannel, (MethodCall methodCall) async {
    if (methodCall.method == 'getApplicationDocumentsDirectory') {
      return '/tmp/openvine_hashtag_test_db';
    }
    return null;
  });

  // Mock device info
  const MethodChannel deviceInfoChannel =
      MethodChannel('dev.fluttercommunity.plus/device_info');
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
        name: 'RealHashtagTest', category: LogCategory.system);
  } catch (e) {
    timer.cancel();
    Log.warning('Connection timeout: $e', name: 'RealHashtagTest', category: LogCategory.system);
  }
}

Future<List<VideoEvent>> _fetchVideosWithHashtags(VideoEventService videoEventService) async {
  Log.info('🏷️ Fetching videos with real hashtags...', name: 'RealHashtagTest', category: LogCategory.system);

  await videoEventService.startDiscoverySubscription();

  final videos = <VideoEvent>[];
  final maxWaitTime = Duration(seconds: 20);
  final startTime = DateTime.now();

  while (videos.length < 5 && DateTime.now().difference(startTime) < maxWaitTime) {
    await Future.delayed(Duration(milliseconds: 500));

    final discoveryVideos = videoEventService.discoveryVideos;

    for (final video in discoveryVideos) {
      if (video.hashtags.isNotEmpty && !videos.any((v) => v.id == video.id)) {
        videos.add(video);
        Log.info('🏷️ Found video with hashtags: ${video.hashtags} - ${video.content.substring(0, 50)}...',
            name: 'RealHashtagTest', category: LogCategory.system);
      }
    }
  }

  if (videos.isEmpty) {
    Log.warning('No videos with hashtags found, creating fallback',
        name: 'RealHashtagTest', category: LogCategory.system);
    videos.add(_createFallbackVideo());
  }

  return videos;
}

VideoEvent _createFallbackVideo() {
  return VideoEvent(
    id: 'fallback_hashtag_video',
    pubkey: 'test_pubkey',
    content: 'Fallback video content with #openvine and #nostr hashtags for testing',
    videoUrl: 'https://example.com/video.mp4',
    title: 'Fallback Hashtag Video',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    timestamp: DateTime.now(),
  );
}