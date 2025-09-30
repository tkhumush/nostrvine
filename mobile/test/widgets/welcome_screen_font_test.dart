// ABOUTME: Widget test for welcome screen Google Font rendering
// ABOUTME: Verifies that the diVine title uses Pacifico font

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/auth_service.dart';

@GenerateMocks([AuthService])
import 'welcome_screen_font_test.mocks.dart';

void main() {
  group('WelcomeScreen Font Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
    });

    testWidgets('diVine title uses Pacifico Google Font', (tester) async {
      // Set larger test size to prevent overflow
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      // Build the widget with provider override
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: WelcomeScreen(),
          ),
        ),
      );

      // Allow font loading to complete (will use fallback in tests)
      await tester.pumpAndSettle();

      // Find the title text widget
      final titleFinder = find.text('Welcome to diVine');
      expect(titleFinder, findsOneWidget);

      // Get the Text widget
      final Text titleWidget = tester.widget(titleFinder);

      // Verify the style uses Pacifico font family
      expect(titleWidget.style, isNotNull);
      expect(titleWidget.style!.fontFamily, contains('Pacifico'));

      // Verify other style properties
      expect(titleWidget.style!.fontSize, equals(32));
      expect(titleWidget.style!.color, equals(Colors.white));
    });

    testWidgets('Welcome screen layout renders correctly', (tester) async {
      // Set larger test size to prevent overflow
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: const MaterialApp(
            home: WelcomeScreen(),
          ),
        ),
      );

      // Allow font loading to complete (will use fallback in tests)
      await tester.pumpAndSettle();

      // Verify key elements are present
      expect(find.text('Welcome to diVine'), findsOneWidget);
      expect(find.text('Create and share short videos on the decentralized web'), findsOneWidget);
      expect(find.text('Create New Identity'), findsOneWidget);
      expect(find.text('Import Existing Identity'), findsOneWidget);
      expect(find.text('What is Nostr?'), findsOneWidget);
    });
  });
}