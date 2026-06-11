/**
 * Prefetch Embedding Model
 *
 * Downloads the embedding model weights into HF_CACHE_DIR and runs a smoke
 * test. Used:
 * - in the Docker build (bakes weights into the image so Railway never
 *   downloads from HuggingFace at runtime)
 * - locally as a sanity check: npm run model:prefetch
 */

import { embedQuery, EMBEDDING_DIMS, EMBEDDING_MODEL } from '../services/embeddings.js'

async function main() {
  const started = Date.now()
  console.log(`Prefetching ${EMBEDDING_MODEL} (device=${process.env.EMBEDDINGS_DEVICE ?? 'cpu'}, cache=${process.env.HF_CACHE_DIR ?? 'default'})...`)

  const vector = await embedQuery('warmup test sentence')

  if (vector.length !== EMBEDDING_DIMS) {
    throw new Error(`Expected ${EMBEDDING_DIMS} dims, got ${vector.length}`)
  }
  const norm = Math.sqrt(vector.reduce((s, v) => s + v * v, 0))
  if (Math.abs(norm - 1) > 0.01) {
    throw new Error(`Expected normalized vector, got norm=${norm}`)
  }

  console.log(`OK: ${vector.length} dims, norm=${norm.toFixed(4)}, first values [${vector.slice(0, 3).map(v => v.toFixed(4)).join(', ')}], ${Date.now() - started}ms`)
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Prefetch failed:', err)
    process.exit(1)
  })
