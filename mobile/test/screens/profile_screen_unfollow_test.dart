// ABOUTME: TDD test for profile screen unfollow functionality
// ABOUTME: Tests that the unfollow button correctly removes user from contact list

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/screens/profile_screen_scrollable.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/nostr_service_interface.dart';

import 'profile_screen_unfollow_test.mocks.dart';

@GenerateMocks([
  INostrService,
  AuthService,
  SubscriptionManager,
  SocialService,
])
void main() {
  group('Profile Screen Unfollow Tests (TDD)', () {
    late MockINostrService mockNostrService;
    late MockAuthService mockAuthService;
    late MockSocialService mockSocialService;

    setUp(() {
      mockNostrService = MockINostrService();
      mockAuthService = MockAuthService();
      mockSocialService = MockSocialService();

      // Setup default mock behaviors
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockNostrService.isInitialized).thenReturn(true);
    });

    testWidgets('RED: Unfollow button should trigger unfollowUser when tapped',
        (WidgetTester tester) async {
      const profilePubkey = 'target_user_pubkey_456';
      const currentUserPubkey = 'current_user_pubkey_123';

      // Setup: User is following the target
      when(mockSocialService.isFollowing(profilePubkey)).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(currentUserPubkey);
      when(mockSocialService.unfollowUser(profilePubkey)).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProfileScreenScrollable(
                profilePubkey: profilePubkey,
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Find the Following button
      final followingButton = find.widgetWithText(ElevatedButton, 'Following');
      expect(followingButton, findsOneWidget);

      // Tap the Following button to unfollow
      await tester.tap(followingButton);
      await tester.pump();

      // Verify unfollowUser was called
      verify(mockSocialService.unfollowUser(profilePubkey)).called(1);
    });

    testWidgets('GREEN: Follow button should trigger followUser when tapped',
        (WidgetTester tester) async {
      const profilePubkey = 'target_user_pubkey_789';
      const currentUserPubkey = 'current_user_pubkey_123';

      // Setup: User is NOT following the target
      when(mockSocialService.isFollowing(profilePubkey)).thenReturn(false);
      when(mockAuthService.currentPublicKeyHex).thenReturn(currentUserPubkey);
      when(mockSocialService.followUser(profilePubkey)).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProfileScreenScrollable(
                profilePubkey: profilePubkey,
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Find the Follow button
      final followButton = find.widgetWithText(ElevatedButton, 'Follow');
      expect(followButton, findsOneWidget);

      // Tap the Follow button
      await tester.tap(followButton);
      await tester.pump();

      // Verify followUser was called
      verify(mockSocialService.followUser(profilePubkey)).called(1);
    });

    testWidgets('REFACTOR: Button should update UI after successful unfollow',
        (WidgetTester tester) async {
      const profilePubkey = 'target_user_pubkey_abc';
      const currentUserPubkey = 'current_user_pubkey_123';

      // Start with user following the target
      var isFollowing = true;
      when(mockSocialService.isFollowing(profilePubkey))
          .thenAnswer((_) => isFollowing);
      when(mockAuthService.currentPublicKeyHex).thenReturn(currentUserPubkey);

      // Setup unfollowUser to update the state
      when(mockSocialService.unfollowUser(profilePubkey)).thenAnswer((_) async {
        isFollowing = false;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProfileScreenScrollable(
                profilePubkey: profilePubkey,
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Initially shows "Following"
      expect(find.widgetWithText(ElevatedButton, 'Following'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Follow'), findsNothing);

      // Tap to unfollow
      await tester.tap(find.widgetWithText(ElevatedButton, 'Following'));
      await tester.pumpAndSettle();

      // After unfollow, should show "Follow"
      expect(find.widgetWithText(ElevatedButton, 'Follow'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Following'), findsNothing);
    });

    testWidgets('ERROR HANDLING: Show error if unfollow fails',
        (WidgetTester tester) async {
      const profilePubkey = 'target_user_pubkey_xyz';
      const currentUserPubkey = 'current_user_pubkey_123';

      when(mockSocialService.isFollowing(profilePubkey)).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(currentUserPubkey);
      when(mockSocialService.unfollowUser(profilePubkey))
          .thenThrow(Exception('Network error'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProfileScreenScrollable(
                profilePubkey: profilePubkey,
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Tap unfollow button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Following'));
      await tester.pumpAndSettle();

      // Should show error in snackbar
      expect(find.textContaining('Failed to unfollow user'), findsOneWidget);
    });

    testWidgets('EDGE CASE: Cannot follow/unfollow when not authenticated',
        (WidgetTester tester) async {
      const profilePubkey = 'target_user_pubkey_def';

      // Setup: User is not authenticated
      when(mockAuthService.isAuthenticated).thenReturn(false);
      when(mockAuthService.currentPublicKeyHex).thenReturn(null);
      when(mockSocialService.isFollowing(profilePubkey)).thenReturn(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
            nostrServiceProvider.overrideWithValue(mockNostrService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ProfileScreenScrollable(
                profilePubkey: profilePubkey,
              ),
            ),
          ),
        ),
      );

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Follow button should be disabled or show login prompt
      final followButton = find.widgetWithText(ElevatedButton, 'Follow');
      if (followButton.evaluate().isNotEmpty) {
        await tester.tap(followButton);
        await tester.pumpAndSettle();

        // Should show authentication required message
        expect(find.text('Please login to follow users'), findsOneWidget);
      }
    });

  });
}