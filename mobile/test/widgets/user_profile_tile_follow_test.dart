import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/optimistic_follow_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

class MockAuthService extends Mock implements AuthService {}
class MockSocialService extends Mock implements SocialService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserProfileTile follow button', () {
    late MockAuthService mockAuth;
    late MockSocialService mockSocial;

    setUp(() {
      mockAuth = MockAuthService();
      mockSocial = MockSocialService();

      when(mockAuth.isAuthenticated).thenReturn(true);
      when(mockAuth.currentPublicKeyHex).thenReturn('current_user');
      when(mockSocial.isFollowing(any)).thenReturn(false);
      when(mockSocial.followUser(any)).thenAnswer((_) async {});
      when(mockSocial.unfollowUser(any)).thenAnswer((_) async {});
    });

    Widget build(String pubkey) {
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(mockAuth),
        socialServiceProvider.overrideWithValue(mockSocial),
      ]);
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );
    }

    testWidgets('tapping Follow uses optimistic updates and calls service',
        (tester) async {
      final pubkey = 'target_user_1';

      // Build a provider scope with our mocks
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(mockAuth),
        socialServiceProvider.overrideWithValue(mockSocial),
      ]);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: UserProfileTile(pubkey: pubkey),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially shows Follow
      expect(find.text('Follow'), findsOneWidget);

      // Tap Follow
      await tester.tap(find.text('Follow'));
      await tester.pump();

      // Optimistic state should switch to Following immediately
      expect(find.text('Following'), findsOneWidget);

      // Service should be called
      verify(mockSocial.followUser(pubkey)).called(1);
    });
  });
}
