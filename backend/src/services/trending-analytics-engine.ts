// ABOUTME: Trending calculation service using Analytics Engine SQL queries
// ABOUTME: Replaces KV-based trending with proper viral score calculations

export interface TrendingVideo {
  videoId: string;
  views: number;
  uniqueViewers: number;
  avgCompletion: number;
  viralScore: number;
  title?: string;
  creatorPubkey?: string;
  hashtags?: string[];
}

export interface TrendingHashtag {
  tag: string;
  views: number;
  videoCount: number;
}

export interface RelatedVideo {
  videoId: string;
  sharedTags: number;
  totalViews: number;
  relevanceScore: number;
}

export class TrendingAnalyticsEngineService {
  constructor(
    private env: Env,
    private ctx: ExecutionContext
  ) {}

  /**
   * Get trending videos with viral score calculation
   * viral_score = sqrt(views) * avg_completion * (1 + log2(unique_viewers))
   */
  async getTrendingVideos(
    window: '1h' | '24h' | '7d' = '24h',
    limit: number = 50
  ): Promise<TrendingVideo[]> {
    // Map window to SQL interval
    const windowMap = {
      '1h': '1 HOUR',
      '24h': '1 DAY',
      '7d': '7 DAY'
    };

    const query = `
      WITH metrics AS (
        SELECT
          blob1 AS video_id,
          SUM(double1 * toUInt32(_sample_interval)) AS views,
          uniqExact(blob2) AS unique_viewers,
          AVG(double4) AS avg_completion,
          MAX(blob9) AS title,
          MAX(blob7) AS creator_pubkey,
          MAX(blob8) AS hashtags
        FROM nostrvine_video_views
        WHERE blob5 = 'view_end'
          AND toDateTime(double8/1000) >= now() - INTERVAL ${windowMap[window]}
        GROUP BY video_id
      )
      SELECT
        video_id AS videoId,
        views,
        unique_viewers AS uniqueViewers,
        avg_completion AS avgCompletion,
        sqrt(views) * avg_completion * (1 + log2(unique_viewers + 1)) AS viralScore,
        title,
        creator_pubkey AS creatorPubkey,
        hashtags
      FROM metrics
      WHERE views > 0
      ORDER BY viralScore DESC
      LIMIT ${limit}
    `;

    try {
      const results = await this.executeQuery(query);
      return results.map(row => ({
        videoId: row.videoId,
        views: parseInt(row.views),
        uniqueViewers: parseInt(row.uniqueViewers),
        avgCompletion: parseFloat(row.avgCompletion) || 0,
        viralScore: parseFloat(row.viralScore) || 0,
        title: row.title || undefined,
        creatorPubkey: row.creatorPubkey || undefined,
        hashtags: row.hashtags ? row.hashtags.split(',') : undefined
      }));
    } catch (error) {
      console.error('Failed to get trending videos:', error);
      return [];
    }
  }

  /**
   * Get most popular hashtags
   */
  async getTrendingHashtags(
    window: '1h' | '24h' | '7d' = '24h',
    limit: number = 100
  ): Promise<TrendingHashtag[]> {
    const windowMap = {
      '1h': '1 HOUR',
      '24h': '1 DAY',
      '7d': '7 DAY'
    };

    const query = `
      WITH tag_views AS (
        SELECT
          arrayJoin(splitByChar(',', lower(blob8))) AS tag,
          double1 AS view_count,
          toUInt32(_sample_interval) AS sample_mult,
          blob1 AS video_id
        FROM nostrvine_video_views
        WHERE blob5 = 'view_end'
          AND toDateTime(double8/1000) >= now() - INTERVAL ${windowMap[window]}
          AND length(blob8) > 0
      )
      SELECT
        tag,
        SUM(view_count * sample_mult) AS views,
        COUNT(DISTINCT video_id) AS videoCount
      FROM tag_views
      WHERE length(tag) > 0
      GROUP BY tag
      ORDER BY views DESC
      LIMIT ${limit}
    `;

    try {
      const results = await this.executeQuery(query);
      return results.map(row => ({
        tag: row.tag,
        views: parseInt(row.views),
        videoCount: parseInt(row.videoCount)
      }));
    } catch (error) {
      console.error('Failed to get trending hashtags:', error);
      return [];
    }
  }

