# OpenVine Caching Strategy for <50ms Response Times

## Current Performance Issues
- Direct Analytics Engine queries take 200-500ms
- No edge caching in place
- KV storage adds 50-100ms latency

## Multi-Layer Caching Architecture

### 1. Cloudflare Edge Cache (Target: <20ms)
```typescript
// Use Cloudflare's built-in edge cache
const cache = caches.default;

// Cache trending data at edge locations
const cacheKey = new Request(`https://cache.openvine.co/trending/${window}`, {
  cf: {
    cacheTtl: 300, // 5 minutes
    cacheEverything: true
  }
});

// Check edge cache first
const cached = await cache.match(cacheKey);
if (cached) return cached; // <20ms response
```

### 2. Workers KV with Geographically Distributed Reads (<50ms)
```typescript
// Pre-compute and store in KV
await env.TRENDING_KV.put(
  `trending:${window}`,
  data,
  { 
    expirationTtl: 300,
    metadata: { timestamp: Date.now() }
  }
);
```

### 3. Durable Objects for Real-time Aggregation (<30ms)
```typescript
// Use Durable Objects for live aggregation
export class TrendingAggregator {
  private cache = new Map<string, CachedResult>();
  
  async getTrending(window: string) {
    // Return pre-aggregated data instantly
    return this.cache.get(window);
  }
  
  // Background updates every 30 seconds
  async updateCache() {
    // Aggregate from Analytics Engine
    // Store in memory cache
  }
}
```

### 4. Pre-computation Strategy

#### Scheduled Worker (runs every 30 seconds)
```typescript
export default {
  async scheduled(event: ScheduledEvent, env: Env) {
    // Pre-compute all trending windows
    const windows = ['1h', '24h', '7d'];
    const limits = [10, 20, 50, 100];
    
    for (const window of windows) {
      for (const limit of limits) {
        const data = await computeTrending(window, limit);
        
        // Store in multiple cache layers
        await Promise.all([
          // Edge cache
          cacheAtEdge(window, limit, data),
          // KV storage
          env.TRENDING_KV.put(`${window}:${limit}`, data),
          // Durable Object
          durableObject.store(window, limit, data)
        ]);
      }
    }
  }
}
```

### 5. Smart Cache Warming

#### Predictive Pre-fetching
```typescript
// Track access patterns
const accessLog = new Map<string, number>();

// Pre-warm frequently accessed combinations
async function warmCache() {
  const popular = getTopAccessPatterns(accessLog);
  
  for (const pattern of popular) {
    await preComputeAndCache(pattern);
  }
}
```

### 6. Response Strategy

```typescript
async function getTrendingVideos(window: string, limit: number) {
  // Level 1: Browser cache (0ms)
  // Set cache headers for client-side caching
  
  // Level 2: Edge cache (<20ms)
  const edgeCached = await checkEdgeCache(window, limit);
  if (edgeCached) return edgeCached;
  
  // Level 3: Durable Object (<30ms)
  const durableData = await durableObject.get(window, limit);
  if (durableData) return durableData;
  
  // Level 4: KV storage (<50ms)
  const kvData = await env.TRENDING_KV.get(`${window}:${limit}`);
  if (kvData) return kvData;
  
  // Level 5: Compute and cache (200-500ms)
  const fresh = await computeFromAnalyticsEngine(window, limit);
  await cacheAllLayers(fresh);
  return fresh;
}
```

## Implementation Steps

### Phase 1: Edge Caching (Immediate)
```typescript
// Add to trending-api.ts
export async function handleTrendingVideos(request: Request, env: Env) {
  const cache = caches.default;
  const cacheKey = new Request(request.url);
  
  // Check edge cache
  const cached = await cache.match(cacheKey);
  if (cached) {
    return cached;
  }
  
  // Get data (from KV or compute)
  const response = new Response(data, {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, max-age=300, s-maxage=300',
      'CDN-Cache-Control': 'max-age=300',
      'Cloudflare-CDN-Cache-Control': 'max-age=300'
    }
  });
  
  // Store in edge cache
  await cache.put(cacheKey, response.clone());
  return response;
}
```

### Phase 2: Scheduled Pre-computation
```typescript
// wrangler.toml
[triggers]
crons = ["*/30 * * * *"] # Every 30 seconds

