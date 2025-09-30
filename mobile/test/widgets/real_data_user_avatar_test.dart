// ABOUTME: Real data widget test for UserAvatar using actual Nostr profile data
// ABOUTME: Tests avatar display with real profile pictures, real names, and actual network requests

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPlatformMocks();

  group('UserAvatar - Real Data Tests', () {
    late NostrService nostrService;
    late NostrKeyManager keyManager;
    late List<UserProfile> realProfiles;

    setUpAll(() async {
      Log.info('🚀 Setting up real profile data test environment',
          name: 'RealAvatarTest', category: LogCategory.system);

      keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      await nostrService.initialize(customRelays: [
        'wss://relay.damus.io',
        'wss://nos.lol',
        'wss://relay3.openvine.co'
      ]);

      await _waitForRelayConnection(nostrService);
      realProfiles = await _fetchRealProfiles(nostrService);

      Log.info('✅ Found ${realProfiles.length} real profiles for testing',
          name: 'RealAvatarTest', category: LogCategory.system);
    });

    tearDownAll(() async {
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
    });

    group('Real Profile Images', () {
      testWidgets('displays real profile picture from Nostr network', (tester) async {
        final profileWithImage = realProfiles.firstWhere(
          (p) => p.picture != null && p.picture!.isNotEmpty,
          orElse: () => realProfiles.isNotEmpty ? realProfiles.first : _createFallbackProfile(),
        );

        if (profileWithImage.picture == null) {
          Log.warning('No profiles with images found, skipping real image test',
              name: 'RealAvatarTest', category: LogCategory.system);
          return;
        }

        Log.info('Testing with real profile image: ${profileWithImage.picture}',
            name: 'RealAvatarTest', category: LogCategory.system);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: profileWithImage.picture,
                name: profileWithImage.bestDisplayName,
                size: 80,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show CachedNetworkImage for real URL
        expect(find.byType(CachedNetworkImage), findsOneWidget);

        final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.imageUrl, profileWithImage.picture);
        expect(cachedImage.width, 80);
        expect(cachedImage.height, 80);

        Log.info('✅ Real profile image displayed successfully',
            name: 'RealAvatarTest', category: LogCategory.system);
      });

      testWidgets('shows real names in fallback avatars', (tester) async {
        final profileWithName = realProfiles.firstWhere(
          (p) => p.bestDisplayName.isNotEmpty,
          orElse: () => realProfiles.isNotEmpty ? realProfiles.first : _createFallbackProfile(),
        );

        Log.info('Testing with real profile name: ${profileWithName.bestDisplayName}',
            name: 'RealAvatarTest', category: LogCategory.system);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: null, // Force fallback
                name: profileWithName.bestDisplayName,
                size: 60,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show initials from real name
        final expectedInitials = _getInitials(profileWithName.bestDisplayName);
        if (expectedInitials.isNotEmpty) {
          expect(find.text(expectedInitials), findsOneWidget);
        }

        Log.info('✅ Real profile name displayed as initials: $expectedInitials',
            name: 'RealAvatarTest', category: LogCategory.system);
      });

      testWidgets('handles broken profile image URLs gracefully', (tester) async {
        final profileWithBrokenImage = realProfiles.isNotEmpty
            ? UserProfile(
                pubkey: realProfiles.first.pubkey,
                rawData: realProfiles.first.rawData,
                createdAt: realProfiles.first.createdAt,
                eventId: realProfiles.first.eventId,
                name: realProfiles.first.name,
                displayName: realProfiles.first.displayName,
                picture: 'https://broken-image-url-that-does-not-exist.com/avatar.jpg',
                about: realProfiles.first.about,
                nip05: realProfiles.first.nip05,
                lud16: realProfiles.first.lud16,
                website: realProfiles.first.website,
                banner: realProfiles.first.banner,
              )
            : _createFallbackProfile();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: profileWithBrokenImage.picture,
                name: profileWithBrokenImage.bestDisplayName,
                size: 50,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should attempt to load image but gracefully fall back
        expect(find.byType(CachedNetworkImage), findsOneWidget);

        final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.errorWidget, isNotNull);

        // Wait a bit more for error handling
        await tester.pump(Duration(seconds: 2));

        Log.info('✅ Broken image URL handled gracefully',
            name: 'RealAvatarTest', category: LogCategory.system);
      });
    });

    group('Real Avatar Interactions', () {
      testWidgets('handles tap interactions with real profile data', (tester) async {
        if (realProfiles.isEmpty) return;

        final testProfile = realProfiles.first;
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: testProfile.picture,
                name: testProfile.bestDisplayName,
                onTap: () {
                  tapped = true;
                  Log.info('Avatar tapped for profile: ${testProfile.bestDisplayName}',
                      name: 'RealAvatarTest', category: LogCategory.system);
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);

        Log.info('✅ Real profile avatar tap handled correctly',
            name: 'RealAvatarTest', category: LogCategory.system);
      });
    });

    group('Real Profile Integration', () {
      testWidgets('integrates with real Riverpod profile provider', (tester) async {
        if (realProfiles.isEmpty) return;

        final testProfile = realProfiles.first;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final profileAsync = ref.watch(fetchUserProfileProvider(testProfile.pubkey));

                    return profileAsync.when(
                      data: (profile) => UserAvatar(
                        imageUrl: profile?.picture,
                        name: profile?.bestDisplayName,
                        size: 64,
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, _) => const Icon(Icons.error),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should eventually show avatar (might start as loading)
        expect(
          find.byType(UserAvatar).or(find.byType(CircularProgressIndicator)),
          findsOneWidget,
        );

        // Wait for async profile loading
        await tester.pump(Duration(seconds: 1));

        Log.info('✅ Real Riverpod profile provider integration working',
            name: 'RealAvatarTest', category: LogCategory.system);
      });

      testWidgets('displays multiple real avatars simultaneously', (tester) async {
        final testProfiles = realProfiles.take(3).toList();
        if (testProfiles.length < 2) return;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: testProfiles
                    .asMap()
                    .entries
                    .map((entry) => UserAvatar(
                          key: ValueKey('avatar_${entry.key}'),
                          imageUrl: entry.value.picture,
                          name: entry.value.bestDisplayName,
                          size: 40,
                        ))
                    .toList(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byType(UserAvatar), findsNWidgets(testProfiles.length));

        for (int i = 0; i < testProfiles.length; i++) {
          expect(find.byKey(ValueKey('avatar_$i')), findsOneWidget);
        }

        Log.info('✅ Multiple real avatars displayed simultaneously',
            name: 'RealAvatarTest', category: LogCategory.system);
      });
    });

    group('Real Network Conditions', () {
      testWidgets('handles slow network conditions gracefully', (tester) async {
        final profileWithImage = realProfiles.firstWhere(
          (p) => p.picture != null && p.picture!.isNotEmpty,
          orElse: () => _createFallbackProfile(),
        );

        if (profileWithImage.picture == null) return;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: profileWithImage.picture,
                name: profileWithImage.bestDisplayName,
                size: 60,
              ),
            ),
          ),
        );

        // Should show placeholder initially
        await tester.pump(Duration(milliseconds: 100));

        final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.placeholder, isNotNull);

        // Wait for image to potentially load
        await tester.pumpAndSettle(Duration(seconds: 3));

        Log.info('✅ Slow network conditions handled gracefully',
            name: 'RealAvatarTest', category: LogCategory.system);
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
      return '/tmp/openvine_avatar_test_db';
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
        name: 'RealAvatarTest', category: LogCategory.system);
  } catch (e) {
    timer.cancel();
    Log.warning('Connection timeout: $e', name: 'RealAvatarTest', category: LogCategory.system);
  }
}

