// ABOUTME: Enhanced NostrService with multiple relay support for trending videos
// ABOUTME: Adds popular Nostr relays to improve video discovery

import 'dart:async';

import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart' as embedded;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Enhanced NostrService with multiple relay support
class NostrServiceEnhanced implements INostrService {
  NostrServiceEnhanced(this._keyManager);
  
  final NostrKeyManager _keyManager;
  final Map<String, StreamController<Event>> _subscriptions = {};
  final Map<String, bool> _relayAuthStates = {};
  final _authStateController = StreamController<Map<String, bool>>.broadcast();
  
  embedded.EmbeddedNostrRelay? _embeddedRelay;
  
  bool _isInitialized = false;
  bool _isDisposed = false;
  final List<String> _configuredRelays = [];
  
  // Popular Nostr relays for better video discovery
  static const List<String> popularRelays = [
    'wss://relay3.openvine.co',     // OpenVine's relay
    'wss://relay.damus.io',         // Popular general relay
    'wss://relay.nostr.band',       // Good for discovery
    'wss://nos.lol',                // Fast relay
    'wss://relay.snort.social',     // Social-focused relay
    'wss://relay.primal.net',       // Primal's relay
  ];
  
  @override
  Future<void> initialize({List<String>? customRelays, bool enableP2P = true}) async {
    if (_isDisposed) throw StateError('NostrService is disposed');
    if (_isInitialized) return;
    
    Log.info('🚀 Enhanced NostrService: Starting initialization with multiple relays',
        name: 'NostrServiceEnhanced', category: LogCategory.system);
    
    try {
      // Initialize embedded relay
      _embeddedRelay = embedded.EmbeddedNostrRelay();
      await _embeddedRelay!.initialize(
        enableGarbageCollection: true,
      );
      Log.info('✅ Embedded relay initialized',
          name: 'NostrServiceEnhanced', category: LogCategory.system);
      
      // Add all popular relays for better discovery
      final relaysToAdd = customRelays ?? popularRelays;
      
      for (final relayUrl in relaysToAdd) {
        try {
          await _embeddedRelay!.addExternalRelay(relayUrl);
          _configuredRelays.add(relayUrl);
          Log.info('✅ Added relay: $relayUrl',
              name: 'NostrServiceEnhanced', category: LogCategory.system);
        } catch (e) {
          Log.warning('⚠️ Failed to add relay $relayUrl: $e',
              name: 'NostrServiceEnhanced', category: LogCategory.system);
        }
      }
      
      _isInitialized = true;
      Log.info('🎉 Initialization complete with ${_configuredRelays.length} relays',
          name: 'NostrServiceEnhanced', category: LogCategory.system);
      
      // Log connected relays for debugging
      final connected = _embeddedRelay?.connectedRelays ?? [];
      Log.info('📡 Connected to ${connected.length} relays: ${connected.join(", ")}',
          name: 'NostrServiceEnhanced', category: LogCategory.system);
      
    } catch (e) {
      Log.error('❌ Failed to initialize: $e',
          name: 'NostrServiceEnhanced', category: LogCategory.system);
      throw StateError('Failed to initialize embedded relay: $e');
    }
  }
  
