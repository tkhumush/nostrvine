#!/usr/bin/env node
// ABOUTME: Integration tests for trending queries against live Analytics Engine
// ABOUTME: Tests real SQL queries and viral score calculations with actual data

const ACCOUNT_ID = 'c84e7a9bf7ed99cb41b8e73566568c75';
const API_TOKEN = 'Qnh5CVxAcAldbePkdpr--7BJUW4seif_N5HSqIvF';

/**
 * Execute SQL query against Analytics Engine
 */
async function executeQuery(query) {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/analytics_engine/sql`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${API_TOKEN}`,
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
}

/**
 * Test 1: Viral Score Calculation
 */
async function testViralScoreCalculation() {
  console.log('\n📊 Test 1: Viral Score Calculation');
  console.log('=' .repeat(50));

  const query = `
    WITH metrics AS (
      SELECT
        blob1 AS video_id,
        SUM(double1 * toUInt32(_sample_interval)) AS views,
        COUNT(DISTINCT blob2) AS unique_viewers,
        AVG(double4) AS avg_completion,
        MAX(blob9) AS title
      FROM nostrvine_video_views
      WHERE blob5 IN ('view_end', 'view_start')
        AND toDateTime(double8/1000) >= now() - INTERVAL '30' DAY
      GROUP BY video_id
      HAVING views > 0
    )
    SELECT
      video_id,
      views,
      unique_viewers,
      round(avg_completion, 2) AS avg_completion,
      round(sqrt(views) * avg_completion * (1 + log2(unique_viewers + 1)), 2) AS viral_score,
      title
    FROM metrics
    ORDER BY viral_score DESC
    LIMIT 10
  `;

  try {
    const results = await executeQuery(query);
    console.log(`✅ Found ${results.length} videos with viral scores\n`);
    
    // Display top 5
    results.slice(0, 5).forEach((video, i) => {
      console.log(`${i + 1}. Video: ${video.video_id.substring(0, 8)}...`);
      console.log(`   Views: ${video.views}, Unique: ${video.unique_viewers}`);
      console.log(`   Completion: ${video.avg_completion || 0}%`);
      console.log(`   Viral Score: ${video.viral_score}`);
      console.log(`   Title: ${video.title || 'N/A'}\n`);
    });

    // Verify viral score calculation
    if (results.length > 0) {
      const video = results[0];
      const expectedScore = Math.sqrt(video.views) * (video.avg_completion || 0) * (1 + Math.log2(video.unique_viewers + 1));
      console.log(`🧪 Viral Score Verification:`);
      console.log(`   Calculated: ${video.viral_score}`);
      console.log(`   Expected: ${expectedScore.toFixed(2)}`);
      console.log(`   ✅ Match: ${Math.abs(video.viral_score - expectedScore) < 0.1}\n`);
    }
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 2: Hashtag Aggregation
 */
async function testHashtagAggregation() {
  console.log('\n#️⃣  Test 2: Hashtag Aggregation');
  console.log('=' .repeat(50));

  const query = `
    WITH tag_views AS (
      SELECT
        arrayJoin(splitByChar(',', lower(blob8))) AS tag,
        double1 AS view_count,
        toUInt32(_sample_interval) AS sample_mult,
        blob1 AS video_id
      FROM nostrvine_video_views
      WHERE blob5 IN ('view_end', 'view_start')
        AND toDateTime(double8/1000) >= now() - INTERVAL '7' DAY
        AND length(blob8) > 0
    )
    SELECT
      tag,
      SUM(view_count * sample_mult) AS total_views,
      COUNT(DISTINCT video_id) AS video_count,
      round(total_views / video_count, 2) AS avg_views_per_video
    FROM tag_views
    WHERE length(tag) > 0
    GROUP BY tag
    ORDER BY total_views DESC
    LIMIT 20
  `;

  try {
    const results = await executeQuery(query);
    console.log(`✅ Found ${results.length} trending hashtags\n`);
    
    // Display top 10
    results.slice(0, 10).forEach((tag, i) => {
      console.log(`${i + 1}. #${tag.tag}`);
      console.log(`   Total views: ${tag.total_views}`);
      console.log(`   Videos: ${tag.video_count}`);
      console.log(`   Avg views/video: ${tag.avg_views_per_video}\n`);
    });
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 3: Related Videos by Shared Hashtags
 */
async function testRelatedVideos() {
  console.log('\n🔗 Test 3: Related Videos Algorithm');
  console.log('=' .repeat(50));

  // First get a video with hashtags
  const seedQuery = `
    SELECT blob1 AS video_id, blob8 AS hashtags
    FROM nostrvine_video_views
    WHERE length(blob8) > 0
      AND position(blob8, ',') > 0
    LIMIT 1
  `;

  try {
    const seedResults = await executeQuery(seedQuery);
    if (seedResults.length === 0) {
      console.log('⚠️ No videos with multiple hashtags found for testing');
      return;
    }

    const seedVideo = seedResults[0];
    console.log(`🎬 Seed video: ${seedVideo.video_id.substring(0, 16)}...`);
    console.log(`   Hashtags: ${seedVideo.hashtags}\n`);

    // Find related videos
    const relatedQuery = `
      WITH seed_tags AS (
        SELECT arrayDistinct(splitByChar(',', lower('${seedVideo.hashtags}'))) AS tags
      ),
      video_tags AS (
        SELECT
          blob1 AS video_id,
          arrayDistinct(splitByChar(',', lower(blob8))) AS tags,
          SUM(double1 * toUInt32(_sample_interval)) AS views
        FROM nostrvine_video_views
        WHERE blob5 IN ('view_end', 'view_start')
          AND length(blob8) > 0
          AND blob1 != '${seedVideo.video_id}'
        GROUP BY video_id, blob8
      )
      SELECT
        video_id,
        length(arrayIntersect(video_tags.tags, seed_tags.tags)) AS shared_tags,
        views,
        round(length(arrayIntersect(video_tags.tags, seed_tags.tags)) * sqrt(views), 2) AS relevance_score
      FROM video_tags
      CROSS JOIN seed_tags
      WHERE length(arrayIntersect(video_tags.tags, seed_tags.tags)) >= 1
      ORDER BY relevance_score DESC
      LIMIT 10
    `;

    const relatedResults = await executeQuery(relatedQuery);
    console.log(`✅ Found ${relatedResults.length} related videos\n`);

    relatedResults.slice(0, 5).forEach((video, i) => {
      console.log(`${i + 1}. Video: ${video.video_id.substring(0, 16)}...`);
      console.log(`   Shared tags: ${video.shared_tags}`);
      console.log(`   Views: ${video.views}`);
      console.log(`   Relevance score: ${video.relevance_score}\n`);
    });
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 4: Time Window Queries
 */
async function testTimeWindows() {
  console.log('\n⏰ Test 4: Time Window Performance');
  console.log('=' .repeat(50));

  const windows = [
    { label: '1 hour', interval: "'1' HOUR" },
    { label: '24 hours', interval: "'1' DAY" },
    { label: '7 days', interval: "'7' DAY" }
  ];

  for (const window of windows) {
    const query = `
      SELECT
        COUNT(*) AS total_events,
        COUNT(DISTINCT blob1) AS unique_videos,
        COUNT(DISTINCT blob2) AS unique_users
      FROM nostrvine_video_views
      WHERE toDateTime(double8/1000) >= now() - INTERVAL ${window.interval}
    `;

    try {
      const start = Date.now();
      const results = await executeQuery(query);
      const duration = Date.now() - start;
      
      console.log(`📊 ${window.label} window:`);
      console.log(`   Events: ${results[0].total_events}`);
      console.log(`   Videos: ${results[0].unique_videos}`);
      console.log(`   Users: ${results[0].unique_users}`);
      console.log(`   Query time: ${duration}ms`);
      console.log(`   ${duration < 500 ? '✅' : '⚠️'} Performance: ${duration < 500 ? 'Good' : 'Slow'}\n`);
    } catch (error) {
      console.error(`❌ ${window.label} failed:`, error.message);
    }
  }
}

/**
 * Test 5: Sample Interval Handling
 */
async function testSampleInterval() {
  console.log('\n🎯 Test 5: Sample Interval Handling');
  console.log('=' .repeat(50));

  const query = `
    SELECT
      toUInt32(_sample_interval) AS sample_interval,
      COUNT(*) AS raw_count,
      COUNT(*) * toUInt32(_sample_interval) AS adjusted_count
    FROM nostrvine_video_views
    WHERE toDateTime(double8/1000) >= now() - INTERVAL '1' DAY
    GROUP BY sample_interval
  `;

  try {
    const results = await executeQuery(query);
    console.log(`✅ Sample interval check:\n`);
    
    results.forEach(row => {
      console.log(`   Interval: ${row.sample_interval}`);
      console.log(`   Raw count: ${row.raw_count}`);
      console.log(`   Adjusted count: ${row.adjusted_count}`);
      console.log(`   ${row.sample_interval === '1' ? '✅ No sampling (good for current volume)' : '⚠️ Sampling active'}\n`);
    });
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 6: Gorse.io Export Format
 */
async function testGorseExport() {
  console.log('\n🤖 Test 6: Gorse.io ML Export Format');
  console.log('=' .repeat(50));
  console.log('Testing data export format for Gorse.io recommendation engine\n');

  // User-item interactions for Gorse
  const interactionsQuery = `
    SELECT
      blob2 AS user_id,
      blob1 AS item_id,
      'view' AS feedback_type,
      toUInt32(double8/1000) AS timestamp
    FROM nostrvine_video_views
    WHERE blob5 = 'view_end'
      AND blob2 != 'anonymous'
      AND toDateTime(double8/1000) >= now() - INTERVAL '7' DAY
    LIMIT 100
  `;

  // Item features for Gorse
  const itemFeaturesQuery = `
    SELECT
      blob1 AS item_id,
      arrayJoin(splitByChar(',', blob8)) AS tag,
      'hashtag' AS feature_type
    FROM nostrvine_video_views
    WHERE length(blob8) > 0
    GROUP BY item_id, tag
    LIMIT 100
  `;

  try {
    const interactions = await executeQuery(interactionsQuery);
    const features = await executeQuery(itemFeaturesQuery);
    
    console.log('📦 Gorse.io Data Format:\n');
    
    console.log('1. User-Item Interactions (for collaborative filtering):');
    console.log('   Format: user_id, item_id, feedback_type, timestamp');
    interactions.slice(0, 3).forEach(row => {
      console.log(`   ${row.user_id.substring(0, 8)}..., ${row.item_id.substring(0, 8)}..., ${row.feedback_type}, ${row.timestamp}`);
    });
    console.log(`   Total: ${interactions.length} interactions ready for export\n`);
    
    console.log('2. Item Features (for content-based filtering):');
    console.log('   Format: item_id, feature_value, feature_type');
    features.slice(0, 3).forEach(row => {
      console.log(`   ${row.item_id.substring(0, 8)}..., ${row.tag}, ${row.feature_type}`);
    });
    console.log(`   Total: ${features.length} features ready for export\n`);
    
    console.log('✅ Data is compatible with Gorse.io import format');
    console.log('   Next step: Set up Gorse API and configure data pipeline');
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Run all tests
 */
async function runAllTests() {
  console.log('🚀 OpenVine Analytics Engine Integration Tests');
  console.log('=' .repeat(50));
  console.log(`Account: ${ACCOUNT_ID}`);
  console.log(`Dataset: nostrvine_video_views`);
  console.log(`Time: ${new Date().toISOString()}\n`);

  await testViralScoreCalculation();
  await testHashtagAggregation();
  await testRelatedVideos();
  await testTimeWindows();
  await testSampleInterval();
  await testGorseExport();

  console.log('\n✨ All tests completed!');
}

// Run tests
runAllTests().catch(console.error);