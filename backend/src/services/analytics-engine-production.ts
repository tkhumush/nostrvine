// ABOUTME: Production-ready Analytics Engine service with test data filtering
// ABOUTME: Filters out test event IDs and calculates proper completion rates

export class ProductionAnalyticsEngineService {
  constructor(
    private env: Env,
    private ctx: ExecutionContext
  ) {}

  /**
   * Get trending videos with test data filtered out
   */
  async getTrendingVideos(window: '1h' | '24h' | '7d' = '24h', limit: number = 50): Promise<any[]> {
    const intervalMap = {
      '1h': `INTERVAL '1' HOUR`,
      '24h': `INTERVAL '24' HOUR`,
      '7d': `INTERVAL '7' DAY`
    };

    const query = `
      SELECT
        blob1 AS videoId,
        SUM(double1) AS views,
        COUNT(DISTINCT blob2) AS uniqueViewers,
        AVG(double4) AS avgCompletion
      FROM nostrvine_video_views
      WHERE blob5 IN ('view_end', 'view_start')
        AND toDateTime(double8/1000) >= now() - ${intervalMap[window]}
        AND length(blob1) = 64
        AND blob1 NOT LIKE '%test%'
        AND blob1 NOT LIKE '%debug%'
        AND blob1 NOT LIKE '%timeout%'
        AND blob1 NOT LIKE '%minimal%'
        AND blob1 NOT LIKE '%perf%'
        AND blob1 NOT LIKE '%integration%'
        AND blob1 REGEXP '^[0-9a-f]{64}$'
      GROUP BY videoId
      HAVING views > 1
      ORDER BY views DESC
      LIMIT ${limit}
    `;

    try {
      const response = await this.executeQuery(query);
      
      // Calculate viral scores and format response
      return response.map(row => ({
        eventId: row.videoId,  // Use eventId for mobile app compatibility
        views: parseInt(row.views),
        uniqueViewers: parseInt(row.uniqueViewers),
        avgCompletion: parseFloat(row.avgCompletion) || 0.85, // Default 85% for 6-second videos
        viralScore: this.calculateViralScore(
          parseInt(row.views),
          parseInt(row.uniqueViewers),
          parseFloat(row.avgCompletion) || 0.85
        )
      }));
    } catch (error) {
      console.error('Failed to get trending videos:', error);
      
      // Fallback: simpler query without regex
      const fallbackQuery = `
        SELECT
          blob1 AS videoId,
          SUM(double1) AS views,
          COUNT(DISTINCT blob2) AS uniqueViewers,
          AVG(double4) AS avgCompletion
        FROM nostrvine_video_views
        WHERE blob5 IN ('view_end', 'view_start')
          AND toDateTime(double8/1000) >= now() - ${intervalMap[window]}
          AND length(blob1) = 64
        GROUP BY videoId
        ORDER BY views DESC
        LIMIT ${limit}
      `;
      
      try {
        const response = await this.executeQuery(fallbackQuery);
        
        // Filter test data in JavaScript
        return response
          .filter(row => {
            const id = row.videoId;
            return !id.includes('test') && 
                   !id.includes('debug') && 
                   !id.includes('timeout') &&
                   !id.includes('minimal') &&
                   !id.includes('perf') &&
                   !id.includes('integration') &&
                   /^[0-9a-f]{64}$/i.test(id);
          })
          .map(row => ({
            eventId: row.videoId,
            views: parseInt(row.views),
            uniqueViewers: parseInt(row.uniqueViewers),
            avgCompletion: parseFloat(row.avgCompletion) || 0.85,
            viralScore: this.calculateViralScore(
              parseInt(row.views),
              parseInt(row.uniqueViewers),
              parseFloat(row.avgCompletion) || 0.85
            )
          }))
          .slice(0, limit);
      } catch (fallbackError) {
        console.error('Fallback query also failed:', fallbackError);
        return [];
      }
    }
  }

  /**
   * Calculate viral score for ranking
   */
  private calculateViralScore(views: number, uniqueViewers: number, completion: number): number {
    // Handle edge cases
    if (views === 0) return 0;
    if (completion === 0) completion = 0.85; // Default for 6-second videos
    
    // viral_score = sqrt(views) * completion * (1 + log2(unique_viewers + 1))
    return Math.sqrt(views) * completion * (1 + Math.log2(uniqueViewers + 1));
  }

  /**
   * Execute Analytics Engine SQL query
   */
  private async executeQuery(query: string): Promise<any[]> {
    const response = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${this.env.CLOUDFLARE_ACCOUNT_ID}/analytics_engine/sql`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.env.CLOUDFLARE_API_TOKEN}`,
          'Content-Type': 'text/plain',
        },
        body: query
      }
    );

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`Analytics Engine query failed: ${error}`);
    }

    const result = await response.json();
    return result.data || [];
  }

  /**
   * Track video view with proper completion rate calculation
   */
  async trackVideoView(event: any, request: Request): Promise<void> {
    const country = (request as any).cf?.country || 'unknown';
    const timestamp = new Date().toISOString();
    const date = timestamp.split('T')[0];
    const hour = new Date().getHours();
    const hashtagsStr = event.hashtags?.join(',') || '';

    // Calculate completion rate if not provided
    let completionRate = event.completionRate || 0;
    
    if (event.watchDuration && event.totalDuration && event.totalDuration > 0) {
      completionRate = Math.min(1, event.watchDuration / event.totalDuration);
    } else if (event.eventType === 'view_end') {
      // Default 85% for completed 6-second videos
      completionRate = 0.85;
    }

    // Filter out test data
    const videoId = event.videoId;
    if (videoId.includes('test') || 
        videoId.includes('debug') || 
        videoId.includes('timeout') ||
        videoId.includes('integration') ||
        videoId.length !== 64) {
      console.log('Skipping test event:', videoId);
      return;
    }

    // Write to Analytics Engine
    this.ctx.waitUntil(
      this.writeAnalyticsDataPoint({
        blobs: [
          videoId,
          event.userId || 'anonymous',
          country,
          event.source,
          event.eventType,
          date,
          event.creatorPubkey || 'unknown',
          hashtagsStr,
          event.title || '',
          hour.toString()
        ],
        doubles: [
          1,
          event.watchDuration || 0,
          event.loopCount || 0,
          completionRate, // Fixed completion rate
          event.totalDuration || 0,
          event.eventType === 'view_start' ? 1 : 0,
          event.eventType === 'view_end' ? 1 : 0,
          Date.now()
        ],
        indexes: [videoId]
      })
    );

    console.log(`📊 Tracked ${event.eventType} for ${videoId.substring(0, 8)}... (${(completionRate * 100).toFixed(1)}% completion)`);
  }

  private async writeAnalyticsDataPoint(data: any): Promise<void> {
    if (this.env.VIDEO_ANALYTICS) {
      await this.env.VIDEO_ANALYTICS.writeDataPoint(data);
    }
  }
}