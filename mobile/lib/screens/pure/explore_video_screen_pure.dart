// ABOUTME: Pure explore video screen using revolutionary Riverpod architecture
// ABOUTME: Inline video player that maintains explore context using composition architecture

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Pure explore video screen using revolutionary single-controller Riverpod architecture
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
  int _currentIndex = 0;
  PageController? _controller;

  @override
  void initState() {
    super.initState();

    // Find starting video index or use provided index
    _currentIndex = widget.startingIndex ??
        widget.videoList.indexWhere((video) => video.id == widget.startingVideo.id);

    if (_currentIndex == -1) {
      _currentIndex = 0; // Fallback to first video
    }

    Log.info('🎯 ExploreVideoScreenPure: Initialized with ${widget.videoList.length} videos, starting at index $_currentIndex',
        category: LogCategory.video);

    _controller = PageController(initialPage: _currentIndex);

    // Set the initial active video once the UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentIndex >= 0 && _currentIndex < widget.videoList.length) {
        ref.read(activeVideoProvider.notifier)
            .setActiveVideo(widget.videoList[_currentIndex].id);
        _prewarmNeighbors(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    // CRITICAL: Clear active video when leaving to stop playback
    // This MUST happen to prevent background audio playing
    try {
      final activeId = ref.read(activeVideoProvider);
      Log.info('🛑 ExploreVideoScreenPure disposing - clearing active video: ${activeId?.substring(0, 8) ?? "none"}',
          name: 'ExploreVideoScreen', category: LogCategory.video);

      ref.read(activeVideoProvider.notifier).clearActiveVideo();

      Log.info('✅ Active video cleared successfully',
          name: 'ExploreVideoScreen', category: LogCategory.video);
    } catch (e) {
      Log.error('❌ Error clearing active video on dispose: $e',
          name: 'ExploreVideoScreen', category: LogCategory.video);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ExploreVideoScreenPure is now a body widget - parent handles Scaffold
    return PageView.builder(
        key: Key('explore-video-${widget.startingVideo.id}'),
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: widget.videoList.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          if (index >= 0 && index < widget.videoList.length) {
            ref.read(activeVideoProvider.notifier)
                .setActiveVideo(widget.videoList[index].id);
            _prewarmNeighbors(index);
          }
        },
        itemBuilder: (context, index) => VideoFeedItem(
          video: widget.videoList[index],
          index: index,
          hasBottomNavigation: false, // Explore feed mode has no bottom navigation
        ),
      );
  }

  void _prewarmNeighbors(int index) {
    final ids = <String>{};
    for (final i in [index - 1, index, index + 1]) {
      if (i >= 0 && i < widget.videoList.length) {
        final v = widget.videoList[i];
        if (v.videoUrl != null && v.videoUrl!.isNotEmpty) {
          ids.add(v.id);
        }
      }
    }
    ref.read(prewarmManagerProvider.notifier).setPrewarmed(ids, cap: 3);
  }
}
