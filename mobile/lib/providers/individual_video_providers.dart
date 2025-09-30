// ABOUTME: Individual video controller providers using proper Riverpod Family pattern
// ABOUTME: Each video gets its own controller with automatic lifecycle management via autoDispose

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_player/video_player.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/services/video_preload_service.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/providers/app_providers.dart';

part 'individual_video_providers.g.dart';

/// Parameters for video controller creation
class VideoControllerParams {
  const VideoControllerParams({
    required this.videoId,
    required this.videoUrl,
    this.videoEvent,
  });

  final String videoId;
  final String videoUrl;
  final dynamic videoEvent; // VideoEvent for enhanced error reporting

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoControllerParams &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          videoUrl == other.videoUrl &&
          videoEvent == other.videoEvent;

  @override
  int get hashCode => videoId.hashCode ^ videoUrl.hashCode ^ videoEvent.hashCode;

  @override
  String toString() => 'VideoControllerParams(videoId: $videoId, videoUrl: $videoUrl, hasEvent: ${videoEvent != null})';
}

/// Loading state for individual videos
class VideoLoadingState {
  const VideoLoadingState({
    required this.videoId,
    required this.isLoading,
    required this.isInitialized,
    required this.hasError,
    this.errorMessage,
  });

  final String videoId;
  final bool isLoading;
  final bool isInitialized;
  final bool hasError;
  final String? errorMessage;

