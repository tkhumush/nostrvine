// ABOUTME: Pure search screen using revolutionary Riverpod architecture
// ABOUTME: Searches for videos, users, and hashtags using composition architecture

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/screens/pure/profile_screen_pure.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/widgets/pure/video_grid_widget.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Pure search screen using revolutionary single-controller Riverpod architecture
class SearchScreenPure extends ConsumerStatefulWidget {
  const SearchScreenPure({super.key});

  @override
  ConsumerState<SearchScreenPure> createState() => _SearchScreenPureState();
}

class _SearchScreenPureState extends ConsumerState<SearchScreenPure>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  late TabController _tabController;

  List<VideoEvent> _videoResults = [];
  List<String> _userResults = [];
  List<String> _hashtagResults = [];

  bool _isSearching = false;
  String _currentQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);

    // Request focus after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    });

    Log.info('🔍 SearchScreenPure: Initialized', category: LogCategory.video);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();

    Log.info('🔍 SearchScreenPure: Disposed', category: LogCategory.video);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query == _currentQuery) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch(query);
      }
    });
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _videoResults = [];
        _userResults = [];
        _hashtagResults = [];
        _isSearching = false;
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = query;
    });

    Log.info('🔍 SearchScreenPure: Searching for: $query', category: LogCategory.video);

    try {
      // Get all videos from provider
      final videoEventsAsync = ref.read(videoEventsProvider);

      await videoEventsAsync.when(
        loading: () async {
          // Wait a bit for loading
          await Future.delayed(const Duration(milliseconds: 500));
        },
        error: (error, stack) async {
          Log.error('🔍 SearchScreenPure: Error loading videos: $error', category: LogCategory.video);
        },
        data: (videos) async {
          // Filter videos based on search query
          final filteredVideos = videos.where((video) {
            final titleMatch = video.title?.toLowerCase().contains(query.toLowerCase()) ?? false;
            final contentMatch = video.content.toLowerCase().contains(query.toLowerCase());
            final hashtagMatch = video.hashtags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
            return titleMatch || contentMatch || hashtagMatch;
          }).toList();

          // Extract unique hashtags and users
          final hashtags = <String>{};
          final users = <String>{};

          for (final video in videos) {
            for (final tag in video.hashtags) {
              if (tag.toLowerCase().contains(query.toLowerCase())) {
                hashtags.add(tag);
              }
            }
            if (video.pubkey.toLowerCase().contains(query.toLowerCase())) {
              users.add(video.pubkey);
            }
          }

          if (mounted) {
            setState(() {
              _videoResults = filteredVideos;
              _hashtagResults = hashtags.take(20).toList();
              _userResults = users.take(20).toList();
              _isSearching = false;
            });
          }
        },
      );
    } catch (e) {
      Log.error('🔍 SearchScreenPure: Search failed: $e', category: LogCategory.video);

      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search videos, users, hashtags...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.search, color: Colors.grey),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'Videos (${_videoResults.length})'),
            Tab(text: 'Users (${_userResults.length})'),
            Tab(text: 'Hashtags (${_hashtagResults.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVideosTab(),
          _buildUsersTab(),
          _buildHashtagsTab(),
        ],
      ),
    );
  }

  Widget _buildVideosTab() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (_currentQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for videos',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            Text(
              'Enter keywords, hashtags, or user names',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return VideoGridWidget(
      key: const Key('search-videos-grid'),
      videos: _videoResults,
      crossAxisCount: 2,
      emptyMessage: 'No videos found for "$_currentQuery"',
    );
  }

  Widget _buildUsersTab() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (_currentQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for users',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            Text(
              'Find content creators and friends',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_userResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_currentQuery"',
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userResults.length,
      itemBuilder: (context, index) {
        final user = _userResults[index];
        return Card(
          color: Colors.grey[900],
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text(
                user.isNotEmpty ? user[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              user,
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Content creator',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              Log.info('🔍 SearchScreenPure: Tapped user: $user', category: LogCategory.video);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfileScreenPure(profilePubkey: user),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHashtagsTab() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (_currentQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tag, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for hashtags',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),
            Text(
              'Discover trending topics and content',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_hashtagResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.tag_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No hashtags found for "$_currentQuery"',
              style: const TextStyle(color: Colors.grey, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hashtagResults.length,
      itemBuilder: (context, index) {
        final hashtag = _hashtagResults[index];
        return Card(
          color: Colors.grey[900],
          child: ListTile(
            leading: const Icon(Icons.tag, color: Colors.green),
            title: Text(
              '#$hashtag',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Tap to view videos with this hashtag',
              style: TextStyle(color: Colors.grey),
            ),
            onTap: () {
              Log.info('🔍 SearchScreenPure: Tapped hashtag: $hashtag', category: LogCategory.video);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HashtagFeedScreen(hashtag: hashtag),
                ),
              );
            },
          ),
        );
      },
    );
  }
}