/**
 * Manual test for verification rate limiting
 * Run this with: NODE_ENV=development npx tsx test/rate-limit-verification.test.ts
 */

const API_BASE = 'http://localhost:3001';

async function testSendRateLimit() {
  console.log('\n=== Testing /api/verification/send Rate Limiting ===');
  console.log('Limit: 3 requests per 15 minutes per IP\n');

  const phoneNumber = '+15555551234'; // Test phone number

  for (let i = 1; i <= 5; i++) {
    console.log(`Request ${i}:`);
    try {
      const response = await fetch(`${API_BASE}/api/verification/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phoneNumber }),
      });

      const data = await response.json();
      const rateLimitRemaining = response.headers.get('RateLimit-Remaining');
      const rateLimitReset = response.headers.get('RateLimit-Reset');

      console.log(`  Status: ${response.status}`);
      console.log(`  Remaining: ${rateLimitRemaining}`);
      console.log(`  Reset: ${new Date(Number(rateLimitReset) * 1000).toLocaleTimeString()}`);

      if (response.status === 429) {
        console.log(`  ✓ Rate limit triggered! Error: ${data.error}`);
      } else if (response.status === 200) {
        console.log(`  ✓ Request succeeded`);
      } else {
        console.log(`  Response: ${JSON.stringify(data)}`);
      }
    } catch (error: any) {
      console.log(`  ✗ Error: ${error.message}`);
    }
    console.log('');
  }
}

async function testVerifyRateLimit() {
  console.log('\n=== Testing /api/verification/verify Rate Limiting ===');
  console.log('Limit: 5 requests per 15 minutes per IP\n');

  const phoneNumber = '+15555551234';
  const code = '123456';

  for (let i = 1; i <= 7; i++) {
    console.log(`Request ${i}:`);
    try {
      const response = await fetch(`${API_BASE}/api/verification/verify`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phoneNumber, code }),
      });

      const data = await response.json();
      const rateLimitRemaining = response.headers.get('RateLimit-Remaining');
      const rateLimitReset = response.headers.get('RateLimit-Reset');

      console.log(`  Status: ${response.status}`);
      console.log(`  Remaining: ${rateLimitRemaining}`);
      console.log(`  Reset: ${new Date(Number(rateLimitReset) * 1000).toLocaleTimeString()}`);

      if (response.status === 429) {
        console.log(`  ✓ Rate limit triggered! Error: ${data.error}`);
      } else if (response.status === 200 || response.status === 400) {
        console.log(`  ✓ Request processed (valid/invalid code)`);
      } else {
        console.log(`  Response: ${JSON.stringify(data)}`);
      }
    } catch (error: any) {
      console.log(`  ✗ Error: ${error.message}`);
    }
    console.log('');
  }
}

async function runTests() {
  console.log('Starting rate limit tests...');
  console.log('Make sure the server is running on http://localhost:3001');
  console.log('\nNote: These tests will actually trigger rate limits!');
  console.log('Wait 15 minutes between test runs or restart the server.\n');

  await testSendRateLimit();
  await testVerifyRateLimit();

  console.log('\n=== Tests Complete ===');
  console.log('\nExpected behavior:');
  console.log('- /send: First 3 requests succeed, 4th and 5th return 429');
  console.log('- /verify: First 5 requests process, 6th and 7th return 429');
  console.log('\nRate limits reset after 15 minutes or server restart.');
}

runTests().catch(console.error);
