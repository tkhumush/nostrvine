// ABOUTME: Screen displaying videos filtered by a specific hashtag
// ABOUTME: Allows users to explore all videos with a particular hashtag

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/screens/pure/explore_video_screen_pure.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/video_feed_item.dart';

class HashtagFeedScreen extends ConsumerStatefulWidget {
  const HashtagFeedScreen({required this.hashtag, this.embedded = false, super.key});
  final String hashtag;
  final bool embedded;  // If true, don't show Scaffold/AppBar (for embedding in explore)

  @override
  ConsumerState<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends ConsumerState<HashtagFeedScreen> {
  @override
  void initState() {
    super.initState();
    // Subscribe to videos with this hashtag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hashtagService = ref.read(hashtagServiceProvider);
      hashtagService.subscribeToHashtagVideos([widget.hashtag]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Builder(
          builder: (context) {
            final videoService = ref.watch(videoEventServiceProvider);
            final hashtagService = ref.watch(hashtagServiceProvider);
            final videos = List<VideoEvent>.from(
              hashtagService.getVideosByHashtags([widget.hashtag]),
            )..sort(VideoEvent.compareByLoopsThenTime);

            if (videoService.isLoading && videos.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: VineTheme.vineGreen),
                    const SizedBox(height: 24),
                    const Text(
                      'Fetching videos from relays...',
                      style: TextStyle(
                        color: VineTheme.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This may take a few moments',
                      style: TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            if (videos.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.tag,
                      size: 64,
                      color: VineTheme.secondaryText,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No videos found for #${widget.hashtag}',
                      style: const TextStyle(
                        color: VineTheme.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Be the first to post a video with this hashtag!',
                      style: TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return GestureDetector(
                  onTap: () {
                    // Navigate to inline video player for this hashtag
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ExploreVideoScreenPure(
                          startingVideo: video,
                          videoList: videos,
                          contextTitle: '#${widget.hashtag}',
                          startingIndex: index,
                        ),
                      ),
                    );
                  },
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    width: double.infinity,
                    child: VideoFeedItem(
                      video: video,
                      index: index,
                    ),
                  ),
                );
              },
            );
          },
        );

    // If embedded, return body only; otherwise wrap with Scaffold
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 0,
        title: Text(
          '#${widget.hashtag}',
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: body,
    );
  }
}
