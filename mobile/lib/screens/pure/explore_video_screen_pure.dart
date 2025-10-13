// ABOUTME: Pure explore video screen using VideoPageView widget
// ABOUTME: Simplified implementation using consolidated video feed component

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/widgets/video_page_view.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Pure explore video screen using VideoPageView for consistent behavior
class ExploreVideoScreenPure extends ConsumerStatefulWidget {
  const ExploreVideoScreenPure({
    super.key,
    required this.startingVideo,
    required this.videoList,
    required this.contextTitle,
    this.startingIndex,
  });

  final VideoEvent startingVideo;
  final List<VideoEvent> videoList;
  final String contextTitle;
  final int? startingIndex;

  @override
  ConsumerState<ExploreVideoScreenPure> createState() => _ExploreVideoScreenPureState();
}

class _ExploreVideoScreenPureState extends ConsumerState<ExploreVideoScreenPure> {
  late int _initialIndex;
  ActiveVideoNotifier? _activeVideoNotifier; // Save notifier for safe disposal
  String? _activeVideoIdAtInit; // Save active video ID for logging

  @override
  void initState() {
    super.initState();

    // Save notifier reference for safe disposal
    // CRITICAL: Must do this before any async work
    _activeVideoNotifier = ref.read(activeVideoProvider.notifier);
    _activeVideoIdAtInit = ref.read(activeVideoProvider).currentVideoId;

    // Find starting video index or use provided index
    _initialIndex = widget.startingIndex ??
        widget.videoList.indexWhere((video) => video.id == widget.startingVideo.id);

    if (_initialIndex == -1) {
      _initialIndex = 0; // Fallback to first video
    }

    Log.info('🎯 ExploreVideoScreenPure: Initialized with ${widget.videoList.length} videos, starting at index $_initialIndex',
        category: LogCategory.video);
  }

  @override
  void dispose() {
    // CRITICAL: Clear active video when leaving to stop playback
    // Use saved notifier reference - NEVER use ref.read() in dispose()
    if (_activeVideoNotifier != null) {
      try {
        Log.info('🛑 ExploreVideoScreenPure disposing - clearing active video: ${_activeVideoIdAtInit != null ? _activeVideoIdAtInit!.substring(0, 8) : "none"}',
            name: 'ExploreVideoScreen', category: LogCategory.video);

        _activeVideoNotifier!.clearActiveVideo();

        Log.info('✅ Active video cleared successfully',
            name: 'ExploreVideoScreen', category: LogCategory.video);
      } catch (e) {
        Log.error('❌ Error clearing active video on dispose: $e',
            name: 'ExploreVideoScreen', category: LogCategory.video);
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ExploreVideoScreenPure is now a body widget - parent handles Scaffold
    return VideoPageView(
      key: Key('explore-video-${widget.startingVideo.id}'),
      videos: widget.videoList,
      initialIndex: _initialIndex,
      hasBottomNavigation: false, // Explore feed mode has no bottom navigation
      enablePrewarming: true,
      enablePreloading: false, // Explore screen doesn't need preloading
      enableLifecycleManagement: true, // Enable lifecycle management for autoplay
      contextTitle: widget.contextTitle,
      onPageChanged: (index, video) {
        Log.debug('📄 Page changed to index $index (${video.id.substring(0, 8)}...)',
            name: 'ExploreVideoScreen', category: LogCategory.video);
      },
    );
  }
}