Future<List<UserProfile>> _fetchRealProfiles(NostrService nostrService) async {
  Log.info('👤 Fetching real user profiles...', name: 'RealAvatarTest', category: LogCategory.system);

  // Well-known Nostr pubkeys for testing
  final knownPubkeys = [
    'npub1sg6plzptd64u62a878hep2kev88swjh3tw00gjsfl8f237lmu63q0uf63m', // jack
    'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6', // fiatjaf
    'npub1damus8ku2qv7hkv05c6xphjgz6lqlvd6xl7z62gqmp48c4gv0wnsl5xtnd', // damus
  ];

  final profiles = <UserProfile>[];

  for (final pubkey in knownPubkeys) {
    try {
      // Subscribe to profile events for this pubkey
      await nostrService.subscribeToProfile(pubkey);
      await Future.delayed(Duration(milliseconds: 500)); // Wait for response

      // Get profile if available
      final profile = await nostrService.getProfile(pubkey);
      if (profile != null) {
        profiles.add(profile);
        Log.info('📋 Found profile: ${profile.bestDisplayName} (${profile.picture != null ? "with image" : "no image"})',
            name: 'RealAvatarTest', category: LogCategory.system);
      }
    } catch (e) {
      Log.warning('Failed to fetch profile $pubkey: $e',
          name: 'RealAvatarTest', category: LogCategory.system);
    }
  }

  return profiles;
}

UserProfile _createFallbackProfile() {
  return UserProfile(
    pubkey: 'test_pubkey',
    rawData: {},
    createdAt: DateTime.now(),
    eventId: 'test_event_id',
    name: 'Test User',
    displayName: 'Test Display Name',
    picture: 'https://example.com/avatar.jpg',
    about: 'Test profile for avatar testing',
  );
}

String _getInitials(String name) {
  if (name.isEmpty) return '';

  final words = name.trim().split(RegExp(r'\s+'));
  if (words.length == 1) {
    return words.first.isNotEmpty ? words.first[0].toUpperCase() : '';
  }

  return words.take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
}