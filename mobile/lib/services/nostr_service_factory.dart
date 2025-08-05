// ABOUTME: Factory for creating platform-appropriate NostrService implementations
// ABOUTME: Handles conditional service creation for web vs mobile platforms

import 'package:flutter/foundation.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/nostr_service.dart';

/// Factory class for creating platform-appropriate NostrService implementations
class NostrServiceFactory {
  /// Create the appropriate NostrService for the current platform
  static INostrService create(NostrKeyManager keyManager) {
    // Always use NostrService which has embedded relay support for all platforms
    print('NostrServiceFactory: Creating NostrService with embedded relay support');
    return NostrService(keyManager);
  }

  /// Initialize the created service with appropriate parameters
  static Future<void> initialize(INostrService service) async {
    // Initialize with P2P enabled for mobile platforms, disabled for web
    await (service as dynamic).initialize(enableP2P: !kIsWeb);
  }

  /// Check if P2P features are available on current platform and service
  static bool isP2PAvailable(INostrService service) {
    // P2P is available on mobile platforms with NostrService
    return !kIsWeb;
  }
}

