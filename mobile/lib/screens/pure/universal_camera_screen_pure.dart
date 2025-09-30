// ABOUTME: Pure universal camera screen using revolutionary Riverpod architecture
// ABOUTME: Cross-platform recording without VideoManager dependencies using pure providers

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_overlay_manager_provider.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/macos_camera_preview.dart' show CameraPreviewPlaceholder;

/// Pure universal camera screen using revolutionary single-controller Riverpod architecture
class UniversalCameraScreenPure extends ConsumerStatefulWidget {
  const UniversalCameraScreenPure({super.key});

  @override
  ConsumerState<UniversalCameraScreenPure> createState() => _UniversalCameraScreenPureState();
}

class _UniversalCameraScreenPureState extends ConsumerState<UniversalCameraScreenPure> {
  String? _errorMessage;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();

    // Pause all background videos when entering camera screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final videoManager = ref.read(videoOverlayManagerProvider);
        videoManager.pauseAllVideos();
        Log.info('📹 UniversalCameraScreenPure: Paused background videos', category: LogCategory.video);
      } catch (e) {
        Log.warning('📹 Failed to pause background videos: $e', category: LogCategory.video);
      }
    });

    Log.info('📹 UniversalCameraScreenPure: Initialized', category: LogCategory.video);
  }

  @override
  void dispose() {
    // Provider handles disposal automatically
    super.dispose();

    Log.info('📹 UniversalCameraScreenPure: Disposed', category: LogCategory.video);
  }

  Future<void> _initializeServices() async {
    try {
      // Use post-frame callback to avoid provider modification during build
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          // Initialize the recording service
          await ref.read(vineRecordingProvider.notifier).initialize();
        } catch (e) {
          Log.error('📹 UniversalCameraScreenPure: Failed to initialize recording: $e',
              category: LogCategory.video);

          if (mounted) {
            setState(() {
              _errorMessage = 'Failed to initialize camera: $e';
            });
          }
        }
      });
    } catch (e) {
      Log.error('📹 UniversalCameraScreenPure: Initialization error: $e',
          category: LogCategory.video);

      setState(() {
        _errorMessage = 'Initialization failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('back-button'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Record Video',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final recordingState = ref.watch(vineRecordingProvider);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: recordingState.isRecording
                    ? Colors.red.withValues(alpha: 0.7)
                    : Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      recordingState.isRecording ? Icons.fiber_manual_record : Icons.videocam,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      recordingState.isRecording
                        ? _formatDuration(recordingState.recordingDuration)
                        : 'Ready',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final recordingState = ref.watch(vineRecordingProvider);

          // Listen for auto-stop (when recording stops without user action)
          ref.listen<VineRecordingUIState>(vineRecordingProvider, (previous, next) {
            if (previous != null && previous.isRecording && !next.isRecording && !_isProcessing) {
              // Recording stopped automatically (timer reached max duration)
              Log.info('📹 Recording auto-stopped, processing result', category: LogCategory.video);
              _handleRecordingAutoStop();
            }
          });

          if (recordingState.isError) {
            return _buildErrorScreen(recordingState.errorMessage);
          }

          if (!recordingState.isInitialized) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              // Camera preview (fullscreen)
              Positioned.fill(
                child: recordingState.isInitialized
                  ? ref.read(vineRecordingProvider.notifier).previewWidget
                  : CameraPreviewPlaceholder(
                      isRecording: recordingState.isRecording,
                    ),
              ),

              // Recording controls overlay (bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: _buildRecordingControls(recordingState),
                ),
              ),

              // Camera controls (top right)
              if (recordingState.isInitialized && !recordingState.isRecording)
                Positioned(
                  top: 16,
                  right: 16,
                  child: _buildCameraControls(recordingState),
                ),

              // Processing overlay
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'Processing video...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorScreen([String? customMessage]) {
    final message = customMessage ?? _errorMessage ?? 'Unknown error occurred';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Camera Error', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retryInitialization,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingControls(dynamic recordingState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Cancel/Back button (when not recording) OR Publish button (when recording)
        IconButton(
          onPressed: recordingState.isRecording
            ? () {
                // Stop and publish immediately
                Log.info('📹 Publish button pressed', category: LogCategory.video);
                _toggleRecording(); // This will stop recording and navigate to metadata
              }
            : () {
                Navigator.of(context).pop();
              },
          icon: Icon(
            recordingState.isRecording ? Icons.check_circle : Icons.close,
            color: recordingState.isRecording ? Colors.green : Colors.white,
            size: recordingState.isRecording ? 40 : 32,
          ),
        ),

        // Record button
        GestureDetector(
          onTap: recordingState.isRecording ? null : _toggleRecording,  // Disable while recording
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recordingState.isRecording ? Colors.red : Colors.white,
              border: Border.all(
                color: recordingState.isRecording ? Colors.white : Colors.grey,
                width: 4,
              ),
            ),
            child: recordingState.isRecording
              ? Center(
                  child: Text(
                    _formatDuration(recordingState.recordingDuration),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : const Icon(
                  Icons.fiber_manual_record,
                  color: Colors.red,
                  size: 32,
                ),
          ),
        ),

        // Switch camera button
        IconButton(
          onPressed: recordingState.isRecording ? null : _switchCamera,
          icon: Icon(
            Icons.flip_camera_ios,
            color: recordingState.isRecording ? Colors.grey : Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildCameraControls(dynamic recordingState) {
    return Column(
      children: [
        // Flash toggle
        IconButton(
          onPressed: _toggleFlash,
          icon: const Icon(
            Icons.flash_off,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        // Timer toggle
        IconButton(
          onPressed: _toggleTimer,
          icon: const Icon(
            Icons.timer,
            color: Colors.white,
            size: 28,
          ),
        ),
      ],
    );
  }

  void _toggleRecording() async {
    try {
      final notifier = ref.read(vineRecordingProvider.notifier);
      final state = ref.read(vineRecordingProvider);

      if (state.isRecording) {
        // Stop recording manually
        Log.info('📹 Manually stopping recording', category: LogCategory.video);
        final result = await notifier.stopRecording();
        Log.info('📹 Recording stopped, result: ${result?.path}', category: LogCategory.video);
        if (result != null && mounted) {
          _processRecording(result);
        } else {
          Log.warning('📹 No file returned from stopRecording', category: LogCategory.video);
        }
      } else {
        // Start recording
        await notifier.startRecording();
      }
    } catch (e) {
      Log.error('📹 UniversalCameraScreenPure: Recording toggle failed: $e',
          category: LogCategory.video);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _switchCamera() async {
    try {
      await ref.read(vineRecordingProvider.notifier).switchCamera();
    } catch (e) {
      Log.error('📹 UniversalCameraScreenPure: Camera switch failed: $e',
          category: LogCategory.video);
    }
  }

  void _toggleFlash() {
    // TODO: Implement flash toggle
    Log.info('📹 UniversalCameraScreenPure: Flash toggle requested', category: LogCategory.video);
  }

  void _handleRecordingAutoStop() async {
    try {
      final notifier = ref.read(vineRecordingProvider.notifier);
      final result = await notifier.finishRecording();

      Log.info('📹 Auto-stop result: ${result?.path}', category: LogCategory.video);

      if (result != null && mounted) {
        _processRecording(result);
      } else {
        Log.warning('📹 No file returned after auto-stop', category: LogCategory.video);
      }
    } catch (e) {
      Log.error('📹 Failed to handle auto-stop: $e', category: LogCategory.video);
    }
  }

  void _toggleTimer() {
    // TODO: Implement timer toggle
    Log.info('📹 UniversalCameraScreenPure: Timer toggle requested', category: LogCategory.video);
  }

  void _processRecording(File recordedFile) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      Log.info('📹 UniversalCameraScreenPure: Processing recorded file: ${recordedFile.path}',
          category: LogCategory.video);

      // Get video duration (simplified for now)
      const duration = Duration(seconds: 6); // Default duration

      if (mounted) {
        // Navigate to metadata screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoMetadataScreenPure(
              videoFile: recordedFile,
              duration: duration,
            ),
          ),
        );

        // Return to previous screen after metadata screen
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      Log.error('📹 UniversalCameraScreenPure: Processing failed: $e',
          category: LogCategory.video);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _retryInitialization() async {
    setState(() {
      _errorMessage = null;
    });

    await _initializeServices();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }
}