// ABOUTME: Riverpod provider for tracking app foreground/background state
// ABOUTME: Ensures video visibility callbacks only trigger when app is actually in foreground

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_foreground_provider.g.dart';

/// State notifier for tracking app foreground/background state
class AppForegroundNotifier extends StateNotifier<bool> {
  AppForegroundNotifier() : super(true); // Start as foreground

  void setForeground(bool isForeground) {
    state = isForeground;
  }
}

/// Provider for app foreground state - true when app is in foreground, false when backgrounded
@riverpod
AppForegroundNotifier appForegroundNotifier(Ref ref) {
  return AppForegroundNotifier();
}

/// Convenience provider to watch just the boolean state
@riverpod
bool isAppInForeground(Ref ref) {
  return ref.watch(appForegroundNotifierProvider);
}