  /**
   * Get related videos based on shared hashtags
   */
  async getRelatedVideos(
    seedVideoId: string,
    limit: number = 40
  ): Promise<RelatedVideo[]> {
    const query = `
      WITH seed_tags AS (
        SELECT arrayDistinct(splitByChar(',', lower(blob8))) AS tags
        FROM nostrvine_video_views
        WHERE blob1 = '${seedVideoId}'
          AND length(blob8) > 0
        LIMIT 1
      ),
      video_tags AS (
        SELECT
          blob1 AS video_id,
          arrayDistinct(splitByChar(',', lower(blob8))) AS tags,
          SUM(double1 * toUInt32(_sample_interval)) AS views
        FROM nostrvine_video_views
        WHERE blob5 = 'view_end'
          AND length(blob8) > 0
          AND blob1 != '${seedVideoId}'
          AND toDateTime(double8/1000) >= now() - INTERVAL 30 DAY
        GROUP BY video_id, blob8
      )
      SELECT
        video_id AS videoId,
        length(arrayIntersect(video_tags.tags, seed_tags.tags)) AS sharedTags,
        views AS totalViews,
        length(arrayIntersect(video_tags.tags, seed_tags.tags)) * sqrt(views) AS relevanceScore
      FROM video_tags
      CROSS JOIN seed_tags
      WHERE length(arrayIntersect(video_tags.tags, seed_tags.tags)) >= 2
      ORDER BY relevanceScore DESC
      LIMIT ${limit}
    `;

    try {
      const results = await this.executeQuery(query);
      return results.map(row => ({
        videoId: row.videoId,
        sharedTags: parseInt(row.sharedTags),
        totalViews: parseInt(row.totalViews),
        relevanceScore: parseFloat(row.relevanceScore) || 0
      }));
    } catch (error) {
      console.error('Failed to get related videos:', error);
      return [];
    }
  }

  /**
   * Get co-watched videos (users who watched seedVideo also watched these)
   */
  async getCoWatchedVideos(
    seedVideoId: string,
    window: '1h' | '24h' | '7d' = '24h',
    limit: number = 40
  ): Promise<{ videoId: string; coWatchers: number }[]> {
    const windowMap = {
      '1h': '1 HOUR',
      '24h': '1 DAY',
      '7d': '7 DAY'
    };

    const query = `
      WITH view_sessions AS (
        SELECT
          blob2 AS user_id,
          blob1 AS video_id,
          MAX(double8) AS ts
        FROM nostrvine_video_views
        WHERE blob5 = 'view_start'
          AND toDateTime(double8/1000) >= now() - INTERVAL ${windowMap[window]}
          AND blob2 != 'anonymous'
        GROUP BY user_id, video_id
      ),
      seed_viewers AS (
        SELECT DISTINCT user_id
        FROM view_sessions
        WHERE video_id = '${seedVideoId}'
      )
      SELECT
        v.video_id AS videoId,
        COUNT(DISTINCT v.user_id) AS coWatchers
      FROM view_sessions v
      INNER JOIN seed_viewers s ON v.user_id = s.user_id
      WHERE v.video_id != '${seedVideoId}'
      GROUP BY v.video_id
      ORDER BY coWatchers DESC
      LIMIT ${limit}
    `;

    try {
      const results = await this.executeQuery(query);
      return results.map(row => ({
        videoId: row.videoId,
        coWatchers: parseInt(row.coWatchers)
      }));
    } catch (error) {
      console.error('Failed to get co-watched videos:', error);
      return [];
    }
  }

