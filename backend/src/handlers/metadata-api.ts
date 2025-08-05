// ABOUTME: API endpoints for retrieving file metadata including SHA-256 hashes
// ABOUTME: Supports both single file and batch requests for efficient metadata retrieval

export interface FileMetadataResponse {
  fileId: string;
  sha256?: string;
  size?: number;
  contentType?: string;
  uploadedAt?: string;
  originalName?: string;
  error?: string;
}

export interface BatchMetadataRequest {
  urls?: string[];
  fileIds?: string[];
}

export interface BatchMetadataResponse {
  [key: string]: Omit<FileMetadataResponse, 'fileId'>;
}

/**
 * Extract fileId from various URL formats:
 * - https://api.openvine.co/media/1751108612675-a475b5f8
 * - /media/1751108612675-a475b5f8
 * - 1751108612675-a475b5f8
 */
function extractFileId(input: string): string {
  // Remove protocol and domain if present
  const path = input.replace(/^https?:\/\/[^\/]+/, '');
  
  // Extract fileId from path
  const matches = path.match(/\/media\/([^\/\?]+)/);
  if (matches) {
    return matches[1];
  }
  
  // If no path match, assume input is already a fileId
  return input.replace(/^\/+/, '');
}

/**
 * Handle GET /api/metadata/{fileId} - Get metadata for a single file
 */
export async function handleGetFileMetadata(
  fileId: string,
  env: Env
): Promise<Response> {
  try {
    console.log(`📋 Getting metadata for fileId: ${fileId}`);

    if (!env.MEDIA_BUCKET) {
      return new Response(JSON.stringify({
        fileId,
        error: 'Media storage not configured'
      }), {
        status: 503,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    // Try with .mp4 extension first (most common)
    let objectKey = `uploads/${fileId}.mp4`;
    let headResult = await env.MEDIA_BUCKET.head(objectKey);
    
    // If not found, try without extension
    if (!headResult) {
      objectKey = `uploads/${fileId}`;
      headResult = await env.MEDIA_BUCKET.head(objectKey);
    }

    if (!headResult) {
      return new Response(JSON.stringify({
        fileId,
        error: 'File not found'
      }), {
        status: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    const response: FileMetadataResponse = {
      fileId,
      sha256: headResult.customMetadata?.sha256,
      size: headResult.size,
      contentType: headResult.httpMetadata?.contentType || 'application/octet-stream',
      uploadedAt: headResult.uploaded?.toISOString(),
      originalName: headResult.customMetadata?.originalName
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=3600' // 1 hour cache
      }
    });

  } catch (error) {
    console.error('Error getting file metadata:', error);
    
    return new Response(JSON.stringify({
      fileId,
      error: 'Internal server error'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
}

/**
 * Handle POST /api/metadata/batch - Get metadata for multiple files
 */
export async function handleBatchGetMetadata(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    console.log('📋 Batch metadata request received');

    if (!env.MEDIA_BUCKET) {
      return new Response(JSON.stringify({
        error: 'Media storage not configured'
      }), {
        status: 503,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    const body = await request.json() as BatchMetadataRequest;
    
    // Extract fileIds from URLs or use provided fileIds
    let fileIds: string[] = [];
    if (body.urls) {
      fileIds = body.urls.map(extractFileId);
    } else if (body.fileIds) {
      fileIds = body.fileIds;
    } else {
      return new Response(JSON.stringify({
        error: 'Either urls or fileIds array is required'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    // Limit batch size to prevent abuse
    if (fileIds.length > 100) {
      return new Response(JSON.stringify({
        error: 'Batch size limited to 100 files'
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    const results: BatchMetadataResponse = {};
    
    // Process files in parallel for efficiency
    const promises = fileIds.map(async (fileId) => {
      try {
        // Try with .mp4 extension first
        let objectKey = `uploads/${fileId}.mp4`;
        let headResult = await env.MEDIA_BUCKET.head(objectKey);
        
        // If not found, try without extension
        if (!headResult) {
          objectKey = `uploads/${fileId}`;
          headResult = await env.MEDIA_BUCKET.head(objectKey);
        }

        if (!headResult) {
          results[fileId] = {
            error: 'File not found'
          };
          return;
        }

        results[fileId] = {
          sha256: headResult.customMetadata?.sha256,
          size: headResult.size,
          contentType: headResult.httpMetadata?.contentType || 'application/octet-stream',
          uploadedAt: headResult.uploaded?.toISOString(),
          originalName: headResult.customMetadata?.originalName
        };
      } catch (error) {
        console.error(`Error processing fileId ${fileId}:`, error);
        results[fileId] = {
          error: 'Failed to retrieve metadata'
        };
      }
    });

    await Promise.all(promises);

    // If URLs were provided, map results back to URLs
    if (body.urls) {
      const urlResults: BatchMetadataResponse = {};
      body.urls.forEach((url, index) => {
        urlResults[url] = results[fileIds[index]];
      });
      
      console.log(`✅ Batch metadata complete: ${Object.keys(urlResults).length} files processed`);
      
      return new Response(JSON.stringify(urlResults), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'public, max-age=3600' // 1 hour cache
        }
      });
    }

    console.log(`✅ Batch metadata complete: ${Object.keys(results).length} files processed`);

    return new Response(JSON.stringify(results), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=3600' // 1 hour cache
      }
    });

  } catch (error) {
    console.error('Batch metadata error:', error);
    
    return new Response(JSON.stringify({
      error: 'Internal server error'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
}

/**
 * Handle OPTIONS requests for metadata endpoints
 */
export function handleMetadataOptions(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    }
  });
}