// ABOUTME: Explore screen with proper Vine theme and video grid functionality
// ABOUTME: Pure Riverpod architecture for video discovery with grid/feed modes

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Pure ExploreScreen using revolutionary Riverpod architecture
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isInFeedMode = false;
  List<VideoEvent>? _feedVideos;
  int _feedStartIndex = 0;
  String? _hashtagMode;  // When non-null, showing hashtag feed

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1); // Start on Popular Now
    _tabController.addListener(_onTabChanged);

    // Load top hashtags for trending navigation
    _loadHashtags();

    Log.info('🎯 ExploreScreenPure: Initialized with revolutionary architecture',
        category: LogCategory.video);
  }

  Future<void> _loadHashtags() async {
    Log.info('🏷️ ExploreScreen: Starting hashtag load',
        category: LogCategory.video);
    await TopHashtagsService.instance.loadTopHashtags();
    final count = TopHashtagsService.instance.topHashtags.length;
    Log.info('🏷️ ExploreScreen: Hashtags loaded: $count total, isLoaded=${TopHashtagsService.instance.isLoaded}',
        category: LogCategory.video);
    if (mounted) {
      setState(() {
        // Trigger rebuild after hashtags are loaded
        Log.info('🏷️ ExploreScreen: Triggering rebuild with $count hashtags',
            category: LogCategory.video);
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();

    Log.info('🎯 ExploreScreenPure: Disposed cleanly',
        category: LogCategory.video);
  }

  void _onTabChanged() {
    if (!mounted) return;

    Log.debug('🎯 ExploreScreenPure: Switched to tab ${_tabController.index}',
        category: LogCategory.video);

    // Exit feed or hashtag mode when user switches tabs
    if (_isInFeedMode || _hashtagMode != null) {
      setState(() {
        _isInFeedMode = false;
        _feedVideos = null;
        _hashtagMode = null;
      });
      Log.info('🎯 ExploreScreenPure: Exited feed/hashtag mode via tab change',
          category: LogCategory.video);
    }
  }


  void _enterFeedMode(List<VideoEvent> videos, int startIndex) {
    if (!mounted) return;

    setState(() {
      _isInFeedMode = true;
      _feedVideos = videos;
      _feedStartIndex = startIndex;
    });

    // Set active video; feed screen manages playback based on visibility
    if (startIndex >= 0 && startIndex < videos.length) {
      ref.read(activeVideoProvider.notifier).setActiveVideo(videos[startIndex].id);
    }

    Log.info('🎯 ExploreScreenPure: Entered feed mode at index $startIndex',
        category: LogCategory.video);
  }

  void _exitFeedMode() {
    if (!mounted) return;

    setState(() {
      _isInFeedMode = false;
      _feedVideos = null;
    });

    // Clear active video on exit
    ref.read(activeVideoProvider.notifier).clearActiveVideo();

    Log.info('🎯 ExploreScreenPure: Exited feed mode',
        category: LogCategory.video);
  }

  void _enterHashtagMode(String hashtag) {
    if (!mounted) return;

    setState(() {
      _hashtagMode = hashtag;
    });

    Log.info('🎯 ExploreScreenPure: Entered hashtag mode for #$hashtag',
        category: LogCategory.video);
  }


  @override
  Widget build(BuildContext context) {
    // Always show Column with TabBar + content
    return Column(
      children: [
        // Tabs always visible
        Container(
          color: VineTheme.vineGreen,
          child: TabBar(
            controller: _tabController,
            indicatorColor: VineTheme.whiteText,
            indicatorWeight: 3,
            labelColor: VineTheme.whiteText,
            unselectedLabelColor: VineTheme.whiteText.withValues(alpha: 0.7),
            labelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(text: 'Popular Now'),
              Tab(text: 'Trending'),
              Tab(text: "Editor's Pick"),
            ],
          ),
        ),
        // Content changes based on mode
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isInFeedMode) {
      return _buildFeedModeContent();
    }

    if (_hashtagMode != null) {
      return _buildHashtagModeContent(_hashtagMode!);
    }

    // Default: show tab view
    return TabBarView(
      controller: _tabController,
      children: [
        _buildPopularNowTab(),
        _buildTrendingTab(),
        _buildEditorsPickTab(),
      ],
    );
  }

  Widget _buildFeedModeContent() {
    final videos = _feedVideos ?? const <VideoEvent>[];
    // Just return the video screen - tabs are shown above
    return ExploreVideoScreenPure(
      startingVideo: videos[_feedStartIndex],
      videoList: videos,
      contextTitle: 'Videos',
      startingIndex: _feedStartIndex,
    );
  }

  Widget _buildHashtagModeContent(String hashtag) {
    // Just return the hashtag feed content - tabs are shown above
    return HashtagFeedScreen(hashtag: hashtag, embedded: true);
  }

  Widget _buildEditorsPickTab() {
    return Container(
      key: const Key('editors-pick-content'),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              "Editor's Pick",
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Curated content coming soon',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularNowTab() {
    // Watch video events from our pure provider
    final videoEventsAsync = ref.watch(videoEventsProvider);

    return videoEventsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load videos',
              style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
            ),
          ],
        ),
      ),
      data: (videos) => _buildVideoGrid(videos, 'Popular Now'),
    );
  }

  Widget _buildTrendingTab() {
    // Sort videos by loop count (most loops first)
    final videoEventsAsync = ref.watch(videoEventsProvider);

    return videoEventsAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load trending videos',
              style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
            ),
          ],
        ),
      ),
      data: (videos) {
        // Sort by loop count (descending order - most popular first)
        final sortedVideos = List<VideoEvent>.from(videos);
        sortedVideos.sort((a, b) {
          final aLoops = a.originalLoops ?? 0;
          final bLoops = b.originalLoops ?? 0;
          return bLoops.compareTo(aLoops); // Descending order
        });
        return _buildTrendingTabWithHashtags(sortedVideos);
      },
    );
  }

  Widget _buildTrendingTabWithHashtags(List<VideoEvent> videos) {
    return Column(
      children: [
        // Hashtag navigation section
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Trending Hashtags',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: Builder(
                  builder: (context) {
                    final hashtags = TopHashtagsService.instance.getTopHashtags(limit: 20);

                    if (hashtags.isEmpty) {
                      // Show placeholder while loading
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Loading hashtags...',
                          style: TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: hashtags.length,
                      itemBuilder: (context, index) {
                        final hashtag = hashtags[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          _enterHashtagMode(hashtag);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: VineTheme.vineGreen,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '#$hashtag',
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Videos grid
        Expanded(
          child: _buildVideoGrid(videos, 'Trending'),
        ),
      ],
    );
  }

  Widget _buildVideoGrid(List<VideoEvent> videos, String tabName) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'No videos in $tabName',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new content',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _buildVideoTile(video, index, videos);
      },
    );
  }

  Widget _buildVideoTile(VideoEvent video, int index, List<VideoEvent> videos) {
    return GestureDetector(
      onTap: () {
        Log.info('🎯 ExploreScreen: Tapped video tile at index $index',
            category: LogCategory.video);
        _enterFeedMode(videos, index);
      },
      child: Container(
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              // Video thumbnail with play overlay
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: VineTheme.cardBackground,
                      child: video.thumbnailUrl != null
                          ? VideoThumbnailWidget(
                              video: video,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: VineTheme.cardBackground,
                              child: Icon(
                                Icons.videocam,
                                size: 40,
                                color: VineTheme.secondaryText,
                              ),
                            ),
                    ),
                    // Play button overlay
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: VineTheme.darkOverlay,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow,
                          size: 24,
                          color: VineTheme.whiteText,
                        ),
                      ),
                    ),
                    // Duration badge if available
                    if (video.duration != null)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: VineTheme.darkOverlay,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${video.duration}s',
                            style: TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Video info
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        video.title ??
                        (video.content.length > 25
                          ? '${video.content.substring(0, 25)}...'
                          : video.content),
                        style: TextStyle(
                          color: VineTheme.primaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 12,
                            color: VineTheme.likeRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${video.originalLikes ?? 0}',
                            style: TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Public methods expected by main.dart
  void onScreenVisible() {
    // Handle screen becoming visible
    Log.debug('🎯 ExploreScreen became visible', category: LogCategory.video);
  }

  void onScreenHidden() {
    // Handle screen becoming hidden
    Log.debug('🎯 ExploreScreen became hidden', category: LogCategory.video);
  }

  bool get isInFeedMode => _isInFeedMode;

  void exitFeedMode() => _exitFeedMode();

  void showHashtagVideos(String hashtag) {
    Log.debug('🎯 ExploreScreen showing hashtag videos: $hashtag', category: LogCategory.video);
    // Implementation for hashtag filtering would go here
  }

  void playSpecificVideo(VideoEvent video, List<VideoEvent> videos, int index) {
    Log.debug('🎯 ExploreScreen playing specific video: ${video.id}', category: LogCategory.video);
    _enterFeedMode(videos, index);
  }
}
