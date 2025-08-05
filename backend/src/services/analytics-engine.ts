// ABOUTME: Modern analytics service using Cloudflare Analytics Engine
// ABOUTME: Replaces KV-based analytics with proper time-series data storage

// import { AnalyticsFallbackService } from './analytics-fallback'; // Disabled - using Analytics Engine only

export interface VideoViewEvent {
  videoId: string;
  userId?: string;
  creatorPubkey?: string;
  source: string;
  eventType: string;
  country?: string;
  hashtags?: string[];
  title?: string;
  watchDuration?: number;
  totalDuration?: number;
  loopCount?: number;
  completionRate?: number;
}

export interface VideoMetrics {
  videoId: string;
  views: number;
  uniqueViewers: number;
  avgWatchTime: number;
  avgCompletionRate: number;
  totalLoops: number;
}

export interface SocialInteractionEvent {
  videoId: string;
  userId?: string;
  interactionType: 'like' | 'repost' | 'comment';
  nostrEventId: string;
  nostrEventKind: number; // 7 for reactions, 6 for reposts, 1 for comments
  content?: string; // reaction content ("+", "-") or comment text
  timestamp: number;
  creatorPubkey?: string;
}

export interface VideoSocialMetrics {
  videoId: string;
  likes: number;
  reposts: number;
  comments: number;
  engagementRate: number;
  lastUpdated: string;
}

export class VideoAnalyticsEngineService {
  // private fallbackService: AnalyticsFallbackService; // Disabled - using Analytics Engine only

  constructor(
    private env: Env,
    private ctx: ExecutionContext
  ) {
    // this.fallbackService = new AnalyticsFallbackService(env, ctx); // Disabled
  }

  /**
   * Track a video view event using Analytics Engine
   */
  async trackVideoView(event: VideoViewEvent, request: Request): Promise<void> {
    // Extract metadata from request
    const country = (request as any).cf?.country || 'unknown';
    const userAgent = request.headers.get('User-Agent') || 'unknown';
    const timestamp = new Date().toISOString();
    const date = timestamp.split('T')[0];
    const hour = new Date().getHours();

    // Prepare hashtags as a single string for blob storage
    const hashtagsStr = event.hashtags?.join(',') || '';

    // Write data point to Analytics Engine
    // Note: We don't await this to avoid blocking the response
    this.ctx.waitUntil(
      this.writeAnalyticsDataPoint({
        blobs: [
          event.videoId,                    // blob1: video ID
          event.userId || 'anonymous',      // blob2: user ID
          country,                           // blob3: country
          event.source,                      // blob4: source (mobile/web)
          event.eventType,                   // blob5: event type
          date,                              // blob6: date (YYYY-MM-DD)
          event.creatorPubkey || 'unknown',  // blob7: creator pubkey
          hashtagsStr,                       // blob8: hashtags (comma-separated)
          event.title || '',                 // blob9: video title
          hour.toString()                    // blob10: hour of day
        ],
        doubles: [
          1,                                          // double1: view count
          event.watchDuration || 0,                   // double2: watch duration (ms)
          event.loopCount || 0,                       // double3: loop count
          event.completionRate || 0,                  // double4: completion rate (0-1)
          event.totalDuration || 0,                   // double5: total video duration (ms)
          event.eventType === 'view_start' ? 1 : 0,  // double6: is new view
          event.eventType === 'view_end' ? 1 : 0,    // double7: is completed view
          Date.now()                                  // double8: timestamp (for time-based queries)
        ],
        indexes: [event.videoId] // Use video ID for sampling
      })
    );

    // Disabled KV fallback - using Analytics Engine only
    // console.log('📊 KV fallback disabled - using Analytics Engine only');

    // Log for debugging
    console.log(`📊 Analytics Engine: Tracked ${event.eventType} for video ${event.videoId.substring(0, 8)}...`);
  }

