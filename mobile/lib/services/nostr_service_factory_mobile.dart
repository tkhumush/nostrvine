// ABOUTME: Mobile-specific NostrService factory (kept for compatibility)
// ABOUTME: Returns standard NostrService since it now supports embedded relay

import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';

/// Create NostrService instance for mobile platforms
INostrService createEmbeddedRelayService(NostrKeyManager keyManager) {
  return NostrService(keyManager);
}