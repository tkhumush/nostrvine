// ABOUTME: Riverpod providers for monitoring internet connectivity and relay connection status
// ABOUTME: Provides real-time connection status updates using reactive streams

import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/unified_logger.dart';

part 'connection_status_providers.g.dart';

/// Connection status state
class ConnectionStatus {
  final bool isOnline;
  final bool hasInternetAccess;
  final List<ConnectivityResult> connectionTypes;
  final String? lastError;
  
  const ConnectionStatus({
    required this.isOnline,
    required this.hasInternetAccess,
    required this.connectionTypes,
    this.lastError,
  });
  
  bool get isOffline => !isOnline;
  
  String get connectionStatusText {
    if (!isOnline) return 'Offline';
    if (!hasInternetAccess) return 'No Internet Access';
    if (connectionTypes.contains(ConnectivityResult.wifi)) return 'WiFi';
    if (connectionTypes.contains(ConnectivityResult.mobile)) return 'Mobile Data';
    if (connectionTypes.contains(ConnectivityResult.ethernet)) return 'Ethernet';
    return 'Connected';
  }
  
  ConnectionStatus copyWith({
    bool? isOnline,
    bool? hasInternetAccess,
    List<ConnectivityResult>? connectionTypes,
    String? lastError,
  }) {
    return ConnectionStatus(
      isOnline: isOnline ?? this.isOnline,
      hasInternetAccess: hasInternetAccess ?? this.hasInternetAccess,
      connectionTypes: connectionTypes ?? this.connectionTypes,
      lastError: lastError,
    );
  }
}

/// Main connection status provider
@riverpod
class ConnectionStatusNotifier extends _$ConnectionStatusNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _internetCheckTimer;
  
  @override
  ConnectionStatus build() {
    // Initialize monitoring
    _initialize();
    
    // Cleanup on dispose
    ref.onDispose(() {
      _connectivitySubscription?.cancel();
      _internetCheckTimer?.cancel();
    });
    
    // Return initial state
    return const ConnectionStatus(
      isOnline: true,
      hasInternetAccess: true,
      connectionTypes: [],
    );
  }
  
  Future<void> _initialize() async {
    try {
      Log.debug('🔌 Initializing connection status provider...', 
        name: 'ConnectionStatusProvider', category: LogCategory.system);
      
      // Check initial connectivity
      await _checkConnectivity();
      
      // Listen for connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _handleConnectivityChange,
        onError: (error) {
          Log.error('Connectivity monitoring error: $error', 
            name: 'ConnectionStatusProvider', category: LogCategory.system);
          state = state.copyWith(lastError: error.toString());
        },
      );
      
      // Start periodic internet access checks
      _startInternetChecks();
      
    } catch (e) {
      Log.error('Failed to initialize connection monitoring: $e', 
        name: 'ConnectionStatusProvider', category: LogCategory.system);
      state = state.copyWith(lastError: e.toString());
    }
  }
  
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _handleConnectivityChange(results);
    } catch (e) {
      Log.error('Error checking connectivity: $e', 
        name: 'ConnectionStatusProvider', category: LogCategory.system);
      state = state.copyWith(
        isOnline: false,
        lastError: e.toString(),
      );
    }
  }
  
  Future<void> _handleConnectivityChange(List<ConnectivityResult> results) async {
    Log.debug('📡 Connectivity changed: $results', 
      name: 'ConnectionStatusProvider', category: LogCategory.system);
    
    final isOnline = results.isNotEmpty && 
                     !results.contains(ConnectivityResult.none);
    
    state = state.copyWith(
      isOnline: isOnline,
      connectionTypes: results,
    );
    
    // Check actual internet access
    if (isOnline) {
      await _checkInternetAccess();
    }
  }
  
  void _startInternetChecks() {
    _internetCheckTimer?.cancel();
    _internetCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkInternetAccess(),
    );
  }
  
  Future<void> _checkInternetAccess() async {
    if (!state.isOnline) {
      state = state.copyWith(hasInternetAccess: false);
      return;
    }
    
    try {
      // Try to resolve a reliable hostname
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      final hasAccess = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (hasAccess != state.hasInternetAccess) {
        Log.info('Internet access changed: $hasAccess', 
          name: 'ConnectionStatusProvider', category: LogCategory.system);
        state = state.copyWith(hasInternetAccess: hasAccess);
      }
      
    } catch (e) {
      if (state.hasInternetAccess) {
        Log.warning('Lost internet access: $e', 
          name: 'ConnectionStatusProvider', category: LogCategory.system);
        state = state.copyWith(hasInternetAccess: false);
      }
    }
  }
  
  /// Manually refresh connection status
  Future<void> refresh() async {
    await _checkConnectivity();
  }
}

/// Stream provider for connection changes
@riverpod
Stream<ConnectionStatus> connectionStatusStream(ConnectionStatusStreamRef ref) {
  // Get the notifier to ensure it's initialized
  final notifier = ref.watch(connectionStatusNotifierProvider.notifier);
  
  // Return a stream of state changes
  return ref.watch(connectionStatusNotifierProvider.notifier).stream;
}

/// Convenience providers
@riverpod
bool isOnline(IsOnlineRef ref) {
  return ref.watch(connectionStatusNotifierProvider).isOnline;
}

@riverpod
bool hasInternetAccess(HasInternetAccessRef ref) {
  return ref.watch(connectionStatusNotifierProvider).hasInternetAccess;
}

@riverpod
String connectionType(ConnectionTypeRef ref) {
  return ref.watch(connectionStatusNotifierProvider).connectionStatusText;
}