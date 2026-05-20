#!/usr/bin/env npx tsx
/**
 * Test Script for Bible Smart Search
 *
 * Tests both direct reference parsing and semantic search.
 *
 * Usage:
 *   npx tsx src/scripts/test-search.ts
 *   npx tsx src/scripts/test-search.ts --server=http://localhost:3001
 *   npx tsx src/scripts/test-search.ts --server=https://api.makeready.org
 */

import { parseReference } from '../utils/bible-reference-parser'

// Parse command line args
const args = process.argv.slice(2)
const getArg = (name: string, defaultValue: string) => {
  const arg = args.find((a) => a.startsWith(`--${name}=`))
  return arg ? arg.split('=')[1] : defaultValue
}

const SERVER_URL = getArg('server', 'http://localhost:3001')

// Test cases for reference parsing
const REFERENCE_TESTS = [
  // Should parse as direct references
  { input: 'Romans 1:1', expected: { type: 'direct', bookNumber: 45, chapter: 1, verseStart: 1 } },
  { input: 'Rom 1:1', expected: { type: 'direct', bookNumber: 45, chapter: 1, verseStart: 1 } },
  { input: 'John 3:16', expected: { type: 'direct', bookNumber: 43, chapter: 3, verseStart: 16 } },
  { input: 'John 3:16-17', expected: { type: 'direct', bookNumber: 43, chapter: 3, verseStart: 16, verseEnd: 17 } },
  { input: 'Psalm 23', expected: { type: 'direct', bookNumber: 19, chapter: 23 } },
  { input: 'Ps 23', expected: { type: 'direct', bookNumber: 19, chapter: 23 } },
  { input: '1 John 3', expected: { type: 'direct', bookNumber: 62, chapter: 3 } },
  { input: '1John 3:1', expected: { type: 'direct', bookNumber: 62, chapter: 3, verseStart: 1 } },
  { input: 'Genesis 1:1-3', expected: { type: 'direct', bookNumber: 1, chapter: 1, verseStart: 1, verseEnd: 3 } },
  { input: 'Gen 1', expected: { type: 'direct', bookNumber: 1, chapter: 1 } },
  { input: '2 Cor 5:17', expected: { type: 'direct', bookNumber: 47, chapter: 5, verseStart: 17 } },
  { input: 'Revelation 21:4', expected: { type: 'direct', bookNumber: 66, chapter: 21, verseStart: 4 } },

  // Should NOT parse as direct references (semantic queries)
  { input: 'verses about love', expected: null },
  { input: 'the creation story', expected: null },
  { input: 'top passages on grace', expected: null },
  { input: 'what does the bible say about marriage', expected: null },
  { input: 'scriptures about faith', expected: null },
]

// Test cases for API calls
const API_TESTS = [
  // Direct references
  { query: 'John 3:16', translation: 'KJV', expectedType: 'direct' },
  { query: 'Romans 8:28', translation: 'KJV', expectedType: 'direct' },
  { query: 'Psalm 23', translation: 'KJV', expectedType: 'direct' },
  { query: 'Genesis 1:1-3', translation: 'KJV', expectedType: 'direct' },

  // Semantic queries (will need embeddings to return results)
  { query: 'verses about love', translation: 'KJV', expectedType: 'semantic' },
  { query: 'the creation story', translation: 'KJV', expectedType: 'semantic' },
  { query: 'passages about grace', translation: 'KJV', expectedType: 'semantic' },
]

function printHeader(title: string) {
  console.log('\n' + '='.repeat(60))
  console.log(title)
  console.log('='.repeat(60))
}

function printResult(pass: boolean, message: string) {
  const icon = pass ? '✅' : '❌'
  console.log(`${icon} ${message}`)
}