  /**
   * Track a social interaction event (likes, reposts, comments)
   */
  async trackSocialInteraction(event: SocialInteractionEvent, request: Request): Promise<void> {
    // Extract metadata from request
    const country = (request as any).cf?.country || 'unknown';
    const timestamp = new Date().toISOString();
    const date = timestamp.split('T')[0];
    const hour = new Date().getHours();

    // Map interaction types to numeric values for analytics
    const interactionTypeMap = {
      'like': 1,
      'repost': 2, 
      'comment': 3
    };

    // Write data point to Analytics Engine for social interactions
    this.ctx.waitUntil(
      this.writeSocialAnalyticsDataPoint({
        blobs: [
          event.videoId,                               // blob1: video ID
          event.userId || 'anonymous',                 // blob2: user ID
          event.interactionType,                       // blob3: interaction type
          event.nostrEventId,                          // blob4: nostr event ID
          country,                                     // blob5: country
          date,                                        // blob6: date (YYYY-MM-DD)
          event.creatorPubkey || 'unknown',            // blob7: creator pubkey
          event.content?.substring(0, 100) || '',      // blob8: content preview (truncated)
          hour.toString(),                             // blob9: hour of day
          event.nostrEventKind.toString()              // blob10: nostr event kind
        ],
        doubles: [
          1,                                           // double1: interaction count
          interactionTypeMap[event.interactionType],   // double2: interaction type numeric
          event.nostrEventKind,                        // double3: nostr event kind
          event.timestamp,                             // double4: timestamp
          event.content?.length || 0,                  // double5: content length
          Date.now()                                   // double6: ingestion timestamp
        ],
        indexes: [event.videoId, event.nostrEventId] // Index by video ID and event ID
      })
    );

    // Disabled KV cache - using Analytics Engine only
    // this.ctx.waitUntil(
    //   this.updateSocialMetricsCache(event.videoId, event.interactionType, 1)
    // );

    console.log(`🔄 Analytics Engine: Tracked ${event.interactionType} for video ${event.videoId.substring(0, 8)}...`);
  }

  /**
   * Write data point to Analytics Engine
   */
  private async writeAnalyticsDataPoint(data: {
    blobs: string[];
    doubles: number[];
    indexes: string[];
  }): Promise<void> {
    try {
      // Write to Analytics Engine dataset
      this.env.VIDEO_ANALYTICS.writeDataPoint(data);
    } catch (error) {
      console.error('Failed to write to Analytics Engine:', error);
    }
  }

  /**
   * Write social interaction data point to Analytics Engine
   */
  private async writeSocialAnalyticsDataPoint(data: {
    blobs: string[];
    doubles: number[];
    indexes: string[];
  }): Promise<void> {
    try {
      // Write to Analytics Engine dataset (same dataset, different data structure)
      this.env.VIDEO_ANALYTICS.writeDataPoint(data);
    } catch (error) {
      console.error('Failed to write social analytics to Analytics Engine:', error);
    }
  }

  /**
   * Update social metrics cache in KV storage
   */
  private async updateSocialMetricsCache(
    videoId: string, 
    interactionType: 'like' | 'repost' | 'comment', 
    delta: number
  ): Promise<void> {
    try {
      const cacheKey = `social_metrics:${videoId}`;
      
      // Get current metrics
      const cached = await this.env.ANALYTICS_KV.get(cacheKey);
      let metrics: VideoSocialMetrics;
      
      if (cached) {
        metrics = JSON.parse(cached);
      } else {
        metrics = {
          videoId,
          likes: 0,
          reposts: 0,
          comments: 0,
          engagementRate: 0,
          lastUpdated: new Date().toISOString()
        };
      }

      // Update the specific metric
      switch (interactionType) {
        case 'like':
          metrics.likes += delta;
          break;
        case 'repost':
          metrics.reposts += delta;
          break;
        case 'comment':
          metrics.comments += delta;
          break;
      }

      // Calculate engagement rate (total interactions / (views or 1 to avoid division by zero))
      const totalInteractions = metrics.likes + metrics.reposts + metrics.comments;
      // We'll need to get view count from analytics, for now use simple calculation
      metrics.engagementRate = totalInteractions > 0 ? Math.min(totalInteractions / Math.max(totalInteractions, 100), 1) : 0;
      metrics.lastUpdated = new Date().toISOString();

      // Cache for 1 hour
      await this.env.ANALYTICS_KV.put(cacheKey, JSON.stringify(metrics), {
        expirationTtl: 3600
      });
    } catch (error) {
      console.error('Failed to update social metrics cache:', error);
    }
  }

