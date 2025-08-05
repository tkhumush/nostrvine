// ABOUTME: API handlers for trending and related video endpoints
// ABOUTME: Serves cached data from KV for <500ms response times

import { TrendingAnalyticsEngineService } from '../services/trending-analytics-engine';

/**
 * GET /api/trending/videos
 * Get trending videos with viral scores
 */
export async function handleTrendingVideos(
  request: Request,
  env: Env
): Promise<Response> {
  const url = new URL(request.url);
  const window = url.searchParams.get('window') || '24h';
  const limit = parseInt(url.searchParams.get('limit') || '50');
  
  // First try to get from cache
  const cacheKey = `trending:videos:${window}`;
  const cached = await env.ANALYTICS_KV.get(cacheKey);
  
  if (cached) {
    const data = JSON.parse(cached);
    // Return cached data with limit applied
    return new Response(JSON.stringify({
      videos: data.data.slice(0, limit),
      window,
      timestamp: data.timestamp,
      cached: true
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=60',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
  
  // Fallback to live query if no cache
  const service = new TrendingAnalyticsEngineService(env, {} as ExecutionContext);
  const videos = await service.getTrendingVideos(window as '1h' | '24h' | '7d', limit);
  
  return new Response(JSON.stringify({
    videos,
    window,
    timestamp: Date.now(),
    cached: false
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}

/**
 * GET /api/trending/hashtags
 * Get trending hashtags
 */
export async function handleTrendingHashtags(
  request: Request,
  env: Env
): Promise<Response> {
  const url = new URL(request.url);
  const window = url.searchParams.get('window') || '24h';
  const limit = parseInt(url.searchParams.get('limit') || '100');
  
  // First try to get from cache
  const cacheKey = `trending:hashtags:${window}`;
  const cached = await env.ANALYTICS_KV.get(cacheKey);
  
  if (cached) {
    const data = JSON.parse(cached);
    return new Response(JSON.stringify({
      hashtags: data.data.slice(0, limit),
      window,
      timestamp: data.timestamp,
      cached: true
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=60',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
  
  // Fallback to live query
  const service = new TrendingAnalyticsEngineService(env, {} as ExecutionContext);
  const hashtags = await service.getTrendingHashtags(window as '1h' | '24h' | '7d', limit);
  
  return new Response(JSON.stringify({
    hashtags,
    window,
    timestamp: Date.now(),
    cached: false
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}

/**
 * GET /api/trending/creators
 * Get top creators
 */
export async function handleTrendingCreators(
  request: Request,
  env: Env
): Promise<Response> {
  const url = new URL(request.url);
  const window = url.searchParams.get('window') || '7d';
  const limit = parseInt(url.searchParams.get('limit') || '50');
  
  // First try to get from cache
  const cacheKey = `trending:creators:${window}`;
  const cached = await env.ANALYTICS_KV.get(cacheKey);
  
  if (cached) {
    const data = JSON.parse(cached);
    return new Response(JSON.stringify({
      creators: data.data.slice(0, limit),
      window,
      timestamp: data.timestamp,
      cached: true
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=60',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
  
  // Fallback to live query
  const service = new TrendingAnalyticsEngineService(env, {} as ExecutionContext);
  const creators = await service.getTopCreators(window as '24h' | '7d' | '30d', limit);
  
  return new Response(JSON.stringify({
    creators,
    window,
    timestamp: Date.now(),
    cached: false
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}

/**
 * GET /api/videos/{videoId}/related
 * Get related videos based on shared hashtags
 */
export async function handleRelatedVideos(
  request: Request,
  env: Env,
  videoId: string
): Promise<Response> {
  const url = new URL(request.url);
  const limit = parseInt(url.searchParams.get('limit') || '20');
  const algorithm = url.searchParams.get('algorithm') || 'hashtags'; // hashtags or cowatch
  
  // Check cache first
  const cacheKey = `related:${algorithm}:${videoId}`;
  const cached = await env.ANALYTICS_KV.get(cacheKey);
  
  if (cached) {
    const data = JSON.parse(cached);
    return new Response(JSON.stringify({
      videos: data.videos.slice(0, limit),
      algorithm,
      videoId,
      timestamp: data.timestamp,
      cached: true
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300', // 5 minutes
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
  
  // Live query
  const service = new TrendingAnalyticsEngineService(env, {} as ExecutionContext);
  
  let videos;
  if (algorithm === 'cowatch') {
    videos = await service.getCoWatchedVideos(videoId, '24h', limit);
  } else {
    videos = await service.getRelatedVideos(videoId, limit);
  }
  
  // Cache for 5 minutes
  const cacheData = {
    videos,
    timestamp: Date.now()
  };
  await env.ANALYTICS_KV.put(cacheKey, JSON.stringify(cacheData), {
    expirationTtl: 300
  });
  
  return new Response(JSON.stringify({
    videos,
    algorithm,
    videoId,
    timestamp: Date.now(),
    cached: false
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}

/**
 * GET /api/trending/status
 * Get trending calculation status
 */
export async function handleTrendingStatus(
  request: Request,
  env: Env
): Promise<Response> {
  const lastUpdate = await env.ANALYTICS_KV.get('trending:last_update');
  
  if (!lastUpdate) {
    return new Response(JSON.stringify({
      status: 'no_data',
      message: 'No trending calculations have been performed yet'
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
  
  const data = JSON.parse(lastUpdate);
  const age = Date.now() - data.timestamp;
  
  return new Response(JSON.stringify({
    status: data.success ? 'healthy' : 'error',
    lastUpdate: data.timestamp,
    lastUpdateISO: new Date(data.timestamp).toISOString(),
    ageSeconds: Math.floor(age / 1000),
    nextUpdate: data.timestamp + 300000, // 5 minutes
    nextUpdateISO: new Date(data.timestamp + 300000).toISOString(),
    error: data.error
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}