// ABOUTME: Key management screen for exporting, replacing, and restoring Nostr keys
// ABOUTME: Provides secure backup and recovery options for user cryptographic keys

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/theme/vine_theme.dart';

class KeyManagementScreen extends ConsumerStatefulWidget {
  const KeyManagementScreen({super.key});

  @override
  ConsumerState<KeyManagementScreen> createState() =>
      _KeyManagementScreenState();
}

class _KeyManagementScreenState extends ConsumerState<KeyManagementScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final keyManager = ref.watch(nostrKeyManagerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Key Management'),
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
      ),
      backgroundColor: Colors.black,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Warning banner
          _buildWarningBanner(),
          const SizedBox(height: 24),

          // Export nsec card
          _buildExportCard(context, keyManager),
          const SizedBox(height: 16),

          // Replace key card
          _buildReplaceKeyCard(context, keyManager),
          const SizedBox(height: 16),

          // Restore backup card
          if (keyManager.hasBackup) ...[
            _buildRestoreCard(context, keyManager),
            const SizedBox(height: 16),
          ],

          // Clear backup card
          if (keyManager.hasBackup) ...[
            _buildClearBackupCard(context, keyManager),
          ],
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withValues(alpha: 0.3),
        border: Border.all(color: Colors.red.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red.shade300, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Warning',
                  style: TextStyle(
                    color: Colors.red.shade300,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Your private key (nsec) grants full access to your account. Never share it with anyone.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard(BuildContext context, NostrKeyManager keyManager) {
    return _buildCard(
      icon: Icons.download,
      iconColor: VineTheme.vineGreen,
      title: 'Export Private Key (nsec)',
      description:
          'Copy your private key to backup or import into another Nostr app',
      buttonText: 'Export nsec',
      onPressed: _isProcessing
          ? null
          : () async {
              try {
                setState(() => _isProcessing = true);
                final nsec = keyManager.exportAsNsec();

                // Copy to clipboard
                await Clipboard.setData(ClipboardData(text: nsec));

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Private key copied to clipboard'),
                      backgroundColor: VineTheme.vineGreen,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Failed to export key: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                setState(() => _isProcessing = false);
              }
            },
    );
  }

  Widget _buildReplaceKeyCard(
      BuildContext context, NostrKeyManager keyManager) {
    return _buildCard(
      icon: Icons.refresh,
      iconColor: Colors.orange,
      title: 'Replace Key with Backup',
      description:
          'Generate a new key and backup your current one. Your old key can be restored later.',
      buttonText: 'Replace Key',
      onPressed: _isProcessing
          ? null
          : () => _showReplaceKeyDialog(context, keyManager),
    );
  }

  Widget _buildRestoreCard(BuildContext context, NostrKeyManager keyManager) {
    return _buildCard(
      icon: Icons.restore,
      iconColor: Colors.blue,
      title: 'Restore Backup Key',
      description:
          'Restore your backed-up key as your active key. Your current key will become the backup.',
      buttonText: 'Restore Backup',
      onPressed: _isProcessing
          ? null
          : () => _showRestoreDialog(context, keyManager),
    );
  }

  Widget _buildClearBackupCard(
      BuildContext context, NostrKeyManager keyManager) {
    return _buildCard(
      icon: Icons.delete_forever,
      iconColor: Colors.red,
      title: 'Clear Backup',
      description:
          'Permanently delete your backup key. This cannot be undone.',
      buttonText: 'Clear Backup',
      onPressed:
          _isProcessing ? null : () => _showClearBackupDialog(context, keyManager),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReplaceKeyDialog(
      BuildContext context, NostrKeyManager keyManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Replace Key with Backup?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will:\n'
          '• Generate a new private key\n'
          '• Backup your current key securely\n'
          '• You can restore your old key later\n\n'
          'Your current identity will be replaced with a new one.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                setState(() => _isProcessing = true);
                await keyManager.replaceKeyWithBackup();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Key replaced successfully'),
                      backgroundColor: VineTheme.vineGreen,
                    ),
                  );
                  setState(() {}); // Refresh UI to show restore option
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Failed to replace key: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                setState(() => _isProcessing = false);
              }
            },
            child: const Text('Replace Key'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, NostrKeyManager keyManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Restore Backup Key?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will:\n'
          '• Restore your backed-up key as active\n'
          '• Backup your current key\n'
          '• Switch back to your previous identity',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                setState(() => _isProcessing = true);
                await keyManager.restoreFromBackup();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Backup key restored successfully'),
                      backgroundColor: VineTheme.vineGreen,
                    ),
                  );
                  setState(() {}); // Refresh UI
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Failed to restore backup: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                setState(() => _isProcessing = false);
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showClearBackupDialog(
      BuildContext context, NostrKeyManager keyManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Clear Backup?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete your backup key.\n\n'
          'This action cannot be undone.\n\n'
          'Your active key will remain unchanged.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                setState(() => _isProcessing = true);
                await keyManager.clearBackup();

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Backup cleared successfully'),
                      backgroundColor: VineTheme.vineGreen,
                    ),
                  );
                  setState(() {}); // Refresh UI to hide backup options
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Failed to clear backup: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                setState(() => _isProcessing = false);
              }
            },
            child: const Text('Clear Backup'),
          ),
        ],
      ),
    );
  }
}