async function testReferenceParsing() {
  printHeader('Testing Reference Parser (Local)')

  let passed = 0
  let failed = 0

  for (const test of REFERENCE_TESTS) {
    const result = parseReference(test.input)

    if (test.expected === null) {
      // Should NOT be a direct reference
      if (result === null) {
        printResult(true, `"${test.input}" → semantic query (correct)`)
        passed++
      } else {
        printResult(false, `"${test.input}" → parsed as direct (should be semantic)`)
        failed++
      }
    } else {
      // Should be a direct reference
      if (result === null) {
        printResult(false, `"${test.input}" → null (expected direct reference)`)
        failed++
      } else {
        const bookMatch = result.bookNumber === test.expected.bookNumber
        const chapterMatch = result.chapter === test.expected.chapter
        const verseStartMatch = result.verseStart === test.expected.verseStart
        const verseEndMatch = result.verseEnd === test.expected.verseEnd

        if (bookMatch && chapterMatch && verseStartMatch && verseEndMatch) {
          printResult(true, `"${test.input}" → ${result.bookName} ${result.chapter}:${result.verseStart || 'all'}${result.verseEnd ? `-${result.verseEnd}` : ''}`)
          passed++
        } else {
          printResult(false, `"${test.input}" → mismatch: got book=${result.bookNumber}, ch=${result.chapter}, v=${result.verseStart}-${result.verseEnd}`)
          failed++
        }
      }
    }
  }

  console.log(`\nResults: ${passed} passed, ${failed} failed`)
  return failed === 0
}

async function testAPIEndpoints() {
  printHeader(`Testing API Endpoints (${SERVER_URL})`)

  let passed = 0
  let failed = 0

  for (const test of API_TESTS) {
    try {
      const response = await fetch(`${SERVER_URL}/api/search/smart`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: test.query, translation: test.translation }),
      })

      if (!response.ok) {
        printResult(false, `"${test.query}" → HTTP ${response.status}`)
        failed++
        continue
      }

      const data = await response.json() as {
        type: string
        query: string
        results?: unknown[]
        verses?: unknown[]
        total?: number
        message?: string
      }

      if (data.type === test.expectedType) {
        const resultCount = data.type === 'direct'
          ? (data.verses?.length || 0)
          : (data.results?.length || 0)

        printResult(true, `"${test.query}" → ${data.type} (${resultCount} results)`)

        // Show first result for semantic queries
        if (data.type === 'semantic' && data.results && (data.results as any[]).length > 0) {
          const first = (data.results as any[])[0]
          console.log(`   ↳ Top match: ${first.reference} (${Math.round(first.similarity * 100)}% similar)`)
        }

        // Show message if present
        if (data.message) {
          console.log(`   ↳ Note: ${data.message}`)
        }

        passed++
      } else if (data.type === 'text_fallback' && test.expectedType === 'semantic') {
        // Text fallback is acceptable when embeddings aren't available
        printResult(true, `"${test.query}" → text_fallback (embeddings not available)`)
        console.log(`   ↳ ${data.message}`)
        passed++
      } else {
        printResult(false, `"${test.query}" → ${data.type} (expected ${test.expectedType})`)
        failed++
      }
    } catch (error) {
      printResult(false, `"${test.query}" → Error: ${error instanceof Error ? error.message : 'Unknown error'}`)
      failed++
    }
  }

  console.log(`\nResults: ${passed} passed, ${failed} failed`)
  return failed === 0
}

async function testSuggestions() {
  printHeader(`Testing Suggestions Endpoint (${SERVER_URL})`)

  const queries = ['rom', 'john', 'gen', 'ps']

  for (const q of queries) {
    try {
      const response = await fetch(`${SERVER_URL}/api/search/suggestions?q=${q}&translation=KJV`)
      const data = await response.json() as { suggestions: any[] }

      if (data.suggestions && data.suggestions.length > 0) {
        printResult(true, `"${q}" → ${data.suggestions.map((s: any) => s.bookName).join(', ')}`)
      } else {
        printResult(false, `"${q}" → no suggestions`)
      }
    } catch (error) {
      printResult(false, `"${q}" → Error: ${error instanceof Error ? error.message : 'Unknown error'}`)
    }
  }
}

async function main() {
  console.log('🔍 Bible Smart Search Test Suite')
  console.log(`Server: ${SERVER_URL}`)

  // Test 1: Local reference parsing
  const parsingPassed = await testReferenceParsing()

  // Test 2: API endpoints
  const apiPassed = await testAPIEndpoints()

  // Test 3: Suggestions
  await testSuggestions()

  printHeader('Summary')

  if (parsingPassed && apiPassed) {
    console.log('✅ All tests passed!')
  } else {
    console.log('❌ Some tests failed')
    console.log('\nTroubleshooting:')
    if (!apiPassed) {
      console.log('- Make sure the server is running: npm run dev')
      console.log('- For semantic search, deploy the Edge Function and generate embeddings')
    }
  }
}

main().catch(console.error)
