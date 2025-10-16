// ABOUTME: Route-aware hashtag feed provider (reactive, no lifecycle writes)
// ABOUTME: Returns videos filtered by hashtag from route context

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Route-aware hashtag feed (reactive, no lifecycle writes).
final videosForHashtagRouteProvider = Provider<AsyncValue<VideoFeedState>>((ref) {
  final ctx = ref.watch(pageContextProvider).asData?.value;
  if (ctx == null || ctx.type != RouteType.hashtag) {
    return AsyncValue.data(VideoFeedState(
      videos: const [],
      hasMoreContent: false,
      isLoadingMore: false,
    ));
  }

  // Route param: /hashtag/:tag/:index
  final raw = (ctx.hashtag ?? '').trim();
  final tag = raw.toLowerCase(); // normalize once
  if (tag.isEmpty) {
    return AsyncValue.data(VideoFeedState(
      videos: const [],
      hasMoreContent: false,
      isLoadingMore: false,
    ));
  }

  // Subscribe (service manages lifecycle internally; this is idempotent)
  final svc = ref.watch(videoEventServiceProvider);
  // NOTE: Current service takes List<String>, wrapping single tag
  svc.subscribeToHashtagVideos([tag], limit: 100);
  Log.info('HashtagFeedProvider: subscribed to tag=$tag',
      name: 'HashtagFeedProvider', category: LogCategory.system);

  // REACTIVE selection: rebuilds when service updates the list for this tag
  // Use same lowercase key for subscribe and select
  final items = ref.watch(
    videoEventServiceProvider.select((s) => s.hashtagVideos(tag)),
  );

  // No pagination yet; wire that later
  return AsyncValue.data(
    VideoFeedState(
      videos: items,
      hasMoreContent: false,
      isLoadingMore: false,
    ),
  );
});
