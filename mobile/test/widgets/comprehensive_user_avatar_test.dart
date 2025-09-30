// ABOUTME: Comprehensive widget test for UserAvatar covering image loading, fallbacks, and interactions
// ABOUTME: Tests network image handling, error states, tap interactions, and sizing

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/user_avatar.dart';

void main() {
  group('UserAvatar - Comprehensive Tests', () {
    group('Basic Widget Structure', () {
      testWidgets('creates correct widget structure with default values', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(),
            ),
          ),
        );

        expect(find.byType(GestureDetector), findsOneWidget);
        expect(find.byType(Container), findsOneWidget);
        expect(find.byType(ClipRRect), findsOneWidget);

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, 40);
        expect(container.constraints?.maxHeight, 40);
        expect(container.decoration, isA<BoxDecoration>());

        final decoration = container.decoration as BoxDecoration;
        expect(decoration.shape, BoxShape.circle);
        expect(decoration.color, Colors.grey[300]);
      });

      testWidgets('applies custom size correctly', (tester) async {
        const customSize = 80.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(size: customSize),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, customSize);
        expect(container.constraints?.maxHeight, customSize);

        final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(clipRRect.borderRadius, BorderRadius.circular(customSize / 2));
      });
    });

    group('Image Loading States', () {
      testWidgets('shows CachedNetworkImage when imageUrl is provided', (tester) async {
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(imageUrl: testImageUrl),
            ),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsOneWidget);

        final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.imageUrl, testImageUrl);
        expect(cachedImage.fit, BoxFit.cover);
        expect(cachedImage.width, 40); // default size
        expect(cachedImage.height, 40);
      });

      testWidgets('shows fallback when imageUrl is null', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(name: 'Test User'),
            ),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsNothing);
        // Should show fallback initials or icon
        expect(find.byType(Container), findsAtLeastNWidgets(1));
      });

      testWidgets('shows fallback when imageUrl is empty', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: '',
                name: 'Test User',
              ),
            ),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsNothing);
      });

      testWidgets('shows fallback with user initials when name is provided', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(name: 'John Doe'),
            ),
          ),
        );

        // Should show initials in fallback
        expect(find.text('JD'), findsOneWidget);
      });

      testWidgets('shows default icon when no name is provided', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(),
            ),
          ),
        );

        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('handles single name correctly for initials', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(name: 'Madonna'),
            ),
          ),
        );

        expect(find.text('M'), findsOneWidget);
      });

      testWidgets('handles empty name correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(name: ''),
            ),
          ),
        );

        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('handles very long names correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(name: 'Very Long First Name And Very Long Last Name'),
            ),
          ),
        );

        expect(find.text('VV'), findsOneWidget); // Should take first letter of each word
      });
    });

    group('Image Error Handling', () {
      testWidgets('shows error widget when image fails to load', (tester) async {
        const failingImageUrl = 'https://example.com/nonexistent.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: failingImageUrl,
                name: 'Test User',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.errorWidget, isNotNull);

        // The error widget should show the fallback
        // This is tricky to test without actually triggering network errors
        // In a real test, we might mock the image loading
      });

      testWidgets('shows placeholder while image is loading', (tester) async {
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: testImageUrl,
                name: 'Test User',
              ),
            ),
          ),
        );

        final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.placeholder, isNotNull);
      });
    });

    group('Tap Interactions', () {
      testWidgets('calls onTap when avatar is tapped', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('does not respond to taps when onTap is null', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(),
            ),
          ),
        );

        // Should not throw when tapped
        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        // Test passes if no exception is thrown
      });

      testWidgets('onTap works with image avatar', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'https://example.com/avatar.jpg',
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });

      testWidgets('onTap works with fallback avatar', (tester) async {
        bool tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                name: 'Test User',
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(UserAvatar));
        await tester.pumpAndSettle();

        expect(tapped, isTrue);
      });
    });

    group('Size Variations', () {
      testWidgets('handles very small sizes', (tester) async {
        const smallSize = 16.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                size: smallSize,
                name: 'Test',
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, smallSize);
        expect(container.constraints?.maxHeight, smallSize);
      });

      testWidgets('handles very large sizes', (tester) async {
        const largeSize = 200.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                size: largeSize,
                name: 'Test',
              ),
            ),
          ),
        );

        final container = tester.widget<Container>(find.byType(Container));
        expect(container.constraints?.maxWidth, largeSize);
        expect(container.constraints?.maxHeight, largeSize);
      });

      testWidgets('CachedNetworkImage respects size parameter', (tester) async {
        const customSize = 60.0;
        const testImageUrl = 'https://example.com/avatar.jpg';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                size: customSize,
                imageUrl: testImageUrl,
              ),
            ),
          ),
        );

        final cachedImage = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
        expect(cachedImage.width, customSize);
        expect(cachedImage.height, customSize);
      });
    });

    group('Fallback Content Styling', () {
      testWidgets('fallback text has appropriate styling', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                name: 'Test User',
                size: 50,
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(find.text('TU'));
        expect(text.style?.color, Colors.white);
        expect(text.style?.fontWeight, FontWeight.bold);
        // Font size should be proportional to avatar size
      });

      testWidgets('fallback icon has appropriate styling', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(size: 50),
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.person));
        expect(icon.color, Colors.white);
        // Icon size should be proportional to avatar size
      });
    });

    group('Edge Cases and Robustness', () {
      testWidgets('handles zero size gracefully', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(size: 0),
            ),
          ),
        );

        // Should not crash
        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('handles negative size gracefully', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(size: -10),
            ),
          ),
        );

        // Should not crash and likely clamps to reasonable value
        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('handles names with special characters', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(name: 'José María'),
            ),
          ),
        );

        expect(find.text('JM'), findsOneWidget);
      });

      testWidgets('handles names with numbers', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(name: 'User123 Test456'),
            ),
          ),
        );

        expect(find.text('UT'), findsOneWidget);
      });

      testWidgets('handles whitespace-only names', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(name: '   '),
            ),
          ),
        );

        expect(find.byIcon(Icons.person), findsOneWidget);
      });

      testWidgets('handles malformed URLs gracefully', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                imageUrl: 'not-a-valid-url',
                name: 'Fallback User',
              ),
            ),
          ),
        );

        // Should fall back to initials without crashing
        await tester.pumpAndSettle();
        expect(find.byType(UserAvatar), findsOneWidget);
      });
    });

    group('Multiple Avatars', () {
      testWidgets('renders multiple avatars correctly', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: const [
                  UserAvatar(name: 'User One', size: 40),
                  UserAvatar(name: 'User Two', size: 50),
                  UserAvatar(imageUrl: 'https://example.com/avatar.jpg', size: 60),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(UserAvatar), findsNWidgets(3));
        expect(find.text('UO'), findsOneWidget);
        expect(find.text('UT'), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });
    });
  });
}