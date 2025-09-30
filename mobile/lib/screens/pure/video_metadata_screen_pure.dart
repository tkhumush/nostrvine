// ABOUTME: Pure video metadata screen using revolutionary Riverpod architecture
// ABOUTME: Adds metadata to recorded videos before publishing without VideoManager dependencies

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Pure video metadata screen using revolutionary single-controller Riverpod architecture
class VideoMetadataScreenPure extends ConsumerStatefulWidget {
  const VideoMetadataScreenPure({
    super.key,
    required this.videoFile,
    required this.duration,
  });

  final File videoFile;
  final Duration duration;

  @override
  ConsumerState<VideoMetadataScreenPure> createState() => _VideoMetadataScreenPureState();
}

class _VideoMetadataScreenPureState extends ConsumerState<VideoMetadataScreenPure> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  final List<String> _hashtags = [];
  bool _isExpiringPost = false;
  int _expirationHours = 24;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();

    Log.info('📝 VideoMetadataScreenPure: Initialized for file: ${widget.videoFile.path}',
        category: LogCategory.video);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hashtagController.dispose();
    super.dispose();

    Log.info('📝 VideoMetadataScreenPure: Disposed',
        category: LogCategory.video);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          key: const Key('back-button'),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Metadata',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _isPublishing ? null : _publishVideo,
            child: _isPublishing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Publish',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video info header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.video_library,
                    color: Colors.green,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Video Ready',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Duration: ${_formatDuration(widget.duration)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title input
                    const Text(
                      'Title',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter video title...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description input
                    const Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe your video...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[900],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hashtag input
                    const Text(
                      'Add Hashtag',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hashtagController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'hashtag',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              filled: true,
                              fillColor: Colors.grey[900],
                              prefixText: '#',
                              prefixStyle: const TextStyle(color: Colors.green),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: _addHashtag,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => _addHashtag(_hashtagController.text),
                          icon: const Icon(Icons.add, color: Colors.green),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Hashtags display
                    if (_hashtags.isNotEmpty) ...[
                      const Text(
                        'Hashtags',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _hashtags.map((hashtag) => Chip(
                          label: Text('#$hashtag'),
                          labelStyle: const TextStyle(color: Colors.white),
                          backgroundColor: Colors.green,
                          deleteIcon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onDeleted: () => _removeHashtag(hashtag),
                        )).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Expiring post option
                    SwitchListTile(
                      title: const Text(
                        'Expiring Post',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Automatically delete after $_expirationHours hours',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      value: _isExpiringPost,
                      onChanged: (value) {
                        setState(() {
                          _isExpiringPost = value;
                        });
                      },
                      activeThumbColor: Colors.green,
                    ),

                    if (_isExpiringPost) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Text(
                              'Expires in:',
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Slider(
                                value: _expirationHours.toDouble(),
                                min: 1,
                                max: 168, // 1 week
                                divisions: 167,
                                label: '$_expirationHours hours',
                                onChanged: (value) {
                                  setState(() {
                                    _expirationHours = value.round();
                                  });
                                },
                                activeColor: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addHashtag(String hashtag) {
    final trimmed = hashtag.trim().toLowerCase();
    if (trimmed.isNotEmpty && !_hashtags.contains(trimmed)) {
      setState(() {
        _hashtags.add(trimmed);
        _hashtagController.clear();
      });
    }
  }

  void _removeHashtag(String hashtag) {
    setState(() {
      _hashtags.remove(hashtag);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$twoDigitMinutes:$twoDigitSeconds';
  }

  Future<void> _publishVideo() async {
    setState(() {
      _isPublishing = true;
    });

    try {
      Log.info('📝 VideoMetadataScreenPure: Publishing video: ${widget.videoFile.path}',
          category: LogCategory.video);

      // TODO: Implement video publishing with upload service
      // For now, simulate upload
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        // Navigate back to main feed after successful upload
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      Log.error('📝 VideoMetadataScreenPure: Failed to publish video: $e',
          category: LogCategory.video);

      if (mounted) {
        setState(() {
          _isPublishing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}