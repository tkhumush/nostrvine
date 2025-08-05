// ABOUTME: Test bookmark service persistence across restarts using embedded relay
// ABOUTME: Verifies that bookmarks are properly saved to and loaded from Nostr events

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';

// Create mock classes
class MockNostrService extends Mock implements INostrService {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  group('BookmarkService Persistence Tests', () {
    late MockNostrService mockNostrService;
    late MockAuthService mockAuthService;
    late SharedPreferences mockPrefs;
    
    const testPubkey = '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const testVideoId = 'test-video-event-id-12345';

    setUp(() async {
      mockNostrService = MockNostrService();
      mockAuthService = MockAuthService();
      
      // Use real SharedPreferences in memory mode for testing
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();

      // Setup auth service mock
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
    });

    test('should persist bookmarks across service restarts', () async {
      // === PHASE 1: Create bookmark and simulate persistence ===
      
      // Mock embedded relay returning no existing events initially
      when(mockNostrService.getEvents(filters: any))
          .thenAnswer((_) async => []);
      
      // Mock successful broadcast
      when(mockNostrService.broadcastEvent(any))
          .thenAnswer((_) async => NostrBroadcastResult(
            event: Event.fromJson({
              'id': 'test-id',
              'pubkey': testPubkey,
              'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              'kind': 10003,
              'tags': [],
              'content': '',
              'sig': 'test-sig',
            }),
            successCount: 1,
            totalRelays: 1,
            results: {'relay-url': true},
            errors: {},
          ));

      // Create first service instance and add bookmark
      final service1 = BookmarkService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: mockPrefs,
      );
      
      await service1.initialize();
      
      // Add a bookmark
      final success = await service1.addVideoToGlobalBookmarks(testVideoId);
      expect(success, isTrue);
      expect(service1.isVideoBookmarkedGlobally(testVideoId), isTrue);

      // === PHASE 2: Simulate app restart with embedded relay having the event ===
      
      // Create mock NIP-51 bookmark event that would be returned by embedded relay
      final mockBookmarkEvent = Event.fromJson({
        'id': 'bookmark-event-id-12345',
        'pubkey': testPubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 10003, // NIP-51 global bookmarks
        'tags': [
          ['client', 'openvine'],
          ['e', testVideoId], // Our bookmarked video
        ],
        'content': 'OpenVine global bookmarks',
        'sig': 'mock-signature',
      });

      // Mock embedded relay returning our bookmark event
      when(mockNostrService.getEvents(filters: any))
          .thenAnswer((_) async => [mockBookmarkEvent]);

      // Create second service instance (simulates app restart)
      final service2 = BookmarkService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: mockPrefs,
      );
      
      await service2.initialize();

      // === PHASE 3: Verify bookmark was restored from embedded relay ===
      
      expect(service2.isVideoBookmarkedGlobally(testVideoId), isTrue,
          reason: 'Bookmark should be restored from embedded relay after restart');
      
      expect(service2.globalBookmarks.length, equals(1),
          reason: 'Should have exactly one global bookmark');
      
      expect(service2.globalBookmarks.first.id, equals(testVideoId),
          reason: 'Restored bookmark should have correct video ID');
      
      expect(service2.globalBookmarks.first.type, equals('e'),
          reason: 'Restored bookmark should have correct type');

      // Verify the embedded relay was queried for our events
      verify(mockNostrService.getEvents(
        filters: argThat(
          isA<List<Filter>>()
              .having((filters) => filters.first.authors, 'authors', contains(testPubkey)),
        ),
      )).called(greaterThan(0));
    });

    test('should handle empty embedded relay gracefully', () async {
      // Mock empty embedded relay
      when(mockNostrService.getEvents(filters: any))
          .thenAnswer((_) async => []);

      final service = BookmarkService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: mockPrefs,
      );
      
      await service.initialize();

      expect(service.globalBookmarks.isEmpty, isTrue,
          reason: 'Should handle empty embedded relay without errors');
    });

    test('should handle malformed events gracefully', () async {
      // Create malformed event (missing required tags)
      final malformedEvent = Event.fromJson({
        'id': 'malformed-event-id',
        'pubkey': testPubkey,
        'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'kind': 10003,
        'tags': [], // No bookmark tags
        'content': 'Empty bookmarks',
        'sig': 'mock-signature',
      });

      when(mockNostrService.getEvents(filters: any))
          .thenAnswer((_) async => [malformedEvent]);

      final service = BookmarkService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: mockPrefs,
      );
      
      await service.initialize();

      expect(service.globalBookmarks.isEmpty, isTrue,
          reason: 'Should handle malformed events without crashing');
    });

    test('should use latest bookmark event when multiple exist', () async {
      final oldTimestamp = DateTime.now().subtract(Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final newTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Old bookmark event
      final oldEvent = Event.fromJson({
        'id': 'old-bookmark-event',
        'pubkey': testPubkey,
        'created_at': oldTimestamp,
        'kind': 10003,
        'tags': [
          ['client', 'openvine'],
          ['e', 'old-video-id'],
        ],
        'content': 'Old bookmarks',
        'sig': 'mock-signature-1',
      });

      // New bookmark event (should take precedence)
      final newEvent = Event.fromJson({
        'id': 'new-bookmark-event',
        'pubkey': testPubkey,
        'created_at': newTimestamp,
        'kind': 10003,
        'tags': [
          ['client', 'openvine'],
          ['e', testVideoId],
        ],
        'content': 'New bookmarks',
        'sig': 'mock-signature-2',
      });

      when(mockNostrService.getEvents(filters: any))
          .thenAnswer((_) async => [oldEvent, newEvent]); // Return both events

      final service = BookmarkService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: mockPrefs,
      );
      
      await service.initialize();

      expect(service.globalBookmarks.length, equals(1),
          reason: 'Should only use latest bookmark event');
      
      expect(service.globalBookmarks.first.id, equals(testVideoId),
          reason: 'Should use bookmark from latest event');
      
      expect(service.isVideoBookmarkedGlobally('old-video-id'), isFalse,
          reason: 'Should not include bookmarks from older events');
    });
  });
}