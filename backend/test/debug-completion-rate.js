#!/usr/bin/env node
// ABOUTME: Debug script to investigate completion rate issue
// ABOUTME: Checks what's being stored in double4 (completion_rate field)

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

async function debugCompletionRate() {
  console.log('🔍 Debugging Completion Rate Issue');
  console.log('=' .repeat(50));

  // Check raw values in double4
  console.log('\n1️⃣ Checking raw double4 values (completion_rate field):');
  const rawQuery = `
    SELECT
      blob1 AS video_id,
      blob5 AS event_type,
      double4 AS completion_rate_raw,
      double2 AS watch_duration_ms,
      double5 AS total_duration_ms,
      double1 AS view_count,
      double6 AS is_new_view,
      double7 AS is_completed_view
    FROM nostrvine_video_views
    WHERE blob5 IN ('view_end', 'view_start', 'view')
    LIMIT 20
  `;

  try {
    const results = await executeQuery(rawQuery);
    console.log(`\nSample of ${results.length} events:\n`);
    
    results.forEach((row, i) => {
      console.log(`Event ${i + 1}:`);
      console.log(`  Video: ${row.video_id.substring(0, 16)}...`);
      console.log(`  Event Type: ${row.event_type}`);
      console.log(`  Completion Rate (double4): ${row.completion_rate_raw}`);
      console.log(`  Watch Duration: ${row.watch_duration_ms}ms`);
      console.log(`  Total Duration: ${row.total_duration_ms}ms`);
      console.log(`  View Count: ${row.view_count}`);
      console.log(`  Is New View: ${row.is_new_view}`);
      console.log(`  Is Completed: ${row.is_completed_view}`);
      
      // Calculate what completion rate should be
      if (row.watch_duration_ms && row.total_duration_ms && parseFloat(row.total_duration_ms) > 0) {
        const expectedCompletion = parseFloat(row.watch_duration_ms) / parseFloat(row.total_duration_ms);
        console.log(`  Expected Completion: ${(expectedCompletion * 100).toFixed(1)}%`);
      }
      console.log('');
    });
  } catch (error) {
    console.error('❌ Error:', error.message);
  }

  // Check distribution of completion rates
  console.log('\n2️⃣ Distribution of completion_rate values:');
  const distributionQuery = `
    SELECT
      double4 AS completion_rate,
      COUNT() AS count,
      blob5 AS event_type
    FROM nostrvine_video_views
    WHERE blob5 IN ('view_end', 'view_start', 'view')
    GROUP BY completion_rate, event_type
    ORDER BY count DESC
    LIMIT 20
  `;

  try {
    const results = await executeQuery(distributionQuery);
    console.log('\nCompletion rate distribution:\n');
    
    const grouped = {};
    results.forEach(row => {
      const rate = parseFloat(row.completion_rate);
      const eventType = row.event_type;
      if (!grouped[eventType]) grouped[eventType] = [];
      grouped[eventType].push({ rate, count: parseInt(row.count) });
    });

    Object.keys(grouped).forEach(eventType => {
      console.log(`Event Type: ${eventType}`);
      grouped[eventType].slice(0, 5).forEach(item => {
        console.log(`  Rate: ${item.rate} → Count: ${item.count}`);
      });
      console.log('');
    });
  } catch (error) {
    console.error('❌ Error:', error.message);
  }

  // Check if we're getting watch duration data
  console.log('\n3️⃣ Watch duration analysis:');
  const durationQuery = `
    SELECT
      blob5 AS event_type,
      COUNT() AS total_events,
      SUM(CASE WHEN double2 > 0 THEN 1 ELSE 0 END) AS events_with_duration,
      AVG(double2) AS avg_watch_duration,
      MIN(double2) AS min_duration,
      MAX(double2) AS max_duration,
      AVG(double5) AS avg_video_duration
    FROM nostrvine_video_views
    WHERE blob5 IN ('view_end', 'view_start', 'view')
    GROUP BY event_type
  `;

  try {
    const results = await executeQuery(durationQuery);
    console.log('\nWatch duration by event type:\n');
    
    results.forEach(row => {
      console.log(`Event Type: ${row.event_type}`);
      console.log(`  Total events: ${row.total_events}`);
      console.log(`  Events with duration > 0: ${row.events_with_duration}`);
      console.log(`  Avg watch duration: ${row.avg_watch_duration}ms`);
      console.log(`  Min duration: ${row.min_duration}ms`);
      console.log(`  Max duration: ${row.max_duration}ms`);
      console.log(`  Avg video duration: ${row.avg_video_duration}ms`);
      console.log('');
    });
  } catch (error) {
    console.error('❌ Error:', error.message);
  }

  // Check a specific video's events
  console.log('\n4️⃣ Tracking a specific video\'s events:');
  const specificVideoQuery = `
    SELECT
      blob1 AS video_id,
      COUNT() AS event_count,
      SUM(CASE WHEN blob5 = 'view_start' THEN 1 ELSE 0 END) AS starts,
      SUM(CASE WHEN blob5 = 'view_end' THEN 1 ELSE 0 END) AS ends,
      AVG(double4) AS avg_completion,
      AVG(double2) AS avg_watch_time,
      MAX(double5) AS video_duration
    FROM nostrvine_video_views
    GROUP BY video_id
    HAVING event_count > 10
    ORDER BY event_count DESC
    LIMIT 5
  `;

  try {
    const results = await executeQuery(specificVideoQuery);
    console.log('\nVideos with most events:\n');
    
    results.forEach(row => {
      console.log(`Video: ${row.video_id.substring(0, 20)}...`);
      console.log(`  Total events: ${row.event_count}`);
      console.log(`  Starts: ${row.starts}`);
      console.log(`  Ends: ${row.ends}`);
      console.log(`  Avg completion: ${(parseFloat(row.avg_completion) * 100).toFixed(2)}%`);
      console.log(`  Avg watch time: ${row.avg_watch_time}ms`);
      console.log(`  Video duration: ${row.video_duration}ms`);
      
      if (row.starts > 0 && row.ends > 0) {
        const actualCompletionRate = (row.ends / row.starts) * 100;
        console.log(`  Actual completion rate (ends/starts): ${actualCompletionRate.toFixed(1)}%`);
      }
      console.log('');
    });
  } catch (error) {
    console.error('❌ Error:', error.message);
  }

  console.log('\n🎯 Summary:');
  console.log('The issue appears to be that completion_rate (double4) is not being set correctly');
  console.log('when events are tracked. The mobile app may be sending 0 or not calculating it.');
  console.log('For 6-second videos, we\'d expect 80-95% completion rates.');
}

debugCompletionRate().catch(console.error);