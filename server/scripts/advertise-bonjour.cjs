#!/usr/bin/env node
/**
 * Bonjour/mDNS Service Advertisement
 *
 * Advertises the MakeReady development server on the local network
 * so iOS devices can auto-discover it via Bonjour.
 *
 * Service type: _makeready._tcp
 * Port: 3010 (or PORT env var)
 *
 * Run with: node scripts/advertise-bonjour.cjs
 * Or use: npm run dev:advertise
 */

const bonjour = require('bonjour')()
const os = require('os')

// Default to 3010 to match server/src/index.ts
const API_PORT = parseInt(process.env.PORT || '3010', 10)
const CLIENT_PORT = parseInt(process.env.CLIENT_PORT || '8000', 10)
const API_SERVICE_TYPE = 'makeready'
const CLIENT_SERVICE_TYPE = 'makeready-client'

// Get local IP addresses
function getLocalIPs() {
  const interfaces = os.networkInterfaces()
  const ips = []

  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      // Skip internal (loopback) and non-IPv4 addresses
      if (iface.family === 'IPv4' && !iface.internal) {
        ips.push({ name, address: iface.address })
      }
    }
  }

  return ips
}

// Publish both services
function advertise() {
  const hostname = os.hostname()
  const ips = getLocalIPs()

  console.log('')
  console.log('📡 Advertising MakeReady development servers via Bonjour...')
  console.log('')
  console.log(`   API:    _${API_SERVICE_TYPE}._tcp on port ${API_PORT}`)
  console.log(`   Client: _${CLIENT_SERVICE_TYPE}._tcp on port ${CLIENT_PORT}`)
  console.log(`   Hostname: ${hostname}`)
  console.log('')
  console.log('   Network interfaces:')
  for (const ip of ips) {
    console.log(`     ${ip.name}: API http://${ip.address}:${API_PORT} | Client http://${ip.address}:${CLIENT_PORT}`)
  }
  console.log('')

  const txtRecord = {
    version: '1.0',
    hostname: hostname,
    ips: ips.map((ip) => ip.address).join(','),
  }

  const apiService = bonjour.publish({
    name: `MakeReady API (${hostname})`,
    type: API_SERVICE_TYPE,
    port: API_PORT,
    txt: txtRecord,
  })

  const clientService = bonjour.publish({
    name: `MakeReady Client (${hostname})`,
    type: CLIENT_SERVICE_TYPE,
    port: CLIENT_PORT,
    txt: txtRecord,
  })

  apiService.on('up', () => {
    console.log(`✅ API service advertised (_${API_SERVICE_TYPE}._tcp:${API_PORT})`)
  })

  clientService.on('up', () => {
    console.log(`✅ Client service advertised (_${CLIENT_SERVICE_TYPE}._tcp:${CLIENT_PORT})`)
    console.log('')
    console.log('   iOS devices running MakeReady from Xcode will auto-discover both servers.')
    console.log('')
  })

  apiService.on('error', (err) => {
    console.error('❌ API Bonjour error:', err)
  })

  clientService.on('error', (err) => {
    console.error('❌ Client Bonjour error:', err)
  })

  // Handle graceful shutdown
  function shutdown() {
    console.log('')
    console.log('🛑 Stopping Bonjour advertisements...')
    let stopped = 0
    const done = () => { if (++stopped >= 2) { bonjour.destroy(); process.exit(0) } }
    apiService.stop(done)
    clientService.stop(done)
  }

  process.on('SIGINT', shutdown)
  process.on('SIGTERM', shutdown)
}

advertise()
