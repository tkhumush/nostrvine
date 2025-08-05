# OpenVine Analytics Engine Documentation

## Overview
OpenVine uses Cloudflare Analytics Engine to collect and analyze video engagement metrics in real-time. The system tracks both video views and social interactions (likes, reposts, comments) with high cardinality and time-series data.

## Database Information
- **Account**: Nos Verse (c84e7a9bf7ed99cb41b8e73566568c75)
- **Dataset Name**: `nostrvine_video_views`
- **Engine**: Cloudflare Analytics Engine (ClickHouse-based)
- **Storage**: Time-series optimized with automatic timestamp population

## Data Schema

### Video View Events
When a user views a video, we collect the following data:

#### String Fields (Blobs)
| Field | Blob # | Description | Example |
|-------|--------|-------------|---------|
| Video ID | blob1 | Unique Nostr event ID of the video | "060d451d764232f6..." |
| User ID | blob2 | Viewer's user ID or 'anonymous' | "user123" |
| Country | blob3 | Viewer's country from Cloudflare edge | "US" |
| Source | blob4 | Platform source | "mobile" or "web" |
| Event Type | blob5 | Type of view event | "view_start", "view_end", "pause" |
| Date | blob6 | Date in YYYY-MM-DD format | "2025-08-04" |
| Creator Pubkey | blob7 | Nostr public key of video creator | "npub1..." |
| Hashtags | blob8 | Comma-separated hashtags | "bitcoin,nostr,tech" |
| Video Title | blob9 | Title of the video | "My awesome vine" |
| Hour | blob10 | Hour of day (0-23) | "14" |

#### Numeric Fields (Doubles)
| Field | Double # | Description | Range |
|-------|----------|-------------|-------|
| View Count | double1 | Always 1 for each event | 1 |
| Watch Duration | double2 | Time watched in milliseconds | 0-∞ |
| Loop Count | double3 | Number of times video looped | 0-∞ |
| Completion Rate | double4 | Percentage of video watched | 0-1 |
| Total Duration | double5 | Video length in milliseconds | 0-∞ |
| Is New View | double6 | 1 if view_start event, 0 otherwise | 0 or 1 |
| Is Completed | double7 | 1 if view_end event, 0 otherwise | 0 or 1 |
| Timestamp | double8 | Unix timestamp in milliseconds | epoch ms |

### Social Interaction Events
When users interact with videos (like, repost, comment):

#### String Fields (Blobs)
| Field | Blob # | Description | Example |
|-------|--------|-------------|---------|
| Video ID | blob1 | Video being interacted with | "060d451d764232f6..." |
| User ID | blob2 | User performing the action | "user456" |
| Interaction Type | blob3 | Type of social action | "like", "repost", "comment" |
| Nostr Event ID | blob4 | Unique ID of the Nostr event | "event789..." |
| Country | blob5 | User's country | "UK" |
| Date | blob6 | Date in YYYY-MM-DD format | "2025-08-04" |
| Creator Pubkey | blob7 | Creator of the video | "npub1..." |
| Content Preview | blob8 | First 100 chars of comment | "Great video! I love..." |
| Hour | blob9 | Hour of day | "15" |
| Nostr Event Kind | blob10 | Nostr protocol event type | "7" (reaction), "6" (repost) |

#### Numeric Fields (Doubles)
| Field | Double # | Description | Value |
|-------|----------|-------------|-------|
| Interaction Count | double1 | Always 1 per event | 1 |
| Interaction Type Numeric | double2 | Numeric mapping | 1=like, 2=repost, 3=comment |
| Nostr Event Kind | double3 | Nostr event kind number | 7, 6, 1 |
| Event Timestamp | double4 | When interaction occurred | epoch ms |
| Content Length | double5 | Length of comment text | 0-∞ |
| Ingestion Timestamp | double6 | When we received the event | epoch ms |

## Supported Queries

### 1. Popular Videos
**Endpoint**: `GET /api/analytics/popular?window=24h&limit=10`
```sql
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
LIMIT 10
```
**Returns**: Most viewed videos with engagement metrics

