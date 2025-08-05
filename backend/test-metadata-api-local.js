#!/usr/bin/env node

// Test script for the new metadata API endpoints (local)

const API_BASE = 'http://localhost:8787';

async function testSingleFileMetadata() {
  console.log('\n📋 Testing single file metadata endpoint...');
  
  const fileId = '1751108612675-a475b5f8';
  const url = `${API_BASE}/api/metadata/${fileId}`;
  
  try {
    const response = await fetch(url);
    const data = await response.json();
    
    console.log(`✅ GET ${url}`);
    console.log('Response:', JSON.stringify(data, null, 2));
    
    if (data.sha256) {
      console.log(`\n✅ SHA-256 found: ${data.sha256}`);
    } else {
      console.log('⚠️  No SHA-256 in response');
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

async function testBatchMetadata() {
  console.log('\n📋 Testing batch metadata endpoint...');
  
  const urls = [
    'https://api.openvine.co/media/1751108612675-a475b5f8',
    'https://api.openvine.co/media/1753867006183-7d246e3f',
    'https://api.openvine.co/media/1754311523905-3ed1ba5a'
  ];
  
  try {
    const response = await fetch(`${API_BASE}/api/metadata/batch`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ urls })
    });
    
    const data = await response.json();
    
    console.log(`✅ POST ${API_BASE}/api/metadata/batch`);
    console.log('Request body:', { urls });
    console.log('\nResponse:', JSON.stringify(data, null, 2));
    
    // Count how many have SHA-256
    const withSha256 = Object.values(data).filter(item => item.sha256).length;
    console.log(`\n✅ ${withSha256}/${urls.length} files have SHA-256 hashes`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

async function testBatchWithFileIds() {
  console.log('\n📋 Testing batch metadata with fileIds...');
  
  const fileIds = [
    '1751108612675-a475b5f8',
    '1753867006183-7d246e3f',
    '1754311523905-3ed1ba5a'
  ];
  
  try {
    const response = await fetch(`${API_BASE}/api/metadata/batch`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ fileIds })
    });
    
    const data = await response.json();
    
    console.log(`✅ POST ${API_BASE}/api/metadata/batch`);
    console.log('Request body:', { fileIds });
    console.log('\nResponse:', JSON.stringify(data, null, 2));
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

async function testInvalidFileId() {
  console.log('\n📋 Testing with invalid fileId...');
  
  const fileId = 'invalid-file-id';
  const url = `${API_BASE}/api/metadata/${fileId}`;
  
  try {
    const response = await fetch(url);
    const data = await response.json();
    
    console.log(`✅ GET ${url}`);
    console.log('Response:', JSON.stringify(data, null, 2));
    console.log('Status:', response.status);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

async function runAllTests() {
  console.log('🚀 Starting metadata API tests (LOCAL)...\n');
  
  await testSingleFileMetadata();
  await testBatchMetadata();
  await testBatchWithFileIds();
  await testInvalidFileId();
  
  console.log('\n✅ All tests completed!');
}

// Run tests
runAllTests();