  VideoLoadingState copyWith({
    String? videoId,
    bool? isLoading,
    bool? isInitialized,
    bool? hasError,
    String? errorMessage,
  }) {
    return VideoLoadingState(
      videoId: videoId ?? this.videoId,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoLoadingState &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          isLoading == other.isLoading &&
          isInitialized == other.isInitialized &&
          hasError == other.hasError &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(videoId, isLoading, isInitialized, hasError, errorMessage);

  @override
  String toString() => 'VideoLoadingState(videoId: $videoId, isLoading: $isLoading, isInitialized: $isInitialized, hasError: $hasError, errorMessage: $errorMessage)';
}

/// Provider for individual video controllers with autoDispose
/// Each video gets its own controller instance
@riverpod
VideoPlayerController individualVideoController(
  Ref ref,
  VideoControllerParams params,
) {
  // Concurrency/keep-alive policy: keep active video and prewarmed neighbors alive briefly
  // Keep the provider alive while active/prewarmed, with short grace when transitioning
  final link = ref.keepAlive();
  Timer? dropTimer;

  void rescheduleDrop() {
    dropTimer?.cancel();
    // Re-evaluate current activity/prewarm state at the moment of scheduling
    final currentActiveId = ref.read(activeVideoProvider);
    final isActiveNow = currentActiveId == params.videoId;
    final isPrewarmedNow = ref.read(prewarmManagerProvider).contains(params.videoId);

    // Give a small grace period before releasing when neither active nor prewarmed
    if (!isActiveNow && !isPrewarmedNow) {
      dropTimer = Timer(const Duration(seconds: 3), () {
        try {
          link.close();
        } catch (_) {}
      });
    }
  }

  // React to active/prewarm changes to adjust lifetime
  ref.listen<String?>(activeVideoProvider, (_, __) => rescheduleDrop());
  ref.listen<Set<String>>(prewarmManagerProvider, (_, __) => rescheduleDrop());

  // Ensure timer is cleared on dispose
  ref.onDispose(() {
    dropTimer?.cancel();
  });

  Log.info('🎬 Creating VideoPlayerController for video ${params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId}...',
      name: 'IndividualVideoController', category: LogCategory.system);

  // Try to use preloaded controller first for better performance
  final preloadService = VideoPreloadService();
  final preloadedController = preloadService.getPreloadedController(params.videoId);

  // For now, create network controller and cache asynchronously in background
  final controller = preloadedController ?? VideoPlayerController.networkUrl(
    Uri.parse(params.videoUrl),
  );

  // Cache video in background for future use (non-blocking)
  final videoCache = openVineVideoCache;
  ref.read(brokenVideoTrackerProvider.future).then((tracker) {
    videoCache.cacheVideo(params.videoUrl, params.videoId, brokenVideoTracker: tracker).catchError((error) {
      Log.warning('⚠️ Background video caching failed: $error',
          name: 'IndividualVideoController', category: LogCategory.video);
      return null; // Return null on error
    });
  }).catchError((trackerError) {
    // Fallback without broken video tracker if it fails to load
    videoCache.cacheVideo(params.videoUrl, params.videoId).catchError((error) {
      Log.warning('⚠️ Background video caching failed: $error',
          name: 'IndividualVideoController', category: LogCategory.video);
      return null; // Return null on error
    });
  });

  // Initialize the controller if not already preloaded
  final initFuture = preloadedController != null
    ? Future.value() // Already initialized
    : controller.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Video initialization timed out'),
      );

  initFuture.then((_) {
    Log.info('✅ VideoPlayerController initialized for video ${params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId}...',
        name: 'IndividualVideoController', category: LogCategory.system);

    // Set looping for Vine-like behavior
    controller.setLooping(true);

    // Check current active state and start playback if this video is active
    final isActiveNow = ref.read(activeVideoProvider) == params.videoId;
    if (isActiveNow) {
      Log.info('🎬 Starting video ${params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId}... (active on initialization)',
          name: 'IndividualVideoController', category: LogCategory.system);
      controller.play().catchError((playError) {
        Log.error('❌ Failed to start video playback: $playError',
            name: 'IndividualVideoController', category: LogCategory.system);
      });
    } else {
      Log.debug('⏸️ Video ${params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId}... initialized but not active, staying paused',
          name: 'IndividualVideoController', category: LogCategory.system);
    }
  }).catchError((error) {
    final videoIdDisplay = params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId;

    // Enhanced error logging with full Nostr event details
    final errorMessage = error.toString();
    var logMessage = '❌ VideoPlayerController initialization failed for video $videoIdDisplay...: $errorMessage';

    if (params.videoEvent != null) {
      final event = params.videoEvent as dynamic;
      logMessage += '\n📋 Full Nostr Event Details:';
      logMessage += '\n   • Event ID: ${event.id}';
      logMessage += '\n   • Pubkey: ${event.pubkey}';
      logMessage += '\n   • Content: ${event.content}';
      logMessage += '\n   • Video URL: ${event.videoUrl}';
      logMessage += '\n   • Title: ${event.title ?? 'null'}';
      logMessage += '\n   • Duration: ${event.duration ?? 'null'}';
      logMessage += '\n   • Dimensions: ${event.dimensions ?? 'null'}';
      logMessage += '\n   • MIME Type: ${event.mimeType ?? 'null'}';
      logMessage += '\n   • File Size: ${event.fileSize ?? 'null'}';
      logMessage += '\n   • SHA256: ${event.sha256 ?? 'null'}';
      logMessage += '\n   • Thumbnail URL: ${event.thumbnailUrl ?? 'null'}';
      logMessage += '\n   • Hashtags: ${event.hashtags ?? []}';
      logMessage += '\n   • Created At: ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}';
      if (event.rawTags != null && event.rawTags.isNotEmpty) {
        logMessage += '\n   • Raw Tags: ${event.rawTags}';
      }
    } else {
      logMessage += '\n⚠️  No Nostr event details available (consider passing videoEvent to VideoControllerParams)';
    }

    Log.error(logMessage, name: 'IndividualVideoController', category: LogCategory.system);

    // Mark video as broken for errors that indicate the video URL is non-functional
    if (_isVideoError(errorMessage)) {
      ref.read(brokenVideoTrackerProvider.future).then((tracker) {
        tracker.markVideoBroken(params.videoId, 'Playback initialization failed: $errorMessage');
      }).catchError((trackerError) {
        Log.warning('Failed to mark video as broken: $trackerError',
            name: 'IndividualVideoController', category: LogCategory.system);
      });
    }
  });

  // AutoDispose: Cleanup controller when provider is disposed
  ref.onDispose(() {
    Log.info('🧹 Disposing VideoPlayerController for video ${params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId}...',
        name: 'IndividualVideoController', category: LogCategory.system);
    controller.dispose();
  });

  // Initial drop scheduling based on current state
  rescheduleDrop();

  // Listen for active state changes to control playback reliably
  // Listen to both the specific video active state AND the global activeVideoProvider
  // This ensures we catch state changes even when widgets are disposed
  ref.listen<bool>(isVideoActiveProvider(params.videoId), (prev, next) {
    final videoIdDisplay = params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId;

    try {
      if (next) {
        // Video became active
        if (controller.value.isInitialized) {
          if (!controller.value.isPlaying) {
            Log.info('▶️ Starting video $videoIdDisplay... (became active)',
                name: 'IndividualVideoController', category: LogCategory.system);
            controller.play().catchError((error) {
              Log.error('❌ Failed to play video $videoIdDisplay...: $error',
                  name: 'IndividualVideoController', category: LogCategory.system);
            });
          }
        } else {
          Log.debug('⏳ Video $videoIdDisplay... became active but not yet initialized',
              name: 'IndividualVideoController', category: LogCategory.system);
        }
      } else {
        // Video became inactive
        if (controller.value.isPlaying) {
          Log.info('⏸️ Pausing video $videoIdDisplay... (became inactive)',
              name: 'IndividualVideoController', category: LogCategory.system);
          controller.pause().catchError((error) {
            Log.error('❌ Failed to pause video $videoIdDisplay...: $error',
                name: 'IndividualVideoController', category: LogCategory.system);
          });
        }
      }
    } catch (error) {
      Log.error('❌ Error in active state listener for $videoIdDisplay...: $error',
          name: 'IndividualVideoController', category: LogCategory.system);
    }
  });

  // CRITICAL FIX: Listen to activeVideoProvider changes to pause when this video becomes inactive
  // This handles both: (1) switching to another video, (2) clearing active video entirely
  ref.listen<String?>(activeVideoProvider, (prev, next) {
    final videoIdDisplay = params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId;

    // DEBUG: Log every state change to diagnose if listener fires
    Log.debug('📡 ActiveVideo listener fired for $videoIdDisplay: prev=${prev?.substring(0, 8) ?? "null"}, next=${next?.substring(0, 8) ?? "null"}',
        name: 'IndividualVideoController', category: LogCategory.system);

    try {
      // This video was active (either in prev or we're currently active) and now it's not
      final wasActive = prev == params.videoId;
      final isActiveNow = next == params.videoId;

      if (wasActive && !isActiveNow && controller.value.isPlaying) {
        Log.info('⏸️ Pausing video $videoIdDisplay... (no longer active: ${next == null ? "cleared" : "switched"})',
            name: 'IndividualVideoController', category: LogCategory.system);
        controller.pause().catchError((error) {
          Log.error('❌ Failed to pause video $videoIdDisplay...: $error',
              name: 'IndividualVideoController', category: LogCategory.system);
        });
      } else {
        Log.debug('⏭️ Skipping pause for $videoIdDisplay: wasActive=$wasActive, isActiveNow=$isActiveNow, isPlaying=${controller.value.isPlaying}',
            name: 'IndividualVideoController', category: LogCategory.system);
      }
    } catch (error) {
      Log.error('❌ Error in activeVideoProvider listener for $videoIdDisplay...: $error',
          name: 'IndividualVideoController', category: LogCategory.system);
    }
  });

  return controller;
}

/// Check if error indicates a broken/non-functional video
bool _isVideoError(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('404') ||
         lowerError.contains('not found') ||
         lowerError.contains('invalid statuscode: 404') ||
         lowerError.contains('httpexception') ||
         lowerError.contains('timeout') ||
         lowerError.contains('connection refused') ||
         lowerError.contains('network error') ||
         lowerError.contains('video initialization timed out');
}

/// Provider for video loading state
@riverpod
VideoLoadingState videoLoadingState(
  Ref ref,
  VideoControllerParams params,
) {
  final controller = ref.watch(individualVideoControllerProvider(params));

  if (controller.value.hasError) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: false,
      hasError: true,
      errorMessage: controller.value.errorDescription,
    );
  }

  if (controller.value.isInitialized) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: true,
      hasError: false,
    );
  }

  return VideoLoadingState(
    videoId: params.videoId,
    isLoading: true,
    isInitialized: false,
    hasError: false,
  );
}

