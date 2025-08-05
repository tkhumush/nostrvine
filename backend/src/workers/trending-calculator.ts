// ABOUTME: Scheduled worker that calculates trending videos every 5 minutes
// ABOUTME: Uses Analytics Engine SQL queries with viral score algorithm

import { TrendingAnalyticsEngineService } from '../services/trending-analytics-engine';

export interface TrendingWorkerEnv extends Env {
  ANALYTICS_KV: KVNamespace;
  CLOUDFLARE_ACCOUNT_ID: string;
  CLOUDFLARE_API_TOKEN: string;
}

/**
 * Scheduled worker that runs every 5 minutes to calculate trending
 */
export async function scheduledTrendingCalculator(
  event: ScheduledEvent,
  env: TrendingWorkerEnv,
  ctx: ExecutionContext
): Promise<void> {
  console.log('🔄 Starting trending calculation at', new Date().toISOString());
  
  const service = new TrendingAnalyticsEngineService(env, ctx);
  
  try {
    // Calculate trending videos for all time windows
    const [trending1h, trending24h, trending7d] = await Promise.all([
      service.getTrendingVideos('1h', 50),
      service.getTrendingVideos('24h', 100),
      service.getTrendingVideos('7d', 200)
    ]);

    console.log(`📊 Trending results: 1h=${trending1h.length}, 24h=${trending24h.length}, 7d=${trending7d.length}`);

    // Calculate trending hashtags
    const [hashtags1h, hashtags24h, hashtags7d] = await Promise.all([
      service.getTrendingHashtags('1h', 50),
      service.getTrendingHashtags('24h', 100),
      service.getTrendingHashtags('7d', 100)
    ]);

    console.log(`#️⃣ Hashtag results: 1h=${hashtags1h.length}, 24h=${hashtags24h.length}, 7d=${hashtags7d.length}`);

    // Calculate top creators
    const [creators24h, creators7d, creators30d] = await Promise.all([
      service.getTopCreators('24h', 20),
      service.getTopCreators('7d', 50),
      service.getTopCreators('30d', 100)
    ]);

    console.log(`👤 Creator results: 24h=${creators24h.length}, 7d=${creators7d.length}, 30d=${creators30d.length}`);

    // Cache all results in KV with 5-minute TTL
    const ttl = 300; // 5 minutes
    const timestamp = Date.now();
    
    await Promise.all([
      // Trending videos
      env.ANALYTICS_KV.put(
        'trending:videos:1h',
        JSON.stringify({ data: trending1h, timestamp, window: '1h' }),
        { expirationTtl: ttl }
      ),
      env.ANALYTICS_KV.put(
        'trending:videos:24h',
        JSON.stringify({ data: trending24h, timestamp, window: '24h' }),
        { expirationTtl: ttl }
      ),
      env.ANALYTICS_KV.put(
        'trending:videos:7d',
        JSON.stringify({ data: trending7d, timestamp, window: '7d' }),
        { expirationTtl: ttl }
      ),
      
      // Trending hashtags
      env.ANALYTICS_KV.put(
        'trending:hashtags:1h',
        JSON.stringify({ data: hashtags1h, timestamp, window: '1h' }),
        { expirationTtl: ttl }
      ),
      env.ANALYTICS_KV.put(
        'trending:hashtags:24h',
        JSON.stringify({ data: hashtags24h, timestamp, window: '24h' }),
        { expirationTtl: ttl }
      ),
      env.ANALYTICS_KV.put(
        'trending:hashtags:7d',
        JSON.stringify({ data: hashtags7d, timestamp, window: '7d' }),
        { expirationTtl: ttl }
      ),
      
      // Top creators
      env.ANALYTICS_KV.put(
        'trending:creators:24h',
        JSON.stringify({ data: creators24h, timestamp, window: '24h' }),
        { expirationTtl: ttl }
      ),
      env.ANALYTICS_KV.put(
        'trending:creators:7d',
        JSON.stringify({ data: creators7d, timestamp, window: '7d' }),
        { expirationTtl: ttl }
      ),
      env.ANALYTICS_KV.put(
        'trending:creators:30d',
        JSON.stringify({ data: creators30d, timestamp, window: '30d' }),
        { expirationTtl: ttl }
      ),
      
      // Update timestamp
      env.ANALYTICS_KV.put(
        'trending:last_update',
        JSON.stringify({ timestamp, success: true }),
        { expirationTtl: ttl }
      )
    ]);

    console.log('✅ Trending calculation completed successfully');
  } catch (error) {
    console.error('❌ Trending calculation failed:', error);
    
    // Store error state
    await env.ANALYTICS_KV.put(
      'trending:last_update',
      JSON.stringify({ 
        timestamp: Date.now(), 
        success: false, 
        error: error.message 
      }),
      { expirationTtl: 300 }
    );
    
    throw error;
  }
}

/**
 * HTTP handler to manually trigger trending calculation
 */
export async function handleTrendingRefresh(
  request: Request,
  env: TrendingWorkerEnv,
  ctx: ExecutionContext
): Promise<Response> {
  // Verify auth token if provided
  const authHeader = request.headers.get('Authorization');
  if (env.TRENDING_AUTH_TOKEN && authHeader !== `Bearer ${env.TRENDING_AUTH_TOKEN}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  // Run the calculation
  try {
    await scheduledTrendingCalculator(
      { scheduledTime: Date.now(), cron: '*/5 * * * *' } as ScheduledEvent,
      env,
      ctx
    );
    
    return new Response(JSON.stringify({ 
      success: true, 
      timestamp: new Date().toISOString() 
    }), {
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    return new Response(JSON.stringify({ 
      success: false, 
      error: error.message 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

/**
 * Get cached trending data endpoint
 */
export async function handleGetTrending(
  request: Request,
  env: TrendingWorkerEnv
): Promise<Response> {
  const url = new URL(request.url);
  const type = url.searchParams.get('type') || 'videos'; // videos, hashtags, creators
  const window = url.searchParams.get('window') || '24h';
  
  try {
    const cacheKey = `trending:${type}:${window}`;
    const cached = await env.ANALYTICS_KV.get(cacheKey);
    
    if (!cached) {
      return new Response(JSON.stringify({ 
        error: 'No trending data available. Please wait for next calculation.' 
      }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      });
    }
    
    const data = JSON.parse(cached);
    
    return new Response(JSON.stringify(data), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=60', // Cache for 1 minute
        'X-Last-Updated': new Date(data.timestamp).toISOString()
      }
    });
  } catch (error) {
    return new Response(JSON.stringify({ 
      error: 'Failed to fetch trending data' 
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}