  /**
   * Get popular videos using SQL query
   */
  async getPopularVideos(
    timeframe: '1h' | '24h' | '7d' = '24h',
    limit: number = 10
  ): Promise<VideoMetrics[]> {
    try {
      // First try a simple count query to test if there's any data  
      const testQuery = `SELECT COUNT() as total FROM nostrvine_video_views`;
      
      console.log('Testing Analytics Engine with simple count query...');
      const testResults = await this.executeAnalyticsQuery(testQuery);
      console.log('Test query results:', testResults);

      // Use correct Analytics Engine table name (binding name) with ClickHouse SQL syntax
      const query = `
        SELECT 
          blob1 AS videoId,
          SUM(double1) AS views,
          COUNT(DISTINCT blob2) AS uniqueViewers,
          AVG(double2) AS avgWatchTime,
          AVG(double4) AS avgCompletionRate,
          SUM(double3) AS totalLoops
        FROM nostrvine_video_views
        GROUP BY blob1
        ORDER BY views DESC
        LIMIT ${limit}
      `;

      // Execute SQL query against Analytics Engine
      const results = await this.executeAnalyticsQuery(query);
      if (results && results.length > 0) {
        return results as VideoMetrics[];
      }
      
      // No fallback - return empty if Analytics Engine fails
      console.log('Analytics Engine returned no results');
      return [];
    } catch (error) {
      console.error('Analytics Engine query failed:', error);
      // No fallback - throw the error or return empty
      return [];
    }
  }

  /**
   * Get detailed analytics for a specific video
   */
  async getVideoAnalytics(videoId: string, days: number = 30): Promise<any> {
    const query = `
      SELECT 
        toDate(timestamp) AS date,
        SUM(double1) AS dailyViews,
        COUNT(DISTINCT blob2) AS uniqueViewers,
        AVG(double2) AS avgWatchTime,
        AVG(double4) AS avgCompletionRate,
        SUM(double3) AS totalLoops,
        SUM(double6) AS newViews,
        SUM(double7) AS completedViews
      FROM nostrvine_video_views
      WHERE blob1 = '${videoId}'
        AND timestamp >= NOW() - INTERVAL '${days}' DAY
      GROUP BY date
      ORDER BY date DESC
    `;

    try {
      const results = await this.executeAnalyticsQuery(query);
      return {
        videoId,
        dailyMetrics: results,
        period: `${days} days`
      };
    } catch (error) {
      console.error('Failed to get video analytics:', error);
      return null;
    }
  }

  /**
   * Get real-time metrics
   */
  async getRealtimeMetrics(): Promise<any> {
    try {
      // Use Analytics Engine only
      const query = `
        SELECT 
          COUNT(*) AS totalEvents,
          COUNT(DISTINCT blob1) AS activeVideos,
          COUNT(DISTINCT blob2) AS activeUsers,
          AVG(double2) AS avgWatchTime,
          SUM(double6) AS newViews
        FROM nostrvine_video_views
      `;
      
      const results = await this.executeAnalyticsQuery(query);
      if (results && results.length > 0) {
        return results[0];
      }
      
      // No fallback - return zeros if no data
      return {
        totalEvents: 0,
        activeVideos: 0,
        activeUsers: 0,
        avgWatchTime: 0,
        newViews: 0
      };
    } catch (error) {
      console.error('Analytics Engine query failed:', error);
      // Return default values on error
      return {
        totalEvents: 0,
        activeVideos: 0,
        activeUsers: 0,
        avgWatchTime: 0,
        newViews: 0
      };
    }
  }

  /**
   * Get analytics by hashtag
   */
  async getHashtagAnalytics(hashtag: string, days: number = 7): Promise<any> {
    const query = `
      SELECT 
        blob1 AS videoId,
        blob9 AS title,
        SUM(double1) AS views,
        AVG(double2) AS avgWatchTime,
        AVG(double4) AS avgCompletionRate
      FROM VIDEO_ANALYTICS
      WHERE blob8 LIKE '%${hashtag}%'
        AND timestamp >= NOW() - INTERVAL '${days}' DAY
      GROUP BY videoId, title
      ORDER BY views DESC
      LIMIT 20
    `;

    try {
      const results = await this.executeAnalyticsQuery(query);
      return {
        hashtag,
        videos: results,
        period: `${days} days`
      };
    } catch (error) {
      console.error('Failed to get hashtag analytics:', error);
      return null;
    }
  }

