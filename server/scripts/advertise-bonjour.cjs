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
const PORT = parseInt(process.env.PORT || '3010', 10)
const SERVICE_TYPE = 'makeready'

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

// Publish the service
function advertise() {
  const hostname = os.hostname()
  const ips = getLocalIPs()

  console.log('')
  console.log('📡 Advertising MakeReady development server via Bonjour...')
  console.log('')
  console.log(`   Service type: _${SERVICE_TYPE}._tcp`)
  console.log(`   Port: ${PORT}`)
  console.log(`   Hostname: ${hostname}`)
  console.log('')
  console.log('   Network interfaces:')
  for (const ip of ips) {
    console.log(`     ${ip.name}: http://${ip.address}:${PORT}`)
  }
  console.log('')

  const service = bonjour.publish({
    name: `MakeReady Dev (${hostname})`,
    type: SERVICE_TYPE,
    port: PORT,
    txt: {
      version: '1.0',
      hostname: hostname,
      // Include IPs in TXT record for debugging
      ips: ips.map((ip) => ip.address).join(','),
    },
  })

  service.on('up', () => {
    console.log('✅ Bonjour service is now advertised on the local network')
    console.log('')
    console.log('   iOS devices running MakeReady from Xcode will auto-discover this server.')
    console.log('')
  })

  service.on('error', (err) => {
    console.error('❌ Bonjour advertisement error:', err)
  })

  // Handle graceful shutdown
  process.on('SIGINT', () => {
    console.log('')
    console.log('🛑 Stopping Bonjour advertisement...')
    service.stop(() => {
      bonjour.destroy()
      process.exit(0)
    })
  })

  process.on('SIGTERM', () => {
    service.stop(() => {
      bonjour.destroy()
      process.exit(0)
    })
  })
}

advertise()
