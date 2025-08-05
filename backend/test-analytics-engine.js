#!/usr/bin/env node
// ABOUTME: Direct Analytics Engine test script bypassing fallback
// ABOUTME: Tests SQL API queries against Cloudflare Analytics Engine

const ACCOUNT_ID = 'ea14882f4b5d0270ffc376ca39229a84';
const API_TOKEN = 'Qnh5CVxAcAldbePkdpr--7BJUW4seif_N5HSqIvF';

async function testAnalyticsEngine() {
  console.log('🧪 Testing Analytics Engine SQL API directly...\n');

  // Test 1: Basic API access
  console.log('1️⃣ Testing API access...');
  try {
    const accountResponse = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}`,
      {
        headers: {
          'Authorization': `Bearer ${API_TOKEN}`,
          'Content-Type': 'application/json',
        }
      }
    );
    console.log(`   Account API: ${accountResponse.status} ${accountResponse.statusText}`);
    if (!accountResponse.ok) {
      const error = await accountResponse.text();
      console.log(`   Error: ${error}`);
    } else {
      console.log('   ✅ API access confirmed\n');
    }
  } catch (error) {
    console.log(`   ❌ API access failed: ${error.message}\n`);
  }

  // Test 2: List Analytics Engine datasets
  console.log('2️⃣ Listing Analytics Engine datasets...');
  try {
    const datasetsResponse = await fetch(
      `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/analytics_engine/datasets`,
      {
        headers: {
          'Authorization': `Bearer ${API_TOKEN}`,
          'Content-Type': 'application/json',
        }
      }
    );
    console.log(`   Datasets API: ${datasetsResponse.status} ${datasetsResponse.statusText}`);
    if (datasetsResponse.ok) {
      const data = await datasetsResponse.json();
      console.log(`   Found ${data.result?.length || 0} datasets:`);
      data.result?.forEach(dataset => {
        console.log(`   - ${dataset.name} (${dataset.id})`);
      });
      console.log();
    } else {
      const error = await datasetsResponse.text();
      console.log(`   Error: ${error}\n`);
    }
  } catch (error) {
    console.log(`   ❌ Failed to list datasets: ${error.message}\n`);
  }

  // Test 3: Simple count query
  console.log('3️⃣ Testing simple COUNT query...');
  const countQuery = `SELECT COUNT() as total FROM nostrvine_video_views`;
  await testQuery(countQuery);

  // Test 4: Test with different table name formats
  console.log('4️⃣ Testing different table name formats...');
  const tableNames = [
    'VIDEO_ANALYTICS',
    'nostrvine_video_views', 
    'NOSTRVINE_VIDEO_VIEWS',
    'video_analytics'
  ];
  
  for (const tableName of tableNames) {
    console.log(`   Testing table: ${tableName}`);
    const query = `SELECT COUNT() as total FROM ${tableName}`;
    await testQuery(query, false);
  }

  // Test 5: Complex query (if any table works)
  console.log('\n5️⃣ Testing complex analytics query...');
  const complexQuery = `
    SELECT 
      blob1 AS videoId,
      SUM(double1) AS views,
      COUNT(DISTINCT blob2) AS uniqueViewers
    FROM nostrvine_video_views
    WHERE double8 >= ${Date.now() - 86400000}
    GROUP BY blob1
    ORDER BY views DESC
    LIMIT 5
  `;
  await testQuery(complexQuery);
}

async function testQuery(query, verbose = true) {
  try {
    // Try different API endpoint formats
    const endpoints = [
      `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/analytics_engine/sql`,
      `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/analytics_engine/sql/query`,
      `https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/analytics/sql`
    ];

    for (const endpoint of endpoints) {
      if (verbose) console.log(`   Trying endpoint: ${endpoint}`);
      
      // Try different request formats
      const formats = [
        { 
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${API_TOKEN}`,
            'Content-Type': 'text/plain',
          },
          body: query
        },
        {
          method: 'POST', 
          headers: {
            'Authorization': `Bearer ${API_TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ query })
        },
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${API_TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ sql: query })
        }
      ];

      for (let i = 0; i < formats.length; i++) {
        try {
          const response = await fetch(endpoint, formats[i]);
          
          if (response.ok) {
            const result = await response.json();
            if (verbose) {
              console.log(`   ✅ Query successful with format ${i + 1}!`);
              console.log(`   Result:`, JSON.stringify(result, null, 2));
            }
            return result;
          } else if (verbose && response.status !== 404) {
            const error = await response.text();
            console.log(`   Format ${i + 1}: ${response.status} - ${error.substring(0, 100)}`);
          }
        } catch (error) {
          if (verbose) console.log(`   Format ${i + 1} error: ${error.message}`);
        }
      }
    }
    
    if (verbose) console.log(`   ❌ All query attempts failed\n`);
    return null;
  } catch (error) {
    if (verbose) console.log(`   ❌ Query error: ${error.message}\n`);
    return null;
  }
}

// Run tests
testAnalyticsEngine().catch(console.error);