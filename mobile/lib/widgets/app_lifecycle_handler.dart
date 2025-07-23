// ABOUTME: App lifecycle handler that pauses all videos when app goes to background
// ABOUTME: Ensures videos never play when app is not visible

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/video_visibility_providers.dart';
import '../utils/unified_logger.dart';

/// Handles app lifecycle events for video playback
class AppLifecycleHandler extends ConsumerStatefulWidget {
  final Widget child;
  
  const AppLifecycleHandler({
    super.key,
    required this.child,
  });
  
  @override
  ConsumerState<AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends ConsumerState<AppLifecycleHandler> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final visibilityNotifier = ref.read(videoVisibilityNotifierProvider.notifier);
    
    switch (state) {
      case AppLifecycleState.resumed:
        Log.info('📱 App resumed - enabling visibility-based playback', 
            name: 'AppLifecycleHandler', category: LogCategory.system);
        visibilityNotifier.resumeVisibilityBasedPlayback();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        Log.info('📱 App backgrounded - pausing all videos', 
            name: 'AppLifecycleHandler', category: LogCategory.system);
        visibilityNotifier.pauseAllVideos();
        break;
        
      case AppLifecycleState.detached:
        // App is being terminated
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}