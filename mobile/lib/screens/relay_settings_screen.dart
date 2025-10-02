// ABOUTME: Screen for managing Nostr relay connections and settings
// ABOUTME: Allows users to add, remove, and configure external relay preferences

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/camera_fab.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';

/// Screen for managing Nostr relay settings
class RelaySettingsScreen extends ConsumerStatefulWidget {
  const RelaySettingsScreen({super.key});

  @override
  ConsumerState<RelaySettingsScreen> createState() =>
      _RelaySettingsScreenState();
}

class _RelaySettingsScreenState extends ConsumerState<RelaySettingsScreen> {

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);
    final externalRelays = nostrService.relays;

    Log.info('Displaying ${externalRelays.length} external relays',
        name: 'RelaySettingsScreen');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relay Settings'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'These are external relays that sync with your embedded relay',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Relay list
          Expanded(
            child: externalRelays.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off,
                            color: Colors.grey[600], size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'No external relays configured',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add relays to sync your content',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () => _retryConnection(),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Retry Connection',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VineTheme.vineGreen,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Retry button at the top if relays exist but not connected
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton.icon(
                          onPressed: () => _retryConnection(),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Retry Connection',
                              style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: VineTheme.vineGreen,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: externalRelays.length,
                          itemBuilder: (context, index) {
                            final relay = externalRelays[index];

                            return ListTile(
                              leading: Icon(
                                Icons.cloud,
                                color: Colors.green[400],
                                size: 20,
                              ),
                              title: Text(
                                relay,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                'External relay',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeRelay(relay),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: const CameraFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: VineBottomNav(),
    );
  }

  Future<void> _removeRelay(String relayUrl) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Remove Relay?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove this relay?\n\n$relayUrl',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final nostrService = ref.read(nostrServiceProvider);
      await nostrService.removeRelay(relayUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed relay: $relayUrl'),
            backgroundColor: Colors.orange[700],
          ),
        );
      }

      Log.info('Successfully removed relay: $relayUrl',
          name: 'RelaySettingsScreen');
    } catch (e) {
      Log.error('Failed to remove relay: $e', name: 'RelaySettingsScreen');
      _showError('Failed to remove relay: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  Future<void> _retryConnection() async {
    try {
      final nostrService = ref.read(nostrServiceProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retrying relay connections...'),
          backgroundColor: Colors.orange,
        ),
      );

      await nostrService.retryInitialization();

      // Check if any relays are now connected
      final connectedCount = nostrService.connectedRelayCount;

      if (connectedCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to $connectedCount relay(s)!'),
              backgroundColor: Colors.green[700],
            ),
          );
        }

        // Trigger a refresh of video feeds
        final videoService = ref.read(videoEventServiceProvider);
        await videoService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          replace: true,
        );
      } else {
        _showError(
            'Failed to connect to relays. Please check your network connection.');
      }
    } catch (e) {
      Log.error('Failed to retry connection: $e', name: 'RelaySettingsScreen');
      _showError('Connection retry failed: ${e.toString()}');
    }
  }
}