  /**
   * Get creator analytics
   */
  async getCreatorAnalytics(creatorPubkey: string, days: number = 30): Promise<any> {
    const query = `
      SELECT 
        blob1 AS videoId,
        blob9 AS title,
        SUM(double1) AS totalViews,
        COUNT(DISTINCT blob2) AS uniqueViewers,
        AVG(double2) AS avgWatchTime,
        AVG(double4) AS avgCompletionRate,
        SUM(double3) AS totalLoops
      FROM VIDEO_ANALYTICS
      WHERE blob7 = '${creatorPubkey}'
        AND timestamp >= NOW() - INTERVAL '${days}' DAY
      GROUP BY videoId, title
      ORDER BY totalViews DESC
    `;

    try {
      const results = await this.executeAnalyticsQuery(query);
      return {
        creatorPubkey,
        videos: results,
        totalVideos: results.length,
        period: `${days} days`
      };
    } catch (error) {
      console.error('Failed to get creator analytics:', error);
      return null;
    }
  }

  /**
   * Execute SQL query against Analytics Engine using Cloudflare's SQL API
   */
  private async executeAnalyticsQuery(query: string): Promise<any[]> {
    try {
      console.log('Executing Analytics Engine query:', query);
      
      // Check if we have the required API credentials
      const accountId = this.env.CLOUDFLARE_ACCOUNT_ID;
      const apiToken = this.env.CLOUDFLARE_API_TOKEN;
      
      if (!accountId || !apiToken) {
        console.log('❌ Analytics Engine API credentials not configured');
        console.log('CLOUDFLARE_ACCOUNT_ID present:', !!accountId);
        console.log('CLOUDFLARE_API_TOKEN present:', !!apiToken);
        console.log('Data is being written successfully, but queries need API setup');
        return [];
      }
      
      
      console.log('✅ Analytics Engine credentials configured, attempting query...');
      
      // Use Cloudflare's Analytics Engine SQL API with timeout
      console.log(`🔍 Making Analytics Engine API request to: accounts/${accountId.substring(0, 8)}...`);
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 10000); // 10 second timeout
      
      try {
        // Note: Analytics Engine dataset name might be needed in URL
        const apiUrl = `https://api.cloudflare.com/client/v4/accounts/${accountId}/analytics_engine/sql`;
        console.log(`📡 Analytics Engine SQL API URL: ${apiUrl}`);
        console.log(`📊 Query being sent: ${query}`);
        
        // Try different request formats based on Cloudflare's Analytics Engine API
        console.log('🧪 Trying Analytics Engine SQL API format...');
        
        const response = await fetch(apiUrl, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${apiToken}`,
            'Content-Type': 'text/plain', // Try text/plain instead of JSON
          },
          body: query, // Send raw SQL query, not JSON
          signal: controller.signal
        });
        
        clearTimeout(timeoutId);
        console.log(`📡 Analytics Engine API response: ${response.status} ${response.statusText}`);
        
        if (!response.ok) {
          const errorText = await response.text();
          console.error(`❌ Analytics Engine API error: ${response.status} - ${errorText}`);
          throw new Error(`HTTP ${response.status}: ${response.statusText} - ${errorText}`);
        }
        
        const result = await response.json();
        console.log('📊 Analytics Engine result structure:', Object.keys(result));
        const rows = result.data || [];
        
        console.log(`✅ Analytics query returned ${rows.length} rows`);
        if (rows.length > 0) {
          console.log('📋 Query results preview:', JSON.stringify(rows.slice(0, 3), null, 2));
        }
        
        return rows;
      } catch (error) {
        clearTimeout(timeoutId);
        if (error.name === 'AbortError') {
          console.error('⏰ Analytics Engine query timed out after 10 seconds');
          throw new Error('Analytics Engine query timeout');
        }
        throw error;
      }
    } catch (error) {
      console.error('Analytics Engine SQL query failed:', error);
      console.error('Error details:', {
        message: error.message,
        stack: error.stack,
        query: query
      });
      
      // Return empty results instead of throwing to prevent breaking the API
      return [];
    }
  }

  /**
   * Get system health metrics (compatibility with existing system)
   */
  async getHealthStatus(): Promise<any> {
    const realtimeMetrics = await this.getRealtimeMetrics();
    
    // Check system dependencies
    const dependencies = await this.checkDependencies();
    
    return {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      metrics: {
        totalRequests: realtimeMetrics.totalEvents || 0,
        activeVideos: realtimeMetrics.activeVideos || 0,
        activeUsers: realtimeMetrics.activeUsers || 0,
        averageWatchTime: realtimeMetrics.avgWatchTime || 0,
        requestsPerMinute: Math.round((realtimeMetrics.totalEvents || 0) / 5)
      },
      dependencies
    };
  }

  /**
   * Check the health of system dependencies
   */
  private async checkDependencies(): Promise<any> {
    const checks = {
      analyticsEngine: 'unknown',
      r2: 'unknown',
      kv: 'unknown'
    };

    // Check Analytics Engine (data writing works, SQL queries need API setup)
    try {
      const hasApiCredentials = !!(this.env.CLOUDFLARE_ACCOUNT_ID && this.env.CLOUDFLARE_API_TOKEN);
      checks.analyticsEngine = hasApiCredentials ? 'healthy' : 'configured-for-writes-only';
    } catch (error) {
      checks.analyticsEngine = 'error';
    }

    // Check R2 Storage
    try {
      await this.env.MEDIA_BUCKET.list({ limit: 1 });
      checks.r2 = 'healthy';
    } catch (error) {
      checks.r2 = 'error';
    }

    // Check KV Storage
    try {
      await this.env.METADATA_CACHE.list({ limit: 1 });
      checks.kv = 'healthy';
    } catch (error) {
      checks.kv = 'error';
    }

    return checks;
  }

  /**
   * Get social metrics for a specific video
   */
  async getVideoSocialMetrics(videoId: string): Promise<VideoSocialMetrics> {
    try {
      // Query Analytics Engine directly (no KV cache)
      const query = `
        SELECT 
          blob3 AS interactionType,
          SUM(double1) AS count
        FROM VIDEO_ANALYTICS
        WHERE blob1 = '${videoId}'
          AND blob3 IN ('like', 'repost', 'comment')
          AND timestamp >= NOW() - INTERVAL '30' DAY
        GROUP BY interactionType
      `;

      const response = await this.executeAnalyticsQuery(query);
      
      // Initialize metrics
      let metrics: VideoSocialMetrics = {
        videoId,
        likes: 0,
        reposts: 0,
        comments: 0,
        engagementRate: 0,
        lastUpdated: new Date().toISOString()
      };

      // Process query results
      if (response && response.length > 0) {
        for (const row of response) {
          const interactionType = row.interactionType;
          const count = parseInt(row.count) || 0;
          
          switch (interactionType) {
            case 'like':
              metrics.likes = count;
              break;
            case 'repost':
              metrics.reposts = count;
              break;
            case 'comment':
              metrics.comments = count;
              break;
          }
        }
      }

      // Calculate engagement rate
      const totalInteractions = metrics.likes + metrics.reposts + metrics.comments;
      // TODO: Get actual view count from analytics for better engagement calculation
      metrics.engagementRate = totalInteractions > 0 ? Math.min(totalInteractions / Math.max(totalInteractions, 100), 1) : 0;

      // No caching - return directly from Analytics Engine
      return metrics;
    } catch (error) {
      console.error('Failed to get video social metrics:', error);
      
      // Return empty metrics on error
      return {
        videoId,
        likes: 0,
        reposts: 0,
        comments: 0,
        engagementRate: 0,
        lastUpdated: new Date().toISOString()
      };
    }
  }

  /**
   * Get social metrics for multiple videos (batch operation)
   */
  async getBatchVideoSocialMetrics(videoIds: string[]): Promise<{ [videoId: string]: VideoSocialMetrics }> {
    const results: { [videoId: string]: VideoSocialMetrics } = {};
    
    // Process in parallel for better performance
    await Promise.all(
      videoIds.map(async (videoId) => {
        results[videoId] = await this.getVideoSocialMetrics(videoId);
      })
    );
    
    return results;
  }
}