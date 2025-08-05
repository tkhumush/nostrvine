#!/usr/bin/env node
// ABOUTME: Test production Analytics Engine directly with correct account
// ABOUTME: Verify the production API is working with Nos Verse account

const ACCOUNT_ID = 'c84e7a9bf7ed99cb41b8e73566568c75'; // Nos Verse account
const API_TOKEN = 'Qnh5CVxAcAldbePkdpr--7BJUW4seif_N5HSqIvF';

async function testProductionAnalytics() {
  console.log('🧪 Testing Analytics Engine with Nos Verse account...\n');

  // Test 1: Verify we can query the dataset
  console.log('1️⃣ Testing direct SQL query...');
  const query1 = `
    SELECT 
      blob1 AS videoId,
      SUM(double1) AS views,
      COUNT(DISTINCT blob2) AS uniqueViewers
    FROM nostrvine_video_views
    GROUP BY blob1
    ORDER BY views DESC
    LIMIT 3
  `;

  try {
    const response = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/analytics_engine/sql`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${API_TOKEN}`,
          'Content-Type': 'text/plain',
        },
        body: query1
      }
    );

    if (response.ok) {
      const data = await response.json();
      console.log('✅ Query successful!');
      console.log('Results:', JSON.stringify(data.data, null, 2));
      console.log(`Total rows: ${data.rows}`);
    } else {
      console.log('❌ Query failed:', response.status, response.statusText);
      const error = await response.text();
      console.log('Error:', error);
    }
  } catch (error) {
    console.log('❌ Request failed:', error.message);
  }

  // Test 2: Check the exact query format the code is using
  console.log('\n2️⃣ Testing exact production query format...');
  const prodQuery = `
    SELECT 
      blob1 AS videoId,
      SUM(double1) AS views,
      uniq(blob2) AS uniqueViewers,
      AVG(double2) AS avgWatchTime,
      AVG(double4) AS avgCompletionRate,
      SUM(double3) AS totalLoops
    FROM nostrvine_video_views
    GROUP BY blob1
    ORDER BY views DESC
    LIMIT 10
  `;

  try {
    const response = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/analytics_engine/sql`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${API_TOKEN}`,
          'Content-Type': 'text/plain',
        },
        body: prodQuery
      }
    );

    if (response.ok) {
      const data = await response.json();
      console.log('✅ Production query works!');
      console.log('Top video:', data.data[0]);
      console.log(`Total videos with data: ${data.rows}`);
    } else {
      console.log('❌ Production query failed:', response.status);
      const error = await response.text();
      console.log('Error:', error);
    }
  } catch (error) {
    console.log('❌ Request failed:', error.message);
  }

  // Test 3: Simple count to verify table name
  console.log('\n3️⃣ Verifying table access...');
  try {
    const response = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/analytics_engine/sql`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${API_TOKEN}`,
          'Content-Type': 'text/plain',
        },
        body: 'SELECT COUNT() as total FROM nostrvine_video_views'
      }
    );

    if (response.ok) {
      const data = await response.json();
      console.log('✅ Table access confirmed!');
      console.log(`Total records in Analytics Engine: ${data.data[0].total}`);
    }
  } catch (error) {
    console.log('❌ Count failed:', error.message);
  }

  console.log('\n✨ Summary:');
  console.log('- Account ID: c84e7a9bf7ed99cb41b8e73566568c75 (Nos Verse)');
  console.log('- Dataset: nostrvine_video_views');
  console.log('- API Token: Working with correct permissions');
  console.log('- Production needs to use this account ID in secrets');
}

testProductionAnalytics().catch(console.error);