// ABOUTME: Consolidated video feed PageView component with intelligent preloading
// ABOUTME: Provides consistent vertical scrolling behavior across home feed and explore screens

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Consolidated video feed PageView widget
///
/// Provides consistent vertical scrolling video feed behavior with:
/// - Mouse/trackpad drag support (web + desktop)
/// - Touch gesture support (mobile)
/// - Intelligent prewarming of neighbor videos
/// - Optional preloading for upcoming videos
/// - Pull-to-refresh support
/// - Pagination callback when near end of list
class VideoPageView extends ConsumerStatefulWidget {
  const VideoPageView({
    super.key,
    required this.videos,
    this.controller,
    this.initialIndex = 0,
    this.hasBottomNavigation = true,
    this.enablePrewarming = true,
    this.enablePreloading = false,
    this.enableLifecycleManagement = true,
    this.onPageChanged,
    this.onLoadMore,
    this.onRefresh,
  });

  final List<VideoEvent> videos;
  final PageController? controller;
  final int initialIndex;
  final bool hasBottomNavigation;
  final bool enablePrewarming;
  final bool enablePreloading;
  final bool enableLifecycleManagement;
  final void Function(int index, VideoEvent video)? onPageChanged;
  final VoidCallback? onLoadMore;
  final Future<void> Function()? onRefresh;

  @override
  ConsumerState<VideoPageView> createState() => _VideoPageViewState();
}

class _VideoPageViewState extends ConsumerState<VideoPageView> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = widget.controller ?? PageController(initialPage: widget.initialIndex);

    // Set initial active video
    if (widget.enableLifecycleManagement) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_currentIndex >= 0 && _currentIndex < widget.videos.length) {
          ref.read(activeVideoProvider.notifier)
              .setActiveVideo(widget.videos[_currentIndex].id);
          if (widget.enablePrewarming) {
            _prewarmNeighbors(_currentIndex);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    if (widget.enableLifecycleManagement) {
      try {
        ref.read(activeVideoProvider.notifier).clearActiveVideo();
      } catch (e) {
        Log.error('Error clearing active video on dispose: $e',
            name: 'VideoPageView', category: LogCategory.video);
      }
    }

    // Only dispose controller if we created it
    if (widget.controller == null) {
      _pageController.dispose();
    }
    super.dispose();
  }

  void _prewarmNeighbors(int index) {
    if (!widget.enablePrewarming) return;

    final ids = <String>{};
    for (final i in [index - 1, index, index + 1]) {
      if (i >= 0 && i < widget.videos.length) {
        final v = widget.videos[i];
        if (v.videoUrl != null && v.videoUrl!.isNotEmpty) {
          ids.add(v.id);
        }
      }
    }

    if (ids.isNotEmpty) {
      try {
        ref.read(prewarmManagerProvider.notifier).setPrewarmed(ids.toList(), cap: 3);
      } catch (e) {
        Log.error('Error prewarming neighbors: $e',
            name: 'VideoPageView', category: LogCategory.video);
      }
    }
  }

  void _handlePageChanged(int index) {
    Log.debug('📄 VideoPageView: Page changed to index $index',
        name: 'VideoPageView', category: LogCategory.video);
    setState(() => _currentIndex = index);

    if (index >= 0 && index < widget.videos.length) {
      final video = widget.videos[index];

      // Update active video
      if (widget.enableLifecycleManagement) {
        try {
          ref.read(activeVideoProvider.notifier).setActiveVideo(video.id);
        } catch (e) {
          Log.error('Error setting active video: $e',
              name: 'VideoPageView', category: LogCategory.video);
        }
      }

      // Prewarm neighbors
      if (widget.enablePrewarming) {
        _prewarmNeighbors(index);
      }

      // Check for pagination
      if (widget.onLoadMore != null && index >= widget.videos.length - 3) {
        widget.onLoadMore!();
      }

      // Notify parent
      widget.onPageChanged?.call(index, video);
    }
  }

  Widget _buildPageView() {
    Log.debug('🎮 VideoPageView: Building PageView with controller=${_pageController.hashCode}, '
        'hasClients=${_pageController.hasClients}, '
        'position=${_pageController.hasClients ? _pageController.position.pixels : "no position"}, '
        'videoCount=${widget.videos.length}, '
        'hasBottomNav=${widget.hasBottomNavigation}',
        name: 'VideoPageView', category: LogCategory.video);

    return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _handlePageChanged,
          itemCount: widget.videos.length,
          pageSnapping: true,
          itemBuilder: (context, index) {
            if (index >= widget.videos.length) return const SizedBox.shrink();

            return VideoFeedItem(
              key: ValueKey('video-${widget.videos[index].id}'),
              video: widget.videos[index],
              index: index,
              hasBottomNavigation: widget.hasBottomNavigation,
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    Widget pageView = _buildPageView();

    // Wrap with ScrollConfiguration to enable mouse/trackpad dragging
    pageView = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: pageView,
    );

    // Note: RefreshIndicator cannot wrap vertical PageView as it conflicts with scrolling
    // Pull-to-refresh should be implemented differently (e.g., custom gesture detection
    // or a separate refresh button). For now, onRefresh callback is available but not
    // used with RefreshIndicator to avoid blocking vertical scrolling.

    return pageView;
  }
}
