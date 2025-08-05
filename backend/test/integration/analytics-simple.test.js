#!/usr/bin/env node
// ABOUTME: Simplified integration tests for Analytics Engine
// ABOUTME: Uses only supported SQL functions

const ACCOUNT_ID = 'c84e7a9bf7ed99cb41b8e73566568c75';
const API_TOKEN = 'Qnh5CVxAcAldbePkdpr--7BJUW4seif_N5HSqIvF';

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
 * Test 1: Basic Count and Aggregation
 */
async function testBasicAggregation() {
  console.log('\n📊 Test 1: Basic Aggregation');
  console.log('=' .repeat(50));

  const query = `
    SELECT
      blob1 AS video_id,
      SUM(double1) AS total_views,
      COUNT(DISTINCT blob2) AS unique_viewers,
      AVG(double4) AS avg_completion,
      MAX(blob9) AS title
    FROM nostrvine_video_views
    WHERE blob5 = 'view_end'
    GROUP BY video_id
    ORDER BY total_views DESC
    LIMIT 5
  `;

  try {
    const results = await executeQuery(query);
    console.log(`✅ Found ${results.length} videos\n`);
    
    results.forEach((video, i) => {
      console.log(`${i + 1}. Video: ${video.video_id.substring(0, 16)}...`);
      console.log(`   Views: ${video.total_views}`);
      console.log(`   Unique viewers: ${video.unique_viewers}`);
      console.log(`   Avg completion: ${(parseFloat(video.avg_completion) * 100).toFixed(1)}%`);
      console.log(`   Title: ${video.title || 'N/A'}\n`);
    });
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 2: Viral Score Calculation (Simplified)
 */
async function testViralScore() {
  console.log('\n🚀 Test 2: Viral Score (Simplified)');
  console.log('=' .repeat(50));

  const query = `
    SELECT
      blob1 AS video_id,
      SUM(double1) AS views,
      COUNT(DISTINCT blob2) AS unique_viewers,
      AVG(double4) AS completion_rate,
      SUM(double1) * AVG(double4) AS engagement_score
    FROM nostrvine_video_views
    WHERE blob5 = 'view_end'
    GROUP BY video_id
    HAVING views > 0
    ORDER BY engagement_score DESC
    LIMIT 5
  `;

  try {
    const results = await executeQuery(query);
    console.log(`✅ Top ${results.length} videos by engagement:\n`);
    
    results.forEach((video, i) => {
      // Calculate viral score in JavaScript
      const views = parseFloat(video.views);
      const uniqueViewers = parseFloat(video.unique_viewers);
      const completion = parseFloat(video.completion_rate) || 0;
      const viralScore = Math.sqrt(views) * completion * (1 + Math.log2(uniqueViewers + 1));
      
      console.log(`${i + 1}. Video: ${video.video_id.substring(0, 16)}...`);
      console.log(`   Views: ${views}, Unique: ${uniqueViewers}`);
      console.log(`   Completion: ${(completion * 100).toFixed(1)}%`);
      console.log(`   Engagement Score: ${parseFloat(video.engagement_score).toFixed(2)}`);
      console.log(`   Viral Score (calculated): ${viralScore.toFixed(2)}\n`);
    });
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 3: Time-based Analytics
 */
async function testTimeAnalytics() {
  console.log('\n⏰ Test 3: Time-based Analytics');
  console.log('=' .repeat(50));

  const query = `
    SELECT
      blob6 AS date,
      COUNT() AS events,
      COUNT(DISTINCT blob1) AS unique_videos,
      COUNT(DISTINCT blob2) AS unique_users,
      SUM(double1) AS total_views
    FROM nostrvine_video_views
    GROUP BY date
    ORDER BY date DESC
    LIMIT 7
  `;

  try {
    const results = await executeQuery(query);
    console.log(`✅ Last ${results.length} days of activity:\n`);
    
    results.forEach(day => {
      console.log(`📅 ${day.date}`);
      console.log(`   Events: ${day.events}`);
      console.log(`   Videos: ${day.unique_videos}`);
      console.log(`   Users: ${day.unique_users}`);
      console.log(`   Views: ${day.total_views}\n`);
    });
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 4: Creator Analytics
 */
async function testCreatorAnalytics() {
  console.log('\n👤 Test 4: Creator Analytics');
  console.log('=' .repeat(50));

  const query = `
    SELECT
      blob7 AS creator_pubkey,
      COUNT(DISTINCT blob1) AS video_count,
      SUM(double1) AS total_views,
      COUNT(DISTINCT blob2) AS unique_viewers,
      AVG(double4) AS avg_completion
    FROM nostrvine_video_views
    WHERE blob5 = 'view_end'
      AND blob7 != 'unknown'
    GROUP BY creator_pubkey
    ORDER BY total_views DESC
    LIMIT 5
  `;

  try {
    const results = await executeQuery(query);
    console.log(`✅ Top ${results.length} creators:\n`);
    
    results.forEach((creator, i) => {
      console.log(`${i + 1}. Creator: ${creator.creator_pubkey.substring(0, 16)}...`);
      console.log(`   Videos: ${creator.video_count}`);
      console.log(`   Total views: ${creator.total_views}`);
      console.log(`   Unique viewers: ${creator.unique_viewers}`);
      console.log(`   Avg completion: ${(parseFloat(creator.avg_completion) * 100).toFixed(1)}%\n`);
    });
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 5: Platform Metrics
 */
async function testPlatformMetrics() {
  console.log('\n📈 Test 5: Platform Metrics');
  console.log('=' .repeat(50));

  const query = `
    SELECT
      COUNT() AS total_events,
      COUNT(DISTINCT blob1) AS total_videos,
      COUNT(DISTINCT blob2) AS total_users,
      COUNT(DISTINCT blob7) AS total_creators,
      AVG(double2) AS avg_watch_duration_ms,
      AVG(double4) AS avg_completion_rate,
      SUM(double3) AS total_loops
    FROM nostrvine_video_views
    WHERE blob5 IN ('view_end', 'view_start')
  `;

  try {
    const results = await executeQuery(query);
    const metrics = results[0];
    
    console.log('✅ Overall Platform Metrics:\n');
    console.log(`   Total events: ${metrics.total_events}`);
    console.log(`   Total videos: ${metrics.total_videos}`);
    console.log(`   Total users: ${metrics.total_users}`);
    console.log(`   Total creators: ${metrics.total_creators}`);
    console.log(`   Avg watch duration: ${(parseFloat(metrics.avg_watch_duration_ms) / 1000).toFixed(2)}s`);
    console.log(`   Avg completion rate: ${(parseFloat(metrics.avg_completion_rate) * 100).toFixed(1)}%`);
    console.log(`   Total loops: ${metrics.total_loops}\n`);
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 6: Hashtag Analysis (Simplified)
 */
async function testHashtagAnalysis() {
  console.log('\n#️⃣  Test 6: Hashtag Analysis');
  console.log('=' .repeat(50));

  // Since we can't use splitByChar, let's analyze hashtag fields as-is
  const query = `
    SELECT
      blob8 AS hashtags,
      COUNT() AS occurrences,
      SUM(double1) AS total_views,
      COUNT(DISTINCT blob1) AS video_count
    FROM nostrvine_video_views
    WHERE blob5 = 'view_end'
      AND length(blob8) > 0
    GROUP BY hashtags
    ORDER BY total_views DESC
    LIMIT 10
  `;

  try {
    const results = await executeQuery(query);
    console.log(`✅ Top ${results.length} hashtag combinations:\n`);
    
    results.forEach((row, i) => {
      console.log(`${i + 1}. Tags: ${row.hashtags}`);
      console.log(`   Occurrences: ${row.occurrences}`);
      console.log(`   Total views: ${row.total_views}`);
      console.log(`   Videos: ${row.video_count}\n`);
    });
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

/**
 * Test 7: Performance Check
 */
async function testQueryPerformance() {
  console.log('\n⚡ Test 7: Query Performance');
  console.log('=' .repeat(50));

  const queries = [
    { name: 'Simple count', query: 'SELECT COUNT() FROM nostrvine_video_views' },
    { name: 'Grouped aggregation', query: 'SELECT blob1, SUM(double1) FROM nostrvine_video_views GROUP BY blob1 LIMIT 10' },
    { name: 'Distinct count', query: 'SELECT COUNT(DISTINCT blob1), COUNT(DISTINCT blob2) FROM nostrvine_video_views' }
  ];

  for (const test of queries) {
    try {
      const start = Date.now();
      await executeQuery(test.query);
      const duration = Date.now() - start;
      
      console.log(`📊 ${test.name}:`);
      console.log(`   Time: ${duration}ms`);
      console.log(`   Status: ${duration < 500 ? '✅ Good' : duration < 1000 ? '⚠️ OK' : '❌ Slow'}\n`);
    } catch (error) {
      console.log(`❌ ${test.name}: Failed - ${error.message}\n`);
    }
  }
}

/**
 * Run all tests
 */
async function runAllTests() {
  console.log('🚀 OpenVine Analytics Engine Integration Tests (Simplified)');
  console.log('=' .repeat(50));
  console.log(`Account: ${ACCOUNT_ID}`);
  console.log(`Dataset: nostrvine_video_views`);
  console.log(`Time: ${new Date().toISOString()}\n`);

  await testBasicAggregation();
  await testViralScore();
  await testTimeAnalytics();
  await testCreatorAnalytics();
  await testPlatformMetrics();
  await testHashtagAnalysis();
  await testQueryPerformance();

  console.log('\n✨ All tests completed!');
}

// Run tests
runAllTests().catch(console.error);