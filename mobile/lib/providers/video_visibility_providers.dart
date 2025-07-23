// ABOUTME: Riverpod providers for centralized video visibility management
// ABOUTME: Ensures videos ONLY play when actually visible on screen

import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/unified_logger.dart';

part 'video_visibility_providers.g.dart';

/// Visibility info for a video widget
class VideoVisibilityInfo {
  final String videoId;
  final double visibilityFraction;
  final bool isVisible;
  final DateTime lastUpdate;
  
  const VideoVisibilityInfo({
    required this.videoId,
    required this.visibilityFraction,
    required this.isVisible,
    required this.lastUpdate,
  });
}

/// State for video visibility management
class VideoVisibilityState {
  /// Map of video IDs to their visibility info
  final Map<String, VideoVisibilityInfo> visibilityMap;
  
  /// Set of video IDs that are allowed to play
  final Set<String> playableVideos;
  
  /// Track if user is actively scrolling/playing videos (auto-play mode)
  final bool autoPlayEnabled;
  
  /// The last video that was playing (for auto-play continuation)
  final String? lastPlayingVideo;
  
  const VideoVisibilityState({
    required this.visibilityMap,
    required this.playableVideos,
    required this.autoPlayEnabled,
    this.lastPlayingVideo,
  });
  
  /// Get all currently visible videos
  List<String> get visibleVideos => visibilityMap.entries
      .where((e) => e.value.isVisible)
      .map((e) => e.key)
      .toList();
  
  /// Check if a specific video should be playing
  bool shouldVideoPlay(String videoId) => playableVideos.contains(videoId);
  
  VideoVisibilityState copyWith({
    Map<String, VideoVisibilityInfo>? visibilityMap,
    Set<String>? playableVideos,
    bool? autoPlayEnabled,
    String? lastPlayingVideo,
    bool clearLastPlayingVideo = false,
  }) {
    return VideoVisibilityState(
      visibilityMap: visibilityMap ?? this.visibilityMap,
      playableVideos: playableVideos ?? this.playableVideos,
      autoPlayEnabled: autoPlayEnabled ?? this.autoPlayEnabled,
      lastPlayingVideo: clearLastPlayingVideo ? null : (lastPlayingVideo ?? this.lastPlayingVideo),
    );
  }
}

/// Main video visibility provider
@riverpod
class VideoVisibilityNotifier extends _$VideoVisibilityNotifier {
  /// Minimum visibility fraction required for a video to play (50%)
  static const double minVisibilityThreshold = 0.5;
  
  /// Stream controller for visibility changes
  final _visibilityStreamController = StreamController<VideoVisibilityInfo>.broadcast();
  
  @override
  VideoVisibilityState build() {
    // Cleanup on dispose
    ref.onDispose(() {
      _visibilityStreamController.close();
    });
    
    // Return initial state
    return const VideoVisibilityState(
      visibilityMap: {},
      playableVideos: {},
      autoPlayEnabled: false,
    );
  }
  
  /// Get stream of visibility changes
  Stream<VideoVisibilityInfo> get visibilityStream => _visibilityStreamController.stream;
  
  /// Update visibility for a video
  /// 
  /// This is called by VisibilityDetector widgets wrapping each video.
  /// The manager decides if the video should play based on visibility.
  void updateVideoVisibility(String videoId, double visibilityFraction) {
    final wasPlayable = state.playableVideos.contains(videoId);
    final isNowVisible = visibilityFraction > 0;
    final isNowPlayable = visibilityFraction >= minVisibilityThreshold;
    
    // Update visibility info
    final info = VideoVisibilityInfo(
      videoId: videoId,
      visibilityFraction: visibilityFraction,
      isVisible: isNowVisible,
      lastUpdate: DateTime.now(),
    );
    
    final newVisibilityMap = Map<String, VideoVisibilityInfo>.from(state.visibilityMap);
    newVisibilityMap[videoId] = info;
    
    // Update playable set
    final newPlayableVideos = Set<String>.from(state.playableVideos);
    String? newLastPlayingVideo = state.lastPlayingVideo;
    
    if (isNowPlayable && !wasPlayable) {
      newPlayableVideos.add(videoId);
      
      // Auto-play logic: if auto-play is enabled and this is a new visible video,
      // make it the actively playing one
      if (state.autoPlayEnabled) {
        // When setting a new actively playing video, ensure only one can play
        newLastPlayingVideo = videoId;
      }
      
      Log.info('✅ Video $videoId is now playable (visibility: ${(visibilityFraction * 100).toStringAsFixed(1)}%)', 
          name: 'VideoVisibilityNotifier', category: LogCategory.video);
    } else if (!isNowPlayable && wasPlayable) {
      newPlayableVideos.remove(videoId);
      
      // If this was the actively playing video, update auto-play state
      if (state.lastPlayingVideo == videoId) {
        newLastPlayingVideo = null;
        // If auto-play is enabled, find the next most visible video
        if (state.autoPlayEnabled && newPlayableVideos.isNotEmpty) {
          // Get the most visible video from the remaining playable ones
          String? nextVideo;
          double maxVisibility = 0;
          for (final id in newPlayableVideos) {
            final info = newVisibilityMap[id];
            if (info != null && info.visibilityFraction > maxVisibility) {
              maxVisibility = info.visibilityFraction;
              nextVideo = id;
            }
          }
          if (nextVideo != null) {
            newLastPlayingVideo = nextVideo;
          }
        }
      }
      
      Log.info('⏸️ Video $videoId is no longer playable (visibility: ${(visibilityFraction * 100).toStringAsFixed(1)}%)', 
          name: 'VideoVisibilityNotifier', category: LogCategory.video);
    }
    
    // Emit visibility change
    _visibilityStreamController.add(info);
    
    // Update state
    state = state.copyWith(
      visibilityMap: newVisibilityMap,
      playableVideos: newPlayableVideos,
      lastPlayingVideo: newLastPlayingVideo,
    );
  }
  
