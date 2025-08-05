// ABOUTME: Fallback analytics service using KV for immediate results
// ABOUTME: Complements Analytics Engine with real-time queryable data

export interface VideoViewRecord {
  videoId: string;
  userId?: string;
  creatorPubkey?: string;
  source: string;
  eventType: string;
  timestamp: number;
  watchDuration?: number;
  totalDuration?: number;
  loopCount?: number;
  completionRate?: number;
  hashtags?: string[];
  title?: string;
}

export interface VideoStats {
  videoId: string;
  views: number;
  uniqueViewers: Set<string>;
  totalWatchTime: number;
  totalLoops: number;
  lastView: number;
  title?: string;
  creatorPubkey?: string;
  hashtags?: string[];
}

export class AnalyticsFallbackService {
  constructor(
    private env: Env,
    private ctx: ExecutionContext
  ) {}

  /**
   * Track video view and store in KV for immediate querying
   */
  async trackVideoView(event: VideoViewRecord): Promise<void> {
    const now = Date.now();
    const today = new Date().toISOString().split('T')[0];
    
    // Store individual view record for detailed analytics
    const viewKey = `view:${event.videoId}:${now}:${Math.random().toString(36).substring(7)}`;
    
    try {
      console.log(`🔄 Storing view record: ${viewKey}`);
      // Store the view record with 7 day TTL  
      await this.env.ANALYTICS_KV.put(viewKey, JSON.stringify(event), {
        expirationTtl: 7 * 24 * 60 * 60 // 7 days
      });
      console.log(`✅ View record stored successfully: ${viewKey}`);

      console.log(`🔄 Updating video stats for: ${event.videoId}`);
      // Update video stats aggregation
      await this.updateVideoStats(event);
      console.log(`✅ Video stats updated for: ${event.videoId}`);
      
      console.log(`🔄 Updating daily stats for: ${today}`);
      // Update daily stats
      await this.updateDailyStats(today, event);
      console.log(`✅ Daily stats updated for: ${today}`);
      
      console.log(`📊 Fallback analytics: Tracked ${event.eventType} for video ${event.videoId.substring(0, 8)}...`);
    } catch (error) {
      console.error('💥 Failed to store fallback analytics:', error);
      console.error('💥 Error details:', JSON.stringify(error, null, 2));
      throw error; // Re-throw to see the error in the main handler
    }
  }

  /**
   * Update aggregated video statistics - writes to views: key used by trending calculator
   */
  private async updateVideoStats(event: VideoViewRecord): Promise<void> {
    const viewKey = `views:${event.videoId}`;
    
    try {
      console.log(`🔄 Reading existing view data: ${viewKey}`);
      // Get existing view data (matches structure expected by trending calculator)
      const existingData = await this.env.ANALYTICS_KV.get(viewKey);
      let viewData: any;
      
      if (existingData) {
        viewData = JSON.parse(existingData);
        console.log(`📖 Found existing view data: count=${viewData.count}`);
      } else {
        console.log(`🆕 Creating new view data for: ${event.videoId}`);
        viewData = {
          count: 0,
          uniqueViewers: 0,
          lastUpdate: 0,
          hashtags: event.hashtags || [],
          creatorPubkey: event.creatorPubkey,
          title: event.title,
          totalWatchTimeMs: 0,
          loopCount: 0,
          completedViews: 0,
          pauseCount: 0,
          skipCount: 0,
          averageWatchTimeMs: 0
        };
      }

      // Update view data based on event type
      if (event.eventType === 'view_start' || event.eventType === 'view') {
        viewData.count += 1;
        if (event.userId) {
          viewData.uniqueViewers += 1; // Simplified - would need better unique tracking
        }
      }
      
      if (event.watchDuration) {
        viewData.totalWatchTimeMs += event.watchDuration;
        viewData.averageWatchTimeMs = viewData.count > 0 ? Math.round(viewData.totalWatchTimeMs / viewData.count) : 0;
      }
      
      if (event.loopCount) {
        viewData.loopCount += event.loopCount;
      }
      
      viewData.lastUpdate = event.timestamp;

      console.log(`💾 Writing view data: ${viewKey}, count=${viewData.count}`);
      // Store updated view data (matches trending calculator expectations)
      await this.env.ANALYTICS_KV.put(viewKey, JSON.stringify(viewData), {
        expirationTtl: 30 * 24 * 60 * 60 // 30 days
      });
      console.log(`✅ View data written successfully: ${viewKey}`);
    } catch (error) {
      console.error('💥 Failed to update video stats:', error);
      console.error('💥 Stats error details:', JSON.stringify(error, null, 2));
      throw error;
    }
  }