  /// Fetch specific videos by ID with improved relay discovery
  Future<List<Event>> fetchVideosByIds(List<String> eventIds) async {
    if (eventIds.isEmpty) return [];
    
    Log.info('📡 Fetching ${eventIds.length} videos from ${_configuredRelays.length} relays',
        name: 'NostrServiceEnhanced', category: LogCategory.system);
    
    final filter = nostr.Filter(
      ids: eventIds,
      kinds: [32222], // Video events
    );
    
    final events = <String, Event>{};
    final completer = Completer<void>();
    
    // Subscribe with timeout
    final stream = subscribeToEvents(filters: [filter]);
    final subscription = stream.listen(
      (event) {
        events[event.id] = event;
        Log.verbose('✅ Found video ${event.id.substring(0, 8)}...',
            name: 'NostrServiceEnhanced', category: LogCategory.system);
        
        // Complete early if we have most videos
        if (events.length >= eventIds.length * 0.8) {
          if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (error) {
        Log.error('Stream error: $error',
            name: 'NostrServiceEnhanced', category: LogCategory.system);
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
    );
    
    // Wait with timeout
    await Future.any([
      completer.future,
      Future.delayed(const Duration(seconds: 10)),
    ]);
    
    await subscription.cancel();
    
    Log.info('📊 Fetched ${events.length}/${eventIds.length} videos',
        name: 'NostrServiceEnhanced', category: LogCategory.system);
    
    // Log missing videos for debugging
    final foundIds = events.keys.toSet();
    final missingIds = eventIds.where((id) => !foundIds.contains(id)).toList();
    if (missingIds.isNotEmpty) {
      Log.warning('⚠️ Missing ${missingIds.length} videos: ${missingIds.take(3).map((id) => id.substring(0, 8)).join(", ")}...',
          name: 'NostrServiceEnhanced', category: LogCategory.system);
    }
    
    return events.values.toList();
  }
  
  // ... rest of the INostrService implementation methods ...
  // (These would be copied from the original NostrService)
  
  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isDisposed => _isDisposed;

  @override
  List<String> get connectedRelays => _embeddedRelay?.connectedRelays ?? [];

  @override
  String? get publicKey => _keyManager.publicKey;

  @override
  bool get hasKeys => _keyManager.hasKeys;

  @override
  NostrKeyManager get keyManager => _keyManager;

  @override
  int get relayCount => _configuredRelays.length;

  @override
  int get connectedRelayCount => _embeddedRelay?.connectedRelays.length ?? 0;

  @override
  List<String> get relays => List.from(_configuredRelays);

  @override
  Map<String, dynamic> get relayStatuses {
    final statuses = <String, dynamic>{};
    final connectedRelays = _embeddedRelay?.connectedRelays ?? [];
    for (final relayUrl in _configuredRelays) {
      final isConnected = connectedRelays.contains(relayUrl);
      statuses[relayUrl] = {
        'connected': isConnected,
        'authenticated': isConnected,
      };
      _relayAuthStates[relayUrl] = isConnected;
    }
    return statuses;
  }

  @override
  Map<String, bool> get relayAuthStates => Map.from(_relayAuthStates);

  @override
  Stream<Map<String, bool>> get authStateStream => _authStateController.stream;

  @override
  bool isRelayAuthenticated(String relayUrl) {
    final connectedRelays = _embeddedRelay?.connectedRelays ?? [];
    return connectedRelays.contains(relayUrl);
  }

  @override
  bool get isVineRelayAuthenticated {
    return isRelayAuthenticated('wss://relay3.openvine.co');
  }
  
  @override
  Stream<Event> subscribeToEvents({
    required List<nostr.Filter> filters,
    String? subscriptionId,
  }) {
    subscriptionId ??= DateTime.now().millisecondsSinceEpoch.toString();
    
    final controller = StreamController<Event>.broadcast(
      onCancel: () {
        _subscriptions.remove(subscriptionId);
        _embeddedRelay?.unsubscribe(subscriptionId!);
      },
    );
    
    _subscriptions[subscriptionId] = controller;
    
    // Subscribe via embedded relay
    _embeddedRelay?.subscribe(
      filters: filters,
      subscriptionId: subscriptionId,
      onEvent: (event) {
        if (!controller.isClosed) {
          controller.add(event);
        }
      },
    );
    
    return controller.stream;
  }
  
  @override
  Future<void> unsubscribe(String subscriptionId) async {
    final controller = _subscriptions[subscriptionId];
    if (controller != null) {
      await controller.close();
      _subscriptions.remove(subscriptionId);
      _embeddedRelay?.unsubscribe(subscriptionId);
    }
  }
  
  @override
  Future<void> publishEvent(Event event) async {
    if (!_isInitialized) {
      throw StateError('NostrService not initialized');
    }
    
    await _embeddedRelay?.publishEvent(event);
  }
  
  @override
  Future<void> addRelay(String relayUrl) async {
    if (!_configuredRelays.contains(relayUrl)) {
      await _embeddedRelay?.addExternalRelay(relayUrl);
      _configuredRelays.add(relayUrl);
    }
  }
  
  @override
  Future<void> removeRelay(String relayUrl) async {
    if (_configuredRelays.contains(relayUrl)) {
      await _embeddedRelay?.removeExternalRelay(relayUrl);
      _configuredRelays.remove(relayUrl);
    }
  }
  
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    for (final controller in _subscriptions.values) {
      await controller.close();
    }
    _subscriptions.clear();
    
    await _authStateController.close();
    await _embeddedRelay?.dispose();
    
    _isDisposed = true;
  }
  
  // Additional interface methods would go here...
}