  /// Remove a video from tracking (e.g., when widget is disposed)
  void removeVideo(String videoId) {
    final newVisibilityMap = Map<String, VideoVisibilityInfo>.from(state.visibilityMap);
    newVisibilityMap.remove(videoId);
    
    final newPlayableVideos = Set<String>.from(state.playableVideos);
    newPlayableVideos.remove(videoId);
    
    Log.debug('Removed video $videoId from visibility tracking', 
        name: 'VideoVisibilityNotifier', category: LogCategory.video);
    
    state = state.copyWith(
      visibilityMap: newVisibilityMap,
      playableVideos: newPlayableVideos,
    );
  }
  
  /// Pause all videos (e.g., when app goes to background)
  void pauseAllVideos() {
    state = state.copyWith(playableVideos: {});
    Log.info('⏸️ Paused all videos', name: 'VideoVisibilityNotifier', category: LogCategory.video);
  }
  
  /// Resume visibility-based playback
  void resumeVisibilityBasedPlayback() {
    // Re-evaluate which videos should play based on current visibility
    final newPlayableVideos = <String>{};
    
    for (final entry in state.visibilityMap.entries) {
      if (entry.value.visibilityFraction >= minVisibilityThreshold) {
        newPlayableVideos.add(entry.key);
      }
    }
    
    state = state.copyWith(playableVideos: newPlayableVideos);
    
    Log.info('▶️ Resumed visibility-based playback (${newPlayableVideos.length} videos playable)', 
        name: 'VideoVisibilityNotifier', category: LogCategory.video);
  }
  
  /// Mark a video as actively playing (enables auto-play mode)
  /// 
  /// This should be called when a user explicitly starts playing a video.
  /// It enables auto-play so the next visible video will automatically play.
  void setActivelyPlaying(String videoId) {
    if (state.playableVideos.contains(videoId)) {
      // If there was a previous video playing, ensure it's no longer in playable set
      final newPlayableVideos = Set<String>.from(state.playableVideos);
      if (state.lastPlayingVideo != null && state.lastPlayingVideo != videoId) {
        newPlayableVideos.remove(state.lastPlayingVideo);
        Log.info('⏸️ Removing previous video from playable: ${state.lastPlayingVideo}', 
            name: 'VideoVisibilityNotifier', category: LogCategory.video);
      }
      
      state = state.copyWith(
        playableVideos: newPlayableVideos,
        autoPlayEnabled: true,
        lastPlayingVideo: videoId,
      );
      
      Log.info('🎬 Auto-play enabled - actively playing: $videoId', 
          name: 'VideoVisibilityNotifier', category: LogCategory.video);
    }
  }
  
  /// Disable auto-play (user paused or stopped video)
  void disableAutoPlay() {
    state = state.copyWith(
      autoPlayEnabled: false,
      clearLastPlayingVideo: true,
    );
    Log.info('⏹️ Auto-play disabled', name: 'VideoVisibilityNotifier', category: LogCategory.video);
  }
  
  /// Clear all tracking (for cleanup)
  void clearAll() {
    state = const VideoVisibilityState(
      visibilityMap: {},
      playableVideos: {},
      autoPlayEnabled: false,
    );
    Log.info('🧹 Cleared all video visibility tracking', name: 'VideoVisibilityNotifier', category: LogCategory.video);
  }
  
  /// Get visibility stats for debugging
  Map<String, dynamic> getVisibilityStats() {
    return {
      'totalTracked': state.visibilityMap.length,
      'visibleCount': state.visibleVideos.length,
      'playableCount': state.playableVideos.length,
      'autoPlayEnabled': state.autoPlayEnabled,
      'activelyPlaying': state.lastPlayingVideo,
    };
  }
}

/// Stream provider for visibility changes
@riverpod
Stream<VideoVisibilityInfo> videoVisibilityStream(VideoVisibilityStreamRef ref) {
  final notifier = ref.watch(videoVisibilityNotifierProvider.notifier);
  return notifier.visibilityStream;
}

/// Convenience providers
@riverpod
Set<String> playableVideos(PlayableVideosRef ref) {
  return ref.watch(videoVisibilityNotifierProvider).playableVideos;
}

@riverpod
bool isVideoPlayable(IsVideoPlayableRef ref, String videoId) {
  return ref.watch(videoVisibilityNotifierProvider).playableVideos.contains(videoId);
}

@riverpod
bool isAutoPlayEnabled(IsAutoPlayEnabledRef ref) {
  return ref.watch(videoVisibilityNotifierProvider).autoPlayEnabled;
}

@riverpod
String? activelyPlayingVideo(ActivelyPlayingVideoRef ref) {
  return ref.watch(videoVisibilityNotifierProvider).lastPlayingVideo;
}