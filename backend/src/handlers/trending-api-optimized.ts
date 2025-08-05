// ABOUTME: Optimized trending API with edge caching for <50ms responses
// ABOUTME: Implements multi-layer caching strategy with edge, KV, and pre-computation

import { TrendingAnalyticsEngineService } from '../services/trending-analytics-engine';

/**
 * GET /api/trending/videos - Optimized with edge caching
 */
export async function handleTrendingVideos(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const url = new URL(request.url);
  const window = url.searchParams.get('window') || '24h';
  const limit = parseInt(url.searchParams.get('limit') || '50');
  
  // Build cache key
  const cacheKey = new Request(
    `https://cache.openvine.co/trending/videos/${window}/${limit}`,
    request
  );
  
  // Level 1: Check Cloudflare edge cache (<20ms)
  const cache = caches.default;
  let response = await cache.match(cacheKey);
  
  if (response) {
    // Clone and add cache hit header
    response = new Response(response.body, response);
    response.headers.set('X-Cache', 'HIT-EDGE');
    response.headers.set('X-Cache-Age', 
      String(Date.now() - parseInt(response.headers.get('X-Cache-Time') || '0'))
    );
    return response;
  }
  
  // Level 2: Check pre-computed KV data (<50ms)
  const preComputedKey = `pre:videos:${window}:${limit}`;
  const preComputed = await env.ANALYTICS_KV.get(preComputedKey);
  
  if (preComputed) {
    const data = JSON.parse(preComputed);
    response = new Response(JSON.stringify({
      videos: data,
      window,
      limit,
      timestamp: Date.now(),
      cached: true,
      cacheLayer: 'kv-precomputed'
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300, s-maxage=300, stale-while-revalidate=600',
        'CDN-Cache-Control': 'max-age=300',
        'X-Cache': 'HIT-KV',
        'X-Cache-Time': String(Date.now()),
        'Access-Control-Allow-Origin': '*'
      }
    });
    
    // Store in edge cache
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  }
  
  // Level 3: Regular KV cache
  const kvKey = `trending:videos:${window}`;
  const kvCached = await env.ANALYTICS_KV.get(kvKey);
  
  if (kvCached) {
    const data = JSON.parse(kvCached);
    response = new Response(JSON.stringify({
      videos: data.data.slice(0, limit),
      window,
      timestamp: data.timestamp,
      cached: true,
      cacheLayer: 'kv'
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=60, s-maxage=300, stale-while-revalidate=600',
        'CDN-Cache-Control': 'max-age=300',
        'X-Cache': 'HIT-KV-REGULAR',
        'X-Cache-Time': String(Date.now()),
        'Access-Control-Allow-Origin': '*'
      }
    });
    
    // Store in edge cache
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  }
  
  // Level 4: Compute fresh data (200-500ms)
  const service = new TrendingAnalyticsEngineService(env, ctx);
  const videos = await service.getTrendingVideos(window as '1h' | '24h' | '7d', limit);
  
  // Store in KV for next request
  ctx.waitUntil(
    env.ANALYTICS_KV.put(
      preComputedKey,
      JSON.stringify(videos),
      { expirationTtl: 30 } // 30 seconds for pre-computed
    )
  );
  
  response = new Response(JSON.stringify({
    videos,
    window,
    limit,
    timestamp: Date.now(),
    cached: false,
    cacheLayer: 'computed'
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=30, s-maxage=300, stale-while-revalidate=600',
      'CDN-Cache-Control': 'max-age=300',
      'X-Cache': 'MISS',
      'X-Cache-Time': String(Date.now()),
      'Access-Control-Allow-Origin': '*'
    }
  });
  
  // Store in edge cache
  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}

/**
 * GET /api/trending/hashtags - Optimized with edge caching
 */
export async function handleTrendingHashtags(
  request: Request,
  env: Env,
  ctx: ExecutionContext
): Promise<Response> {
  const url = new URL(request.url);
  const window = url.searchParams.get('window') || '24h';
  const limit = parseInt(url.searchParams.get('limit') || '100');
  
  const cacheKey = new Request(
    `https://cache.openvine.co/trending/hashtags/${window}/${limit}`,
    request
  );
  
  // Check edge cache first
  const cache = caches.default;
  let response = await cache.match(cacheKey);
  
  if (response) {
    response = new Response(response.body, response);
    response.headers.set('X-Cache', 'HIT-EDGE');
    return response;
  }
  
  // Check pre-computed KV
  const preComputedKey = `pre:hashtags:${window}:${limit}`;
  const preComputed = await env.ANALYTICS_KV.get(preComputedKey);
  
  if (preComputed) {
    response = new Response(JSON.stringify({
      hashtags: JSON.parse(preComputed),
      window,
      limit,
      timestamp: Date.now(),
      cached: true,
      cacheLayer: 'kv-precomputed'
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=300, s-maxage=300, stale-while-revalidate=600',
        'X-Cache': 'HIT-KV',
        'X-Cache-Time': String(Date.now()),
        'Access-Control-Allow-Origin': '*'
      }
    });
    
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  }
  
  // Compute fresh
  const service = new TrendingAnalyticsEngineService(env, ctx);
  const hashtags = await service.getTrendingHashtags(window as '1h' | '24h' | '7d', limit);
  
  // Cache in KV
  ctx.waitUntil(
    env.ANALYTICS_KV.put(preComputedKey, JSON.stringify(hashtags), { expirationTtl: 30 })
  );
  
  response = new Response(JSON.stringify({
    hashtags,
    window,
    limit,
    timestamp: Date.now(),
    cached: false,
    cacheLayer: 'computed'
  }), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=30, s-maxage=300, stale-while-revalidate=600',
      'X-Cache': 'MISS',
      'X-Cache-Time': String(Date.now()),
      'Access-Control-Allow-Origin': '*'
    }
  });
  
  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}

