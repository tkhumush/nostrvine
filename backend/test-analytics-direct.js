#!/usr/bin/env node
// ABOUTME: Test Analytics Engine with different API approaches
// ABOUTME: Diagnose the exact API endpoint and format needed

const ACCOUNT_ID = 'ea14882f4b5d0270ffc376ca39229a84';
const API_TOKEN = 'Qnh5CVxAcAldbePkdpr--7BJUW4seif_N5HSqIvF';

async function testAnalytics() {
  console.log('🔍 Testing Analytics Engine access...\n');

  // First, let's check what we can access
  console.log('1️⃣ Testing account access levels...');
  
  const endpoints = [
    '/accounts/' + ACCOUNT_ID,
    '/accounts/' + ACCOUNT_ID + '/analytics',
    '/zones',
    '/accounts/' + ACCOUNT_ID + '/workers/analytics_engine/datasets',
    '/accounts/' + ACCOUNT_ID + '/workers/analytics-engine/datasets',
    '/accounts/' + ACCOUNT_ID + '/rum/site_info',
    '/graphql'
  ];

  for (const endpoint of endpoints) {
    try {
      const response = await fetch(`https://api.cloudflare.com/client/v4${endpoint}`, {
        headers: {
          'Authorization': `Bearer ${API_TOKEN}`,
          'Content-Type': 'application/json'
        }
      });
      console.log(`   ${endpoint}: ${response.status} ${response.statusText}`);
    } catch (error) {
      console.log(`   ${endpoint}: ERROR - ${error.message}`);
    }
  }

  // Test GraphQL for Analytics Engine
  console.log('\n2️⃣ Testing GraphQL Analytics Engine query...');
  const graphqlQuery = {
    query: `
      query {
        viewer {
          accounts(filter: {accountTag: "${ACCOUNT_ID}"}) {
            analyticsEngineDatasets {
              id
              name
            }
          }
        }
      }
    `
  };

  try {
    const graphqlResponse = await fetch('https://api.cloudflare.com/client/v4/graphql', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${API_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(graphqlQuery)
    });
    
    console.log(`   GraphQL: ${graphqlResponse.status}`);
    if (graphqlResponse.ok) {
      const data = await graphqlResponse.json();
      console.log('   Response:', JSON.stringify(data, null, 2));
    } else {
      const error = await graphqlResponse.text();
      console.log('   Error:', error);
    }
  } catch (error) {
    console.log('   GraphQL Error:', error.message);
  }

  // Check if we're using the wrong dataset name
  console.log('\n3️⃣ Checking Workers Analytics Engine binding...');
  console.log('   From wrangler.jsonc:');
  console.log('   - Binding: VIDEO_ANALYTICS');
  console.log('   - Dataset: nostrvine_video_views');
  console.log('   Note: Analytics Engine SQL queries might not be available yet');
  console.log('   Workers Analytics Engine is write-only currently\n');

  console.log('4️⃣ Checking alternative: Workers Analytics API...');
  const workersAnalyticsEndpoint = `/accounts/${ACCOUNT_ID}/analytics_engine/sql`;
  
  try {
    // Try the documented Analytics Engine SQL endpoint
    const sqlResponse = await fetch(`https://api.cloudflare.com/client/v4${workersAnalyticsEndpoint}`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${API_TOKEN}`,
        'Content-Type': 'application/sql'  // Try different content type
      },
      body: 'SELECT 1'
    });
    
    console.log(`   SQL endpoint: ${sqlResponse.status} ${sqlResponse.statusText}`);
    const responseText = await sqlResponse.text();
    console.log(`   Response: ${responseText.substring(0, 200)}`);
  } catch (error) {
    console.log(`   SQL Error: ${error.message}`);
  }

  console.log('\n5️⃣ Important findings:');
  console.log('   - Analytics Engine is currently WRITE-ONLY from Workers');
  console.log('   - SQL queries are not yet available through the API');
  console.log('   - The fallback KV storage is the correct approach for now');
  console.log('   - Cloudflare may add SQL query support in the future\n');
}

testAnalytics().catch(console.error);