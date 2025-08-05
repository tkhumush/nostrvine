#!/usr/bin/env node
// ABOUTME: Debug script to check which trending videos exist and verify video IDs
// ABOUTME: Helps diagnose relay synchronization issues

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

async function checkTrendingVideos() {
  console.log('🔍 Checking Trending Videos in Analytics Engine');
  console.log('=' .repeat(50));

  // Get trending videos (simplified for Analytics Engine limitations)
  const query = `
    SELECT
      blob1 AS videoId,
      SUM(double1) AS views,
      COUNT(DISTINCT blob2) AS uniqueViewers,
      AVG(double4) AS completionRate
    FROM nostrvine_video_views
    WHERE blob5 IN ('view_end', 'view_start')
      AND toDateTime(double8/1000) >= now() - INTERVAL '24' HOUR
    GROUP BY videoId
    ORDER BY views DESC
    LIMIT 20
  `;

  try {
    const results = await executeQuery(query);
    console.log(`\n✅ Found ${results.length} trending videos in last 24 hours:\n`);
    
    const videoIds = [];
    results.forEach((video, i) => {
      console.log(`${i + 1}. Video ID: ${video.videoId}`);
      console.log(`   Views: ${video.views}`);
      console.log(`   Unique viewers: ${video.uniqueViewers}`);
      console.log(`   Completion: ${(parseFloat(video.completionRate) * 100).toFixed(1)}%`);
      console.log('');
      
      videoIds.push(video.videoId);
    });
    
    // Check video ID format
    console.log('\n📋 Video ID Analysis:');
    console.log('-'.repeat(50));
    
    const hexPattern = /^[0-9a-f]{64}$/i;
    const validHex = videoIds.filter(id => hexPattern.test(id));
    const invalidIds = videoIds.filter(id => !hexPattern.test(id));
    
    console.log(`Valid Nostr event IDs (64-char hex): ${validHex.length}`);
    console.log(`Invalid IDs: ${invalidIds.length}`);
    
    if (invalidIds.length > 0) {
      console.log('\n⚠️ Invalid video IDs found:');
      invalidIds.forEach(id => {
        console.log(`  - ${id} (length: ${id.length})`);
      });
    }
    
    // Sample video IDs for relay checking
    console.log('\n🔗 Sample video IDs for relay verification:');
    console.log('Use these with a Nostr client to check if they exist on relay3.openvine.co:');
    validHex.slice(0, 5).forEach(id => {
      console.log(`  ${id}`);
    });
    
    // Note: Can't get creator info due to Analytics Engine limitations
    
    // Check event distribution over time
    const hourlyQuery = `
      SELECT
        toHour(toDateTime(double8/1000)) AS hour,
        COUNT() AS events,
        COUNT(DISTINCT blob1) AS uniqueVideos
      FROM nostrvine_video_views
      WHERE toDateTime(double8/1000) >= now() - INTERVAL '24' HOUR
      GROUP BY hour
      ORDER BY hour DESC
      LIMIT 24
    `;
    
    console.log('\n📊 Event Distribution (Last 24 Hours):');
    const hourlyResults = await executeQuery(hourlyQuery);
    let totalEvents = 0;
    let totalUniqueVideos = new Set();
    
    hourlyResults.forEach(row => {
      totalEvents += parseInt(row.events);
      console.log(`  Hour ${row.hour}: ${row.events} events, ${row.uniqueVideos} unique videos`);
    });
    
    console.log(`\n📈 Summary:`);
    console.log(`  Total events in 24h: ${totalEvents}`);
    console.log(`  Trending videos tracked: ${results.length}`);
    console.log(`  Valid Nostr event IDs: ${validHex.length}/${videoIds.length}`);
    
    if (validHex.length === 0) {
      console.log('\n🚨 CRITICAL: No valid Nostr event IDs found!');
      console.log('This means Analytics Engine is tracking non-Nostr IDs.');
      console.log('Check the mobile app video ID generation.');
    } else if (validHex.length < videoIds.length / 2) {
      console.log('\n⚠️ WARNING: Less than 50% of video IDs are valid Nostr events.');
      console.log('Some analytics may be tracking test or invalid data.');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

checkTrendingVideos().catch(console.error);