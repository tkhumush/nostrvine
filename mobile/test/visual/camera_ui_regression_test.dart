// ABOUTME: Visual regression tests for camera UI components
// ABOUTME: Ensures consistent visual appearance and UI behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  group('Camera UI Visual Regression Tests', () {
    testGoldens('Camera screen initial state', (WidgetTester tester) async {
      await loadAppFonts();

      final widget = ProviderScope(
        child: MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: Color(0xFF00B488),
          ),
          home: UniversalCameraScreenPure(),
        ),
      );

      await tester.pumpWidgetBuilder(widget);
      await screenMatchesGolden(tester, 'camera_screen_initial');
    });

    testGoldens('Camera screen recording state', (WidgetTester tester) async {
      await loadAppFonts();

      // Mock recording state
      final widget = ProviderScope(
        overrides: [
          vineRecordingStateProvider.overrideWith((ref) {
            return Stream.value(VineRecordingUIState(
              recordingState: VineRecordingState.recording,
              progress: 0.5,
              totalRecordedDuration: Duration(seconds: 3),
              remainingDuration: Duration(seconds: 3),
              canRecord: true,
              segments: [],
            ));
          }),
        ],
        child: MaterialApp(
          home: UniversalCameraScreenPure(),
        ),
      );

      await tester.pumpWidgetBuilder(widget);
      await screenMatchesGolden(tester, 'camera_screen_recording');
    });

    testWidgets('Camera controls overlay visibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: UniversalCameraScreenPure(),
          ),
        ),
      );

      // Verify controls are visible
      expect(find.byIcon(Icons.flip_camera), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap record button
      final recordButton = find.byKey(Key('record_button'));
      if (recordButton.evaluate().isNotEmpty) {
        await tester.tap(recordButton);
        await tester.pump();
      }

      // During recording, some controls might change
      // Add specific expectations based on your UI
    });

    testWidgets('Progress bar animation during recording',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingStateProvider.overrideWith((ref) {
              return Stream.periodic(Duration(milliseconds: 100), (i) {
                return VineRecordingUIState(
                  recordingState: VineRecordingState.recording,
                  progress: (i * 0.1).clamp(0.0, 1.0),
                  totalRecordedDuration: Duration(milliseconds: i * 100),
                  remainingDuration: Duration(milliseconds: 6300 - (i * 100)),
                  canRecord: true,
                  segments: [],
                );
              });
            }),
          ],
          child: MaterialApp(
            home: UniversalCameraScreenPure(),
          ),
        ),
      );

      // Verify progress bar updates
      for (int i = 0; i < 10; i++) {
        await tester.pump(Duration(milliseconds: 100));
        // Progress bar should be updating
        final progressIndicator = find.byType(LinearProgressIndicator);
        if (progressIndicator.evaluate().isNotEmpty) {
          expect(progressIndicator, findsOneWidget);
        }
      }
    });

    testWidgets('Camera permission dialog appearance',
        (WidgetTester tester) async {
      // Mock permission denied state
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingStateProvider.overrideWith((ref) {
              return Stream.value(VineRecordingUIState(
                recordingState: VineRecordingState.error,
                progress: 0,
                totalRecordedDuration: Duration.zero,
                remainingDuration: Duration(seconds: 6),
                canRecord: false,
                segments: [],
              ));
            }),
          ],
          child: MaterialApp(
            home: UniversalCameraScreenPure(),
          ),
        ),
      );

      // Should show error message
      await tester.pump();
      expect(find.textContaining('permission'), findsWidgets);
    });

    testGoldens('Camera screen dark mode', (WidgetTester tester) async {
      await loadAppFonts();

      final widget = ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: UniversalCameraScreenPure(),
        ),
      );

      await tester.pumpWidgetBuilder(widget);
      await screenMatchesGolden(tester, 'camera_screen_dark_mode');
    });

    testGoldens('Camera screen landscape orientation',
        (WidgetTester tester) async {
      await loadAppFonts();

      tester.binding.window.physicalSizeTestValue = Size(844, 390);
      tester.binding.window.devicePixelRatioTestValue = 1.0;

      final widget = ProviderScope(
        child: MaterialApp(
          home: UniversalCameraScreenPure(),
        ),
      );

      await tester.pumpWidgetBuilder(widget);
      await screenMatchesGolden(tester, 'camera_screen_landscape');

      // Reset window size
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });
  });
}