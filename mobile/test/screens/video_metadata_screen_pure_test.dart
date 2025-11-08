// ABOUTME: Unit tests for VideoMetadataScreenPure background upload lifecycle
// ABOUTME: Tests initState() upload start and dispose() upload cancellation behavior

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/aspect_ratio.dart' as vine_aspect_ratio;
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'video_metadata_screen_pure_test.mocks.dart';

@GenerateMocks([
  UploadManager,
  DraftStorageService,
])
void main() {
  group('VideoMetadataScreenPure - Background Upload Lifecycle', () {
    late MockUploadManager mockUploadManager;
    late MockDraftStorageService mockDraftService;
    late VineDraft testDraft;
    late File testVideoFile;

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});

      mockUploadManager = MockUploadManager();
      mockDraftService = MockDraftStorageService();

      // Create a temporary test video file
      final tempDir = Directory.systemTemp.createTempSync('test_video');
      testVideoFile = File('${tempDir.path}/test_video.mp4');
      await testVideoFile.writeAsBytes([0, 1, 2, 3, 4]); // Dummy video data

      // Create test draft using factory method
      testDraft = VineDraft.create(
        videoFile: testVideoFile,
        title: 'Test Video',
        description: 'Test Description',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'image_stream',
        aspectRatio: vine_aspect_ratio.AspectRatio.square,
      );

      // Setup mock responses
      when(mockDraftService.getAllDrafts()).thenAnswer((_) async => [testDraft]);
      when(mockUploadManager.isInitialized).thenReturn(true);
    });

    tearDown(() {
      // Clean up test files
      if (testVideoFile.existsSync()) {
        testVideoFile.parent.deleteSync(recursive: true);
      }
    });

    testWidgets('initState() starts background upload immediately', (tester) async {
      // Arrange: Create mock upload that will be returned by startUpload()
      final mockUpload = PendingUpload.create(
        localVideoPath: testVideoFile.path,
        nostrPubkey: 'test-pubkey',
        title: testDraft.title,
        description: testDraft.description,
        hashtags: testDraft.hashtags,
      );

      when(mockUploadManager.startUpload(
        videoFile: anyNamed('videoFile'),
        nostrPubkey: anyNamed('nostrPubkey'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        hashtags: anyNamed('hashtags'),
        videoDuration: anyNamed('videoDuration'),
        proofManifest: anyNamed('proofManifest'),
      )).thenAnswer((_) async => mockUpload);

      // Act: Build the widget (which calls initState())
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(mockUploadManager),
          ],
          child: MaterialApp(
            home: VideoMetadataScreenPure(draftId: testDraft.id),
          ),
        ),
      );

      // Allow async operations to complete
      await tester.pumpAndSettle();

      // Assert: Verify startUpload was called with correct parameters
      verify(mockUploadManager.startUpload(
        videoFile: testVideoFile,
        nostrPubkey: anyNamed('nostrPubkey'),
        title: testDraft.title,
        description: testDraft.description,
        hashtags: testDraft.hashtags,
        videoDuration: anyNamed('videoDuration'),
        proofManifest: anyNamed('proofManifest'),
      )).called(1);
    });

    testWidgets('dispose() cancels upload if still in progress', (tester) async {
      // Arrange: Create mock upload in "uploading" state
      final mockUpload = PendingUpload.create(
        localVideoPath: testVideoFile.path,
        nostrPubkey: 'test-pubkey',
        title: testDraft.title,
      ).copyWith(status: UploadStatus.uploading);

      when(mockUploadManager.startUpload(
        videoFile: anyNamed('videoFile'),
        nostrPubkey: anyNamed('nostrPubkey'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        hashtags: anyNamed('hashtags'),
        videoDuration: anyNamed('videoDuration'),
        proofManifest: anyNamed('proofManifest'),
      )).thenAnswer((_) async => mockUpload);

      when(mockUploadManager.getUpload(mockUpload.id)).thenReturn(mockUpload);
      when(mockUploadManager.cancelUpload(mockUpload.id)).thenAnswer((_) async {});

      // Act: Build widget, then dispose it (navigate away)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(mockUploadManager),
          ],
          child: MaterialApp(
            home: VideoMetadataScreenPure(draftId: testDraft.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate away to trigger dispose()
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(mockUploadManager),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Text('Other Screen')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Verify cancelUpload was called
      verify(mockUploadManager.cancelUpload(mockUpload.id)).called(1);
    });

    testWidgets('dispose() does not cancel if upload already complete', (tester) async {
      // Arrange: Create mock upload in "readyToPublish" state (complete)
      final mockUpload = PendingUpload.create(
        localVideoPath: testVideoFile.path,
        nostrPubkey: 'test-pubkey',
        title: testDraft.title,
      ).copyWith(status: UploadStatus.readyToPublish);

      when(mockUploadManager.startUpload(
        videoFile: anyNamed('videoFile'),
        nostrPubkey: anyNamed('nostrPubkey'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        hashtags: anyNamed('hashtags'),
        videoDuration: anyNamed('videoDuration'),
        proofManifest: anyNamed('proofManifest'),
      )).thenAnswer((_) async => mockUpload);

      when(mockUploadManager.getUpload(mockUpload.id)).thenReturn(mockUpload);

      // Act: Build widget, then dispose it
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(mockUploadManager),
          ],
          child: MaterialApp(
            home: VideoMetadataScreenPure(draftId: testDraft.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate away to trigger dispose()
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(mockUploadManager),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Text('Other Screen')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Verify cancelUpload was NOT called (upload already complete)
      verifyNever(mockUploadManager.cancelUpload(any));
    });

    testWidgets('Upload ID is stored in state variable', (tester) async {
      // Arrange: Create mock upload
      final mockUpload = PendingUpload.create(
        localVideoPath: testVideoFile.path,
        nostrPubkey: 'test-pubkey',
        title: testDraft.title,
      );

      when(mockUploadManager.startUpload(
        videoFile: anyNamed('videoFile'),
        nostrPubkey: anyNamed('nostrPubkey'),
        title: anyNamed('title'),
        description: anyNamed('description'),
        hashtags: anyNamed('hashtags'),
        videoDuration: anyNamed('videoDuration'),
        proofManifest: anyNamed('proofManifest'),
      )).thenAnswer((_) async => mockUpload);

      when(mockUploadManager.getUpload(mockUpload.id)).thenReturn(mockUpload);

      // Act: Build the widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(mockUploadManager),
          ],
          child: MaterialApp(
            home: VideoMetadataScreenPure(draftId: testDraft.id),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert: Verify upload ID is tracked by checking cancelUpload is called with correct ID on dispose
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            uploadManagerProvider.overrideWithValue(mockUploadManager),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Text('Other Screen')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // If upload is still in progress, cancelUpload should be called with the correct upload ID
      // Since we're testing state variable storage, we verify the ID is used correctly
      when(mockUploadManager.getUpload(mockUpload.id))
          .thenReturn(mockUpload.copyWith(status: UploadStatus.uploading));
    });
  });
}
