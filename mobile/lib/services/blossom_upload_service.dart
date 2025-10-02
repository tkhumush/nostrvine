// ABOUTME: Service for uploading videos to user-configured Blossom media servers
// ABOUTME: Supports Blossom BUD-01 authentication and returns media URLs from any Blossom server

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/hash_util.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result type for Blossom upload operations
class BlossomUploadResult {
  final bool success;
  final String? videoId;
  final String? cdnUrl;
  final String? gifUrl;
  final String? thumbnailUrl;
  final String? blurhash;
  final String? errorMessage;

  const BlossomUploadResult({
    required this.success,
    this.videoId,
    this.cdnUrl,
    this.gifUrl,
    this.thumbnailUrl,
    this.blurhash,
    this.errorMessage,
  });
}

class BlossomUploadService {
  static const String _blossomServerKey = 'blossom_server_url';
  static const String _useBlossomKey = 'use_blossom_upload';
  static const String defaultBlossomServer = 'https://cf-stream-service-prod.protestnet.workers.dev';
  
  final AuthService authService;
  final INostrService nostrService;
  final Dio dio;
  
  BlossomUploadService({
    required this.authService, 
    required this.nostrService,
    Dio? dio,
  }) : dio = dio ?? Dio();
  
  /// Get the configured Blossom server URL
  Future<String?> getBlossomServer() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_blossomServerKey);
    // If nothing is stored, return default. If empty string is stored, return it.
    return stored ?? defaultBlossomServer;
  }
  
  /// Set the Blossom server URL
  Future<void> setBlossomServer(String? serverUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (serverUrl != null && serverUrl.isNotEmpty) {
      await prefs.setString(_blossomServerKey, serverUrl);
    } else {
      // Store empty string to indicate "no server configured"
      await prefs.setString(_blossomServerKey, '');
    }
  }
  
  /// Check if Blossom upload is enabled
  Future<bool> isBlossomEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useBlossomKey) ?? true; // Default to true
  }
  
  /// Enable or disable Blossom upload
  Future<void> setBlossomEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBlossomKey, enabled);
  }
  

  /// Create a Blossom authentication event for upload
  Future<Event?> _createBlossomAuthEvent({
    required String url,
    required String method,
    required String fileHash,
    required int fileSize,
  }) async {
    try {
      // Blossom requires these tags (BUD-01):
      // - t: "upload" to indicate upload request
      // - expiration: Unix timestamp when auth expires
      // - x: SHA-256 hash of the file (optional but recommended)

      final now = DateTime.now();
      final expiration = now.add(const Duration(minutes: 5)); // 5 minute expiration
      final expirationTimestamp = expiration.millisecondsSinceEpoch ~/ 1000;

      // Build tags for Blossom auth event (kind 24242)
      final tags = [
        ['t', 'upload'],
        ['expiration', expirationTimestamp.toString()],
        ['x', fileHash], // SHA-256 hash of the file
      ];

      // Create human-readable content explaining the action
      const content = 'Upload video to Blossom server';

      // Use AuthService to create and sign the event (established pattern)
      final signedEvent = await authService.createAndSignEvent(
        kind: 24242, // Blossom auth event kind
        content: content,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error('Failed to create/sign Blossom auth event via AuthService',
            name: 'BlossomUploadService', category: LogCategory.video);
        return null;
      }

      Log.info('Created Blossom auth event: ${signedEvent.id}',
          name: 'BlossomUploadService', category: LogCategory.video);

      return signedEvent;
    } catch (e) {
      Log.error('Error creating Blossom auth event: $e',
          name: 'BlossomUploadService', category: LogCategory.video);
      return null;
    }
  }

  /// Upload a video file to the configured Blossom server
  /// 
  /// This method currently returns a placeholder implementation.
  /// The actual Blossom upload will be implemented using the SDK's
  /// BolssomUploader when the Nostr service integration is ready.
  Future<BlossomUploadResult> uploadVideo({
    required File videoFile,
    required String nostrPubkey,
    required String title,
    String? description,
    List<String>? hashtags,
    void Function(double)? onProgress,
  }) async {
    try {
      // Check if Blossom is enabled and configured
      final isEnabled = await isBlossomEnabled();
      if (!isEnabled) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Blossom upload is not enabled',
        );
      }
      
      final serverUrl = await getBlossomServer();
      if (serverUrl == null || serverUrl.isEmpty) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'No Blossom server configured',
        );
      }
      
      // Parse and validate server URL
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Invalid Blossom server URL',
        );
      }
      
      // Check authentication after URL validation
      if (!authService.isAuthenticated) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        );
      }
      
      Log.info('Uploading to Blossom server: $serverUrl',
          name: 'BlossomUploadService', category: LogCategory.video);

      Log.info('Checking if user is authenticated...',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Check if user is authenticated (has keys available)
      if (!authService.isAuthenticated) {
        Log.error('❌ User not authenticated - cannot sign Blossom requests',
            name: 'BlossomUploadService', category: LogCategory.video);
        return BlossomUploadResult(
          success: false,
          errorMessage: 'User not authenticated - please sign in to upload',
        );
      }

      Log.info('✅ User is authenticated, can create signed events',
          name: 'BlossomUploadService', category: LogCategory.video);
      
      // For now, we'll use a simplified approach since the embedded relay doesn't expose Nostr SDK
      // We'll need to create the upload using direct HTTP calls with Blossom BUD-01 auth
      Log.warning('Blossom upload using SDK integration is pending - needs NostrService refactoring',
          name: 'BlossomUploadService', category: LogCategory.video);
      
      // Report initial progress
      onProgress?.call(0.1);

      Log.info('Reading file bytes for hash calculation...',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Calculate file hash for Blossom
      final fileBytes = await videoFile.readAsBytes();
      Log.info('File bytes read: ${fileBytes.length} bytes',
          name: 'BlossomUploadService', category: LogCategory.video);

      Log.info('Calculating SHA-256 hash...',
          name: 'BlossomUploadService', category: LogCategory.video);
      final fileHash = HashUtil.sha256Hash(fileBytes);
      final fileSize = fileBytes.length;
      
      Log.info('File hash: $fileHash, size: $fileSize bytes',
          name: 'BlossomUploadService', category: LogCategory.video);
      
      // Create Blossom auth event
      final authEvent = await _createBlossomAuthEvent(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
      );

      if (authEvent == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
        );
      }
      
      // Prepare authorization header
      final authEventJson = jsonEncode(authEvent.toJson());
      final authHeader = 'Nostr ${base64.encode(utf8.encode(authEventJson))}';

      Log.info('🔐 Auth event JSON: $authEventJson',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('🔐 Base64 auth payload: ${base64.encode(utf8.encode(authEventJson))}',
          name: 'BlossomUploadService', category: LogCategory.video);

      Log.info('Step 1: Requesting upload URL from Blossom server',
          name: 'BlossomUploadService', category: LogCategory.video);

      final uploadRequestData = {
        'size': fileSize,
        'type': 'video/mp4',
        'sha256': fileHash,
      };
      final uploadRequestJson = jsonEncode(uploadRequestData);

      Log.info('🔍 Upload request details:',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('  📍 URL: $serverUrl/upload',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('  📝 Request body: $uploadRequestJson',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('  🔐 Auth header length: ${authHeader.length} chars',
          name: 'BlossomUploadService', category: LogCategory.video);
      Log.info('  🔐 Auth header preview: ${authHeader.substring(0, 50)}...',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Step 1: Request upload URL with metadata (BUD-01 compliant)
      final metadataResponse = await dio.put(
        '$serverUrl/upload',
        data: uploadRequestJson,
        options: Options(
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Handle HTTP 409 Conflict - file already exists on server
      if (metadataResponse.statusCode == 409) {
        Log.info('✅ File already exists on Blossom server (hash: $fileHash), treating as successful upload',
            name: 'BlossomUploadService', category: LogCategory.video);
        return BlossomUploadResult(
          success: true,
          videoId: fileHash,  // Use file hash as video ID
          cdnUrl: '$serverUrl/$fileHash',
          errorMessage: 'File already exists on server',
        );
      }

      if (metadataResponse.statusCode != 200 && metadataResponse.statusCode != 201) {
        Log.error('❌ Failed to get upload URL: ${metadataResponse.statusCode} - ${metadataResponse.data}',
            name: 'BlossomUploadService', category: LogCategory.video);
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to get upload URL: ${metadataResponse.statusCode} - ${metadataResponse.data}',
        );
      }

      final uploadInfo = metadataResponse.data as Map<String, dynamic>;
      final uploadURL = uploadInfo['uploadURL'] as String?;
      final uid = uploadInfo['uid'] as String?;

      if (uploadURL == null) {
        Log.error('❌ No uploadURL returned from Blossom server',
            name: 'BlossomUploadService', category: LogCategory.video);
        return BlossomUploadResult(
          success: false,
          errorMessage: 'No uploadURL returned from Blossom server',
        );
      }

      Log.info('✅ Got upload URL: $uploadURL (uid: $uid)',
          name: 'BlossomUploadService', category: LogCategory.video);
      onProgress?.call(0.2);

      Log.info('Step 2: Uploading binary data to provided URL',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Step 2: Upload binary data to the provided URL using multipart/form-data
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: 'video.mp4',
        ),
      });

      final response = await dio.post(
        uploadURL,
        data: formData,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) {
            // Progress from 20% to 80% during upload
            final progress = 0.2 + (sent / total) * 0.6;
            onProgress?.call(progress);
          }
        },
      );

      Log.info('Blossom server response: ${response.statusCode}',
            name: 'BlossomUploadService', category: LogCategory.video);
        Log.info('Response headers: ${response.headers}',
            name: 'BlossomUploadService', category: LogCategory.video);
        Log.info('Response data type: ${response.data.runtimeType}',
            name: 'BlossomUploadService', category: LogCategory.video);
        Log.info('Response data: ${response.data}',
            name: 'BlossomUploadService', category: LogCategory.video);

        if (response.statusCode == 200 || response.statusCode == 201) {
          Log.info('✅ Binary upload completed successfully',
              name: 'BlossomUploadService', category: LogCategory.video);
          onProgress?.call(0.9);

          Log.info('Step 3: Getting blob descriptor from Blossom server',
              name: 'BlossomUploadService', category: LogCategory.video);

          // Step 3: Get blob descriptor (BUD-01 compliant)
          final blobResponse = await dio.get(
            '$serverUrl/$fileHash',
            options: Options(
              validateStatus: (status) => status != null && status < 500,
            ),
          );

          if (blobResponse.statusCode == 200) {
            final blobData = blobResponse.data;

            if (blobData is Map) {
              final sha256 = blobData['sha256'] as String?;
              final mediaUrl = blobData['url'] as String?;
              final hlsUrl = blobData['hls'] as String?;
              final thumbnailUrl = blobData['thumbnail'] as String?;

              if (mediaUrl != null && mediaUrl.isNotEmpty) {
                // Extract video ID from URL (use uid if available, otherwise URL component)
                final videoId = uid ?? mediaUrl.split('/').last;

                onProgress?.call(1.0);

                Log.info('✅ Blossom upload successful: $mediaUrl',
                    name: 'BlossomUploadService', category: LogCategory.video);
                Log.info('  HLS: $hlsUrl', name: 'BlossomUploadService', category: LogCategory.video);
                Log.info('  Thumbnail: $thumbnailUrl', name: 'BlossomUploadService', category: LogCategory.video);
                Log.info('  SHA256: $sha256', name: 'BlossomUploadService', category: LogCategory.video);

                return BlossomUploadResult(
                  success: true,
                  cdnUrl: mediaUrl,
                  videoId: videoId,
                  thumbnailUrl: thumbnailUrl,
                );
              } else {
                return BlossomUploadResult(
                  success: false,
                  errorMessage: 'Invalid blob descriptor from Blossom server: missing URL',
                );
              }
            } else {
              return BlossomUploadResult(
                success: false,
                errorMessage: 'Invalid blob descriptor format from Blossom server',
              );
            }
          } else if (blobResponse.statusCode == 202) {
            // Video is still processing - this is success, just not ready yet
            final videoId = uid ?? fileHash.substring(0, 16); // Use uid or hash prefix

            Log.info('🔄 Video uploaded successfully, still processing (HTTP 202)',
                name: 'BlossomUploadService', category: LogCategory.video);
            Log.info('  Video ID: $videoId', name: 'BlossomUploadService', category: LogCategory.video);

            onProgress?.call(0.9); // 90% - upload complete, processing in progress

            return BlossomUploadResult(
              success: true,
              videoId: videoId,
              cdnUrl: '$serverUrl/$fileHash', // Basic URL for now
              errorMessage: 'processing', // Special flag indicating processing state
            );
          } else {
            Log.error('❌ Failed to get blob descriptor: ${blobResponse.statusCode} - ${blobResponse.data}',
                name: 'BlossomUploadService', category: LogCategory.video);
            return BlossomUploadResult(
              success: false,
              errorMessage: 'Failed to get blob descriptor: ${blobResponse.statusCode} - ${blobResponse.data}',
            );
          }
        } else if (response.statusCode == 401) {
          Log.error('❌ Blossom authentication failed: ${response.data}',
              name: 'BlossomUploadService', category: LogCategory.video);
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Authentication failed - check your Nostr keys. Server response: ${response.data}',
          );
        } else if (response.statusCode == 413) {
          Log.error('❌ Blossom file too large: ${response.data}',
              name: 'BlossomUploadService', category: LogCategory.video);
          return BlossomUploadResult(
            success: false,
            errorMessage: 'File too large for this Blossom server. Server response: ${response.data}',
          );
        } else {
          Log.error('❌ Blossom server error ${response.statusCode}: ${response.data}',
              name: 'BlossomUploadService', category: LogCategory.video);
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Blossom server error: ${response.statusCode} - ${response.statusMessage}. Server response: ${response.data}',
          );
        }
    } on DioException catch (e) {
      Log.error('Blossom upload network error: ${e.message}',
          name: 'BlossomUploadService', category: LogCategory.video);

      if (e.type == DioExceptionType.connectionTimeout) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Connection timeout - check server URL',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Cannot connect to Blossom server',
        );
      } else {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Network error: ${e.message}',
        );
      }
    } catch (e) {
      Log.error('Blossom upload error: $e',
          name: 'BlossomUploadService', category: LogCategory.video);
      
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Blossom upload failed: $e',
      );
    }
  }

  /// Upload an image file (e.g. thumbnail) to the configured Blossom server
  ///
  /// This uses the same Blossom BUD-01 protocol as video uploads but with image MIME type
  Future<BlossomUploadResult> uploadImage({
    required File imageFile,
    required String nostrPubkey,
    String mimeType = 'image/jpeg',
    void Function(double)? onProgress,
  }) async {
    try {
      // Check if Blossom is enabled and configured
      final isEnabled = await isBlossomEnabled();
      if (!isEnabled) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Blossom upload is not enabled',
        );
      }

      final serverUrl = await getBlossomServer();
      if (serverUrl == null || serverUrl.isEmpty) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'No Blossom server configured',
        );
      }

      // Parse and validate server URL
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Invalid Blossom server URL',
        );
      }

      // Check authentication
      if (!authService.isAuthenticated) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Not authenticated',
        );
      }

      Log.info('Uploading image to Blossom server: $serverUrl',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Report initial progress
      onProgress?.call(0.1);

      // Calculate file hash for Blossom
      final fileBytes = await imageFile.readAsBytes();
      final fileHash = HashUtil.sha256Hash(fileBytes);
      final fileSize = fileBytes.length;

      Log.info('Image file hash: $fileHash, size: $fileSize bytes',
          name: 'BlossomUploadService', category: LogCategory.video);

      // Create Blossom auth event
      final authEvent = await _createBlossomAuthEvent(
        url: '$serverUrl/upload',
        method: 'PUT',
        fileHash: fileHash,
        fileSize: fileSize,
      );

      if (authEvent == null) {
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Failed to create Blossom authentication',
        );
      }

      // Prepare authorization header
      final authEventJson = jsonEncode(authEvent.toJson());
      final authHeader = 'Nostr ${base64.encode(utf8.encode(authEventJson))}';

      Log.info('Step 1: Requesting upload URL for image from Blossom server',
          name: 'BlossomUploadService', category: LogCategory.video);

      final uploadRequestData = {
        'size': fileSize,
        'type': mimeType,
        'sha256': fileHash,
      };
      final uploadRequestJson = jsonEncode(uploadRequestData);

      // Step 1: Request upload URL with metadata (BUD-01 compliant)
      final metadataResponse = await dio.put(
        '$serverUrl/upload',
        data: uploadRequestJson,
        options: Options(
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      // Handle HTTP 409 Conflict - file already exists on server
      if (metadataResponse.statusCode == 409) {
        Log.info('✅ Image already exists on Blossom server (hash: $fileHash)',
            name: 'BlossomUploadService', category: LogCategory.video);

        onProgress?.call(1.0);

        // Return success with the existing file URL
        return BlossomUploadResult(
          success: true,
          cdnUrl: '$serverUrl/$fileHash',
          videoId: fileHash,
        );
      }

      // Check for successful metadata upload
      if (metadataResponse.statusCode == 200) {
        Log.info('✅ Step 1 complete - got upload URL',
            name: 'BlossomUploadService', category: LogCategory.video);

        onProgress?.call(0.3);

        final uploadUrl = metadataResponse.data['url'] as String?;
        final uid = metadataResponse.data['uid'] as String?;

        if (uploadUrl == null) {
          return BlossomUploadResult(
            success: false,
            errorMessage: 'No upload URL provided by Blossom server',
          );
        }

        Log.info('Step 2: Uploading image data to $uploadUrl',
            name: 'BlossomUploadService', category: LogCategory.video);

        // Step 2: Upload actual image data to the provided URL
        final response = await dio.put(
          uploadUrl,
          data: Stream.fromIterable([fileBytes]),
          options: Options(
            headers: {
              'Content-Type': mimeType,
              'Content-Length': fileSize.toString(),
            },
            validateStatus: (status) => status != null && status < 500,
          ),
          onSendProgress: (sent, total) {
            if (total > 0) {
              final uploadProgress = 0.3 + (sent / total) * 0.6; // 30% to 90%
              onProgress?.call(uploadProgress);
            }
          },
        );

        onProgress?.call(0.95);

        if (response.statusCode == 200 || response.statusCode == 201) {
          Log.info('✅ Step 2 complete - image uploaded successfully',
              name: 'BlossomUploadService', category: LogCategory.video);

          // Step 3: Get blob descriptor to confirm upload
          final blobResponse = await dio.get('$serverUrl/$fileHash');

          if (blobResponse.statusCode == 200) {
            final blobData = blobResponse.data;

            if (blobData is Map) {
              final imageUrl = blobData['url'] as String?;

              if (imageUrl != null && imageUrl.isNotEmpty) {
                final imageId = uid ?? imageUrl.split('/').last;

                onProgress?.call(1.0);

                Log.info('✅ Image upload successful: $imageUrl',
                    name: 'BlossomUploadService', category: LogCategory.video);

                return BlossomUploadResult(
                  success: true,
                  cdnUrl: imageUrl,
                  videoId: imageId,
                );
              } else {
                return BlossomUploadResult(
                  success: false,
                  errorMessage: 'Invalid blob descriptor: missing URL',
                );
              }
            } else {
              return BlossomUploadResult(
                success: false,
                errorMessage: 'Invalid blob descriptor format',
              );
            }
          } else {
            Log.error('❌ Failed to get blob descriptor: ${blobResponse.statusCode}',
                name: 'BlossomUploadService', category: LogCategory.video);
            return BlossomUploadResult(
              success: false,
              errorMessage: 'Failed to get blob descriptor: ${blobResponse.statusCode}',
            );
          }
        } else if (response.statusCode == 401) {
          Log.error('❌ Blossom authentication failed: ${response.data}',
              name: 'BlossomUploadService', category: LogCategory.video);
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Authentication failed - check your Nostr keys',
          );
        } else {
          Log.error('❌ Image upload failed: ${response.statusCode} - ${response.data}',
              name: 'BlossomUploadService', category: LogCategory.video);
          return BlossomUploadResult(
            success: false,
            errorMessage: 'Image upload failed: ${response.statusCode}',
          );
        }
      } else {
        Log.error('❌ Metadata upload failed: ${metadataResponse.statusCode}',
            name: 'BlossomUploadService', category: LogCategory.video);
        return BlossomUploadResult(
          success: false,
          errorMessage: 'Metadata upload failed: ${metadataResponse.statusCode}',
        );
      }
    } catch (e) {
      Log.error('Image upload exception: $e',
          name: 'BlossomUploadService', category: LogCategory.video);
      return BlossomUploadResult(
        success: false,
        errorMessage: 'Image upload failed: $e',
      );
    }
  }
}