// scheduled.ts
export async function scheduled(event: ScheduledEvent, env: Env) {
  const service = new TrendingAnalyticsEngineService(env);
  
  // Pre-compute all combinations
  const configs = [
    { window: '1h', limits: [10, 20, 50] },
    { window: '24h', limits: [10, 20, 50, 100] },
    { window: '7d', limits: [10, 20, 50, 100] }
  ];
  
  for (const config of configs) {
    for (const limit of config.limits) {
      const data = await service.getTrendingVideos(config.window, limit);
      await env.TRENDING_KV.put(
        `pre:${config.window}:${limit}`,
        JSON.stringify(data),
        { expirationTtl: 60 }
      );
    }
  }
}
```

### Phase 3: Durable Objects for Live Data
```typescript
export class TrendingState extends DurableObject {
  private trending = new Map<string, any>();
  
  async fetch(request: Request) {
    const url = new URL(request.url);
    const key = url.pathname;
    
    // Return cached data instantly
    const cached = this.trending.get(key);
    if (cached && Date.now() - cached.timestamp < 30000) {
      return new Response(JSON.stringify(cached.data));
    }
    
    // Update in background
    this.updateTrending(key);
    return new Response(JSON.stringify(cached?.data || {}));
  }
  
  async updateTrending(key: string) {
    // Compute new trending data
    // Store in memory
    this.trending.set(key, {
      data: computedData,
      timestamp: Date.now()
    });
  }
}
```

## Performance Targets

| Cache Layer | Response Time | Hit Rate | TTL |
|------------|---------------|----------|-----|
| Browser | 0ms | 20% | 60s |
| Edge Cache | <20ms | 60% | 300s |
| Durable Object | <30ms | 15% | 30s |
| KV Storage | <50ms | 4% | 300s |
| Compute | 200-500ms | 1% | - |

## Cache Invalidation Strategy

### Event-driven Invalidation
```typescript
// When new video is uploaded or gets significant views
async function invalidateTrendingCache(videoId: string) {
  // Clear specific cache entries
  await Promise.all([
    cache.delete(new Request('https://cache.openvine.co/trending/1h')),
    env.TRENDING_KV.delete('trending:1h'),
    durableObject.invalidate('1h')
  ]);
}
```

### Time-based Expiration
- Edge cache: 5 minutes
- KV storage: 5 minutes  
- Durable Objects: 30 seconds
- Pre-computed data: 30 seconds

## Monitoring

```typescript
// Track cache performance
const metrics = {
  edge_hits: 0,
  edge_misses: 0,
  kv_hits: 0,
  kv_misses: 0,
  compute_time: [],
  response_times: []
};

// Log to Analytics Engine
await logMetrics(metrics);
```

## Expected Results

### Before Optimization
- P50: 350ms
- P95: 500ms
- P99: 800ms

### After Full Implementation
- P50: 25ms (edge cache hits)
- P95: 50ms (KV hits)
- P99: 300ms (cache misses)

## Quick Wins (Implement Today)

1. **Add Edge Cache Headers**
```typescript
headers: {
  'Cache-Control': 'public, max-age=300, s-maxage=300',
  'CDN-Cache-Control': 'max-age=300'
}
```

2. **Pre-compute Top Queries**
```typescript
// Run every 30 seconds
const precompute = ['trending/24h?limit=50', 'trending/7d?limit=20'];
```

3. **Use Stale-While-Revalidate**
```typescript
'Cache-Control': 'public, max-age=60, stale-while-revalidate=240'
```

This allows serving stale content while fetching fresh data in background.