### 2. Video-Specific Analytics
**Endpoint**: `GET /api/analytics/video/{videoId}?days=30`
```sql
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
WHERE blob1 = '{videoId}'
  AND timestamp >= NOW() - INTERVAL '30' DAY
GROUP BY date
ORDER BY date DESC
```
**Returns**: Daily metrics for a specific video

### 3. Real-time Platform Metrics
**Endpoint**: `GET /api/analytics/dashboard`
```sql
SELECT 
  COUNT(*) AS totalEvents,
  COUNT(DISTINCT blob1) AS activeVideos,
  COUNT(DISTINCT blob2) AS activeUsers,
  AVG(double2) AS avgWatchTime,
  SUM(double6) AS newViews
FROM nostrvine_video_views
```
**Returns**: Overall platform activity metrics

### 4. Hashtag Analytics
**Endpoint**: `GET /api/analytics/hashtag?hashtag={tag}&days=7`
```sql
SELECT 
  blob1 AS videoId,
  blob9 AS title,
  SUM(double1) AS views,
  AVG(double2) AS avgWatchTime,
  AVG(double4) AS avgCompletionRate
FROM nostrvine_video_views
WHERE blob8 LIKE '%{hashtag}%'
  AND timestamp >= NOW() - INTERVAL '7' DAY
GROUP BY videoId, title
ORDER BY views DESC
LIMIT 20
```
**Returns**: Top videos for a specific hashtag

### 5. Creator Analytics
**Endpoint**: `GET /api/analytics/creator?pubkey={pubkey}&days=30`
```sql
SELECT 
  blob1 AS videoId,
  blob9 AS title,
  SUM(double1) AS totalViews,
  COUNT(DISTINCT blob2) AS uniqueViewers,
  AVG(double2) AS avgWatchTime,
  AVG(double4) AS avgCompletionRate,
  SUM(double3) AS totalLoops
FROM nostrvine_video_views
WHERE blob7 = '{creatorPubkey}'
  AND timestamp >= NOW() - INTERVAL '30' DAY
GROUP BY videoId, title
ORDER BY totalViews DESC
```
**Returns**: Performance metrics for all videos by a creator

### 6. Video Social Metrics
**Endpoint**: `GET /api/analytics/video/{videoId}/social`
```sql
SELECT 
  blob3 AS interactionType,
  SUM(double1) AS count
FROM nostrvine_video_views
WHERE blob1 = '{videoId}'
  AND blob3 IN ('like', 'repost', 'comment')
  AND timestamp >= NOW() - INTERVAL '30' DAY
GROUP BY interactionType
```
**Returns**: Social engagement counts (likes, reposts, comments)

### 7. Batch Social Metrics
**Endpoint**: `POST /api/analytics/social/batch`
**Body**: `{ "videoIds": ["id1", "id2", "id3"] }`
**Returns**: Social metrics for multiple videos at once (max 50)

## Event Types Tracked

### View Events
- `view_start` - User begins watching
- `view_end` - User completes watching
- `pause` - User pauses video
- `resume` - User resumes video
- `loop` - Video loops/replays

### Social Events
- `like` - User likes/hearts a video (Nostr Kind 7)
- `repost` - User reposts/shares a video (Nostr Kind 6)
- `comment` - User comments on a video (Nostr Kind 1)

## Geographic Analytics
All events include country-level geographic data from Cloudflare's edge network, enabling:
- Regional popularity tracking
- Geographic distribution of viewers
- Country-specific trending content

## Time-Series Capabilities
- Automatic timestamp population on every event
- Hour-of-day tracking for engagement patterns
- Daily aggregations for trend analysis
- Support for time-window queries (1h, 24h, 7d, 30d)

## Performance Characteristics
- **Write Performance**: Asynchronous, non-blocking writes
- **Query Performance**: Sub-second for most aggregations
- **Data Retention**: Currently unlimited (no TTL set)
- **Cardinality**: Unlimited - no restrictions on unique values
- **Real-time**: Data available for querying immediately after write

## Limitations
- No JOIN operations between tables
- No UNION queries
- Single dataset queries only
- Maximum query timeout: 10 seconds
- No support for subqueries

## Future Enhancements (Planned)
- Engagement rate calculations with actual view counts
- Retention cohort analysis
- Funnel analytics for user journeys
- A/B testing metrics
- Revenue/monetization tracking
- Advanced geographic heatmaps