  /**
   * Get creator leaderboard
   */
  async getTopCreators(
    window: '24h' | '7d' | '30d' = '7d',
    limit: number = 50
  ): Promise<any[]> {
    const windowMap = {
      '24h': '1 DAY',
      '7d': '7 DAY',
      '30d': '30 DAY'
    };

    const query = `
      SELECT
        blob7 AS creatorPubkey,
        COUNT(DISTINCT blob1) AS videoCount,
        SUM(double1 * toUInt32(_sample_interval)) AS totalViews,
        uniqExact(blob2) AS uniqueViewers,
        AVG(double4) AS avgCompletion,
        SUM(double3 * toUInt32(_sample_interval)) AS totalLoops
      FROM nostrvine_video_views
      WHERE blob5 = 'view_end'
        AND toDateTime(double8/1000) >= now() - INTERVAL ${windowMap[window]}
        AND blob7 != 'unknown'
      GROUP BY creatorPubkey
      ORDER BY totalViews DESC
      LIMIT ${limit}
    `;

    try {
      const results = await this.executeQuery(query);
      return results.map(row => ({
        creatorPubkey: row.creatorPubkey,
        videoCount: parseInt(row.videoCount),
        totalViews: parseInt(row.totalViews),
        uniqueViewers: parseInt(row.uniqueViewers),
        avgCompletion: parseFloat(row.avgCompletion) || 0,
        totalLoops: parseInt(row.totalLoops)
      }));
    } catch (error) {
      console.error('Failed to get top creators:', error);
      return [];
    }
  }

  /**
   * Execute query against Analytics Engine
   */
  private async executeQuery(query: string): Promise<any[]> {
    const accountId = this.env.CLOUDFLARE_ACCOUNT_ID;
    const apiToken = this.env.CLOUDFLARE_API_TOKEN;
    
    if (!accountId || !apiToken) {
      console.error('Analytics Engine credentials not configured');
      return [];
    }

    try {
      const response = await fetch(
        `https://api.cloudflare.com/client/v4/accounts/${accountId}/analytics_engine/sql`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${apiToken}`,
            'Content-Type': 'text/plain',
          },
          body: query
        }
      );

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`Query failed: ${error}`);
      }

      const result = await response.json();
      return result.data || [];
    } catch (error) {
      console.error('Analytics Engine query error:', error);
      throw error;
    }
  }

  /**
   * Cache trending data in KV for fast access
   */
  async cacheTrendingData(): Promise<void> {
    try {
      // Calculate trending for all time windows
      const [trending1h, trending24h, trending7d] = await Promise.all([
        this.getTrendingVideos('1h', 50),
        this.getTrendingVideos('24h', 100),
        this.getTrendingVideos('7d', 200)
      ]);

      // Cache in KV with 5-minute TTL
      const ttl = 300; // 5 minutes
      await Promise.all([
        this.env.ANALYTICS_KV.put(
          'trending:1h',
          JSON.stringify(trending1h),
          { expirationTtl: ttl }
        ),
        this.env.ANALYTICS_KV.put(
          'trending:24h',
          JSON.stringify(trending24h),
          { expirationTtl: ttl }
        ),
        this.env.ANALYTICS_KV.put(
          'trending:7d',
          JSON.stringify(trending7d),
          { expirationTtl: ttl }
        )
      ]);

      console.log('✅ Trending data cached successfully');
    } catch (error) {
      console.error('Failed to cache trending data:', error);
    }
  }

  /**
   * Get cached trending data (for < 500ms response time)
   */
  async getCachedTrending(window: '1h' | '24h' | '7d' = '24h'): Promise<TrendingVideo[]> {
    try {
      const cached = await this.env.ANALYTICS_KV.get(`trending:${window}`);
      if (cached) {
        return JSON.parse(cached);
      }
    } catch (error) {
      console.error('Failed to get cached trending:', error);
    }
    
    // Fallback to live query if cache miss
    return this.getTrendingVideos(window);
  }
}