/// Active video state notifier
class ActiveVideoNotifier extends StateNotifier<String?> {
  ActiveVideoNotifier() : super(null);

  void setActiveVideo(String videoId) {
    Log.info('🎯 Setting active video to ${videoId.length > 8 ? videoId.substring(0, 8) : videoId}...',
        name: 'ActiveVideoNotifier', category: LogCategory.system);
    state = videoId;
  }

  void clearActiveVideo() {
    Log.info('🔄 Clearing active video',
        name: 'ActiveVideoNotifier', category: LogCategory.system);
    state = null;
  }
}

/// Provider for tracking which video is currently active
final activeVideoProvider = StateNotifierProvider<ActiveVideoNotifier, String?>((ref) {
  return ActiveVideoNotifier();
});

/// Provider for checking if a specific video is currently active
@riverpod
bool isVideoActive(Ref ref, String videoId) {
  final activeVideoId = ref.watch(activeVideoProvider);
  final isActive = activeVideoId == videoId;
  Log.debug('🔍 isVideoActive: videoId=${videoId.length > 8 ? videoId.substring(0, 8) : videoId}..., activeVideoId=${activeVideoId != null && activeVideoId.length > 8 ? activeVideoId.substring(0, 8) : activeVideoId ?? 'null'}, isActive=$isActive',
      name: 'IsVideoActive', category: LogCategory.system);
  return isActive;
}

/// Tracks which videos should be prewarmed (kept alive briefly as neighbors)
class PrewarmManager extends StateNotifier<Set<String>> {
  PrewarmManager() : super(<String>{});

  /// Set the current prewarmed set, capped to [cap] items
  void setPrewarmed(Iterable<String> ids, {int cap = 3}) {
    final limited = ids.take(cap).toSet();
    if (limited.length != state.length || !state.containsAll(limited)) {
      state = limited;
    }
  }

  void clear() => state = <String>{};
}

final prewarmManagerProvider =
    StateNotifierProvider<PrewarmManager, Set<String>>((ref) => PrewarmManager());