/**
 * Scheduled job to pre-compute trending data
 */
export async function preComputeTrending(env: Env, ctx: ExecutionContext) {
  const service = new TrendingAnalyticsEngineService(env, ctx);
  
  // Define all combinations to pre-compute
  const configs = [
    { type: 'videos', window: '1h', limits: [10, 20, 50] },
    { type: 'videos', window: '24h', limits: [10, 20, 50, 100] },
    { type: 'videos', window: '7d', limits: [10, 20, 50, 100] },
    { type: 'hashtags', window: '24h', limits: [20, 50, 100] },
    { type: 'hashtags', window: '7d', limits: [20, 50, 100] }
  ];
  
  const promises = [];
  
  for (const config of configs) {
    for (const limit of config.limits) {
      const promise = (async () => {
        try {
          let data;
          if (config.type === 'videos') {
            data = await service.getTrendingVideos(config.window as '1h' | '24h' | '7d', limit);
          } else {
            data = await service.getTrendingHashtags(config.window as '1h' | '24h' | '7d', limit);
          }
          
          // Store in KV with very short TTL (will be replaced soon)
          await env.ANALYTICS_KV.put(
            `pre:${config.type}:${config.window}:${limit}`,
            JSON.stringify(data),
            { expirationTtl: 35 } // 35 seconds (runs every 30)
          );
          
          // Also warm the edge cache
          const fakeRequest = new Request(
            `https://cache.openvine.co/trending/${config.type}/${config.window}/${limit}`
          );
          const response = new Response(JSON.stringify(data), {
            headers: {
              'Content-Type': 'application/json',
              'Cache-Control': 'public, max-age=30, s-maxage=30'
            }
          });
          await caches.default.put(fakeRequest, response);
          
        } catch (error) {
          console.error(`Failed to pre-compute ${config.type}/${config.window}/${limit}:`, error);
        }
      })();
      
      promises.push(promise);
    }
  }
  
  // Run all pre-computations in parallel
  await Promise.allSettled(promises);
  
  // Log success
  await env.ANALYTICS_KV.put('precompute:last_run', JSON.stringify({
    timestamp: Date.now(),
    success: true,
    configs: configs.length,
    totalCombinations: promises.length
  }), { expirationTtl: 60 });
}

/**
 * GET /api/videos/{videoId}/related - Optimized related videos
 */
export async function handleRelatedVideos(
  request: Request,
  env: Env,
  ctx: ExecutionContext,
  videoId: string
): Promise<Response> {
  const url = new URL(request.url);
  const limit = parseInt(url.searchParams.get('limit') || '20');
  const algorithm = url.searchParams.get('algorithm') || 'hashtags';
  
  // Use shorter cache for related videos (they're more dynamic)
  const cacheKey = new Request(
    `https://cache.openvine.co/related/${algorithm}/${videoId}/${limit}`,
    request
  );
  
  const cache = caches.default;
  let response = await cache.match(cacheKey);
  
  if (response) {
    response = new Response(response.body, response);
    response.headers.set('X-Cache', 'HIT-EDGE');
    return response;
  }
  
  // Check KV
  const kvKey = `related:${algorithm}:${videoId}:${limit}`;
  const cached = await env.ANALYTICS_KV.get(kvKey);
  
  if (cached) {
    response = new Response(cached, {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=60, s-maxage=120',
        'X-Cache': 'HIT-KV',
        'Access-Control-Allow-Origin': '*'
      }
    });
    
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  }
  
  // Compute fresh
  const service = new TrendingAnalyticsEngineService(env, ctx);
  let videos;
  
  if (algorithm === 'cowatch') {
    videos = await service.getCoWatchedVideos(videoId, '24h', limit);
  } else {
    videos = await service.getRelatedVideos(videoId, limit);
  }
  
  const responseData = JSON.stringify({
    videos,
    algorithm,
    videoId,
    timestamp: Date.now(),
    cached: false
  });
  
  // Cache in KV
  ctx.waitUntil(
    env.ANALYTICS_KV.put(kvKey, responseData, { expirationTtl: 120 })
  );
  
  response = new Response(responseData, {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=60, s-maxage=120',
      'X-Cache': 'MISS',
      'Access-Control-Allow-Origin': '*'
    }
  });
  
  ctx.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
}