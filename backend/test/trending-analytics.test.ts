// ABOUTME: Unit tests for TrendingAnalyticsEngineService
// ABOUTME: Tests viral score calculations and query generation

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { TrendingAnalyticsEngineService } from '../src/services/trending-analytics-engine';

// Mock fetch for Analytics Engine API
const mockFetch = vi.fn();
global.fetch = mockFetch;

describe('TrendingAnalyticsEngineService', () => {
  let service: TrendingAnalyticsEngineService;
  let mockEnv: any;
  let mockCtx: any;

  beforeEach(() => {
    vi.clearAllMocks();
    
    mockEnv = {
      CLOUDFLARE_ACCOUNT_ID: 'test-account-id',
      CLOUDFLARE_API_TOKEN: 'test-api-token',
      ANALYTICS_KV: {
        get: vi.fn(),
        put: vi.fn(),
      }
    };
    
    mockCtx = {
      waitUntil: vi.fn()
    };
    
    service = new TrendingAnalyticsEngineService(mockEnv, mockCtx);
  });

  describe('getTrendingVideos', () => {
    it('should calculate viral scores correctly', async () => {
      // Mock Analytics Engine response
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          data: [
            {
              videoId: 'video1',
              views: '100',
              uniqueViewers: '50',
              avgCompletion: '0.85',
              viralScore: '8.5', // sqrt(100) * 0.85 * (1 + log2(50))
              title: 'Test Video 1',
              creatorPubkey: 'npub1abc',
              hashtags: 'bitcoin,nostr'
            },
            {
              videoId: 'video2',
              views: '50',
              uniqueViewers: '30',
              avgCompletion: '0.90',
              viralScore: '6.36',
              title: 'Test Video 2',
              creatorPubkey: 'npub1def',
              hashtags: 'tech,coding'
            }
          ]
        })
      });

      const results = await service.getTrendingVideos('24h', 10);

      expect(results).toHaveLength(2);
      expect(results[0]).toEqual({
        videoId: 'video1',
        views: 100,
        uniqueViewers: 50,
        avgCompletion: 0.85,
        viralScore: 8.5,
        title: 'Test Video 1',
        creatorPubkey: 'npub1abc',
        hashtags: ['bitcoin', 'nostr']
      });

      // Verify the SQL query includes viral score calculation
      expect(mockFetch).toHaveBeenCalledWith(
        expect.stringContaining('/analytics_engine/sql'),
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'Authorization': 'Bearer test-api-token',
            'Content-Type': 'text/plain'
          }),
          body: expect.stringContaining('sqrt(views) * avg_completion * (1 + log2(unique_viewers + 1))')
        })
      );
    });

    it('should handle different time windows', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ data: [] })
      });

      await service.getTrendingVideos('1h', 10);

      expect(mockFetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          body: expect.stringContaining('INTERVAL 1 HOUR')
        })
      );

      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ data: [] })
      });

      await service.getTrendingVideos('7d', 10);

      expect(mockFetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          body: expect.stringContaining('INTERVAL 7 DAY')
        })
      );
    });

    it('should return empty array on API error', async () => {
      mockFetch.mockRejectedValueOnce(new Error('API Error'));

      const results = await service.getTrendingVideos('24h', 10);

      expect(results).toEqual([]);
    });
  });

  describe('getTrendingHashtags', () => {
    it('should parse and aggregate hashtags correctly', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          data: [
            { tag: 'bitcoin', views: '150', videoCount: '5' },
            { tag: 'nostr', views: '120', videoCount: '4' },
            { tag: 'tech', views: '80', videoCount: '3' }
          ]
        })
      });

      const results = await service.getTrendingHashtags('24h', 10);

      expect(results).toEqual([
        { tag: 'bitcoin', views: 150, videoCount: 5 },
        { tag: 'nostr', views: 120, videoCount: 4 },
        { tag: 'tech', views: 80, videoCount: 3 }
      ]);

      // Verify query includes hashtag parsing
      expect(mockFetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          body: expect.stringContaining('splitByChar(\',\', lower(blob8))')
        })
      );
    });
  });

  describe('getRelatedVideos', () => {
    it('should find videos with shared hashtags', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          data: [
            { videoId: 'related1', sharedTags: '3', totalViews: '50', relevanceScore: '21.21' },
            { videoId: 'related2', sharedTags: '2', totalViews: '30', relevanceScore: '10.95' }
          ]
        })
      });

      const results = await service.getRelatedVideos('seed-video-id', 20);

      expect(results).toEqual([
        { videoId: 'related1', sharedTags: 3, totalViews: 50, relevanceScore: 21.21 },
        { videoId: 'related2', sharedTags: 2, totalViews: 30, relevanceScore: 10.95 }
      ]);

      // Verify query includes arrayIntersect for shared tags
      expect(mockFetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          body: expect.stringContaining('arrayIntersect')
        })
      );
    });
  });

  describe('getCoWatchedVideos', () => {
    it('should find videos watched by same users', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          data: [
            { videoId: 'cowatched1', coWatchers: '15' },
            { videoId: 'cowatched2', coWatchers: '10' }
          ]
        })
      });

      const results = await service.getCoWatchedVideos('seed-video-id', '24h', 20);

      expect(results).toEqual([
        { videoId: 'cowatched1', coWatchers: 15 },
        { videoId: 'cowatched2', coWatchers: 10 }
      ]);

      // Verify query includes session JOIN logic
      expect(mockFetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          body: expect.and(
            expect.stringContaining('view_sessions'),
            expect.stringContaining('INNER JOIN')
          )
        })
      );
    });
  });

  describe('cacheTrendingData', () => {
    it('should cache all trending data with correct TTL', async () => {
      // Mock successful API responses
      mockFetch.mockResolvedValue({
        ok: true,
        json: async () => ({ data: [] })
      });

      await service.cacheTrendingData();

      // Verify KV puts were called for each time window
      expect(mockEnv.ANALYTICS_KV.put).toHaveBeenCalledWith(
        'trending:1h',
        expect.any(String),
        { expirationTtl: 300 }
      );
      expect(mockEnv.ANALYTICS_KV.put).toHaveBeenCalledWith(
        'trending:24h',
        expect.any(String),
        { expirationTtl: 300 }
      );
      expect(mockEnv.ANALYTICS_KV.put).toHaveBeenCalledWith(
        'trending:7d',
        expect.any(String),
        { expirationTtl: 300 }
      );
    });
  });

  describe('getCachedTrending', () => {
    it('should return cached data when available', async () => {
      const cachedData = [
        { videoId: 'cached1', views: 100, viralScore: 10 }
      ];
      
      mockEnv.ANALYTICS_KV.get.mockResolvedValueOnce(JSON.stringify(cachedData));

      const results = await service.getCachedTrending('24h');

      expect(results).toEqual(cachedData);
      expect(mockEnv.ANALYTICS_KV.get).toHaveBeenCalledWith('trending:24h');
      expect(mockFetch).not.toHaveBeenCalled();
    });

    it('should fallback to live query on cache miss', async () => {
      mockEnv.ANALYTICS_KV.get.mockResolvedValueOnce(null);
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ data: [] })
      });

      const results = await service.getCachedTrending('24h');

      expect(mockEnv.ANALYTICS_KV.get).toHaveBeenCalledWith('trending:24h');
      expect(mockFetch).toHaveBeenCalled();
    });
  });
});

describe('Viral Score Calculation', () => {
  it('should correctly calculate viral scores for different scenarios', () => {
    // Test cases with expected viral scores
    const testCases = [
      { views: 100, uniqueViewers: 50, avgCompletion: 0.85, expected: 59.98 },
      { views: 1000, uniqueViewers: 200, avgCompletion: 0.75, expected: 203.21 },
      { views: 10, uniqueViewers: 8, avgCompletion: 0.95, expected: 12.29 },
      { views: 0, uniqueViewers: 0, avgCompletion: 0, expected: 0 }
    ];

    testCases.forEach(({ views, uniqueViewers, avgCompletion, expected }) => {
      const viralScore = Math.sqrt(views) * avgCompletion * (1 + Math.log2(uniqueViewers + 1));
      expect(viralScore).toBeCloseTo(expected, 1);
    });
  });
});