  /**
   * Update daily aggregated statistics
   */
  private async updateDailyStats(date: string, event: VideoViewRecord): Promise<void> {
    const dailyKey = `stats:daily:${date}`;
    
    try {
      const existingData = await this.env.ANALYTICS_KV.get(dailyKey);
      let dailyStats = existingData ? JSON.parse(existingData) : {
        date,
        totalEvents: 0,
        totalVideos: new Set(),
        totalUsers: new Set(),
        totalWatchTime: 0
      };

      // Update daily stats
      dailyStats.totalEvents += 1;
      dailyStats.totalVideos = new Set([...dailyStats.totalVideos, event.videoId]);
      if (event.userId) {
        dailyStats.totalUsers = new Set([...dailyStats.totalUsers, event.userId]);
      }
      if (event.watchDuration) {
        dailyStats.totalWatchTime += event.watchDuration;
      }

      // Store with sets converted to arrays
      const serializable = {
        ...dailyStats,
        totalVideos: Array.from(dailyStats.totalVideos),
        totalUsers: Array.from(dailyStats.totalUsers)
      };

      await this.env.ANALYTICS_KV.put(dailyKey, JSON.stringify(serializable), {
        expirationTtl: 30 * 24 * 60 * 60 // 30 days
      });
    } catch (error) {
      console.error('Failed to update daily stats:', error);
    }
  }

  /**
   * Get popular videos from KV fallback data
   */
  async getPopularVideos(limit: number = 10): Promise<any[]> {
    try {
      // List all view keys (matches trending calculator expectations)
      const listResult = await this.env.ANALYTICS_KV.list({ prefix: 'views:' });
      
      const videoStats: any[] = [];
      
      // Fetch each video's view data
      for (const key of listResult.keys) {
        try {
          const data = await this.env.ANALYTICS_KV.get(key.name);
          if (data) {
            const viewData = JSON.parse(data);
            const eventId = key.name.replace('views:', '');
            videoStats.push({
              videoId: eventId,
              views: viewData.count || 0,
              uniqueViewers: viewData.uniqueViewers || 0,
              avgWatchTime: viewData.averageWatchTimeMs || 0,
              totalLoops: viewData.loopCount || 0,
              lastView: viewData.lastUpdate,
              title: viewData.title,
              creatorPubkey: viewData.creatorPubkey
            });
          }
        } catch (error) {
          console.error(`Failed to parse view data for ${key.name}:`, error);
        }
      }
      
      // Sort by views and return top results
      return videoStats
        .sort((a, b) => b.views - a.views)
        .slice(0, limit);
        
    } catch (error) {
      console.error('Failed to get popular videos from fallback:', error);
      return [];
    }
  }

  /**
   * Get real-time metrics from fallback data
   */
  async getRealtimeMetrics(): Promise<any> {
    try {
      const today = new Date().toISOString().split('T')[0];
      const dailyData = await this.env.ANALYTICS_KV.get(`stats:daily:${today}`);
      
      if (!dailyData) {
        return {
          totalEvents: 0,
          activeVideos: 0,
          activeUsers: 0,
          averageWatchTime: 0
        };
      }
      
      const stats = JSON.parse(dailyData);
      
      return {
        totalEvents: stats.totalEvents || 0,
        activeVideos: stats.totalVideos?.length || 0,
        activeUsers: stats.totalUsers?.length || 0,
        averageWatchTime: stats.totalWatchTime / Math.max(stats.totalEvents, 1)
      };
    } catch (error) {
      console.error('Failed to get realtime metrics from fallback:', error);
      return {
        totalEvents: 0,
        activeVideos: 0,
        activeUsers: 0,
        averageWatchTime: 0
      };
    }
  }
}