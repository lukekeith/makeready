/**
 * Prefetch Local Models
 *
 * Downloads the embedding AND reranker model weights into HF_CACHE_DIR and runs
 * smoke tests. Used:
 * - in the Docker build (bakes weights into the image so Railway never
 *   downloads from HuggingFace at runtime — the filesystem is ephemeral)
 * - locally as a sanity check: npm run model:prefetch
 */

import { embedQuery, EMBEDDING_DIMS, EMBEDDING_MODEL } from '../services/embeddings.js'
import { rerank } from '../services/reranker.js'

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

  console.log(`OK embeddings: ${vector.length} dims, norm=${norm.toFixed(4)}, ${Date.now() - started}ms`)

  // Reranker: bake the cross-encoder in too, and assert it ranks an obviously
  // relevant doc above an irrelevant one (guards against a bad ONNX export
  // silently inverting ranking, which we hit with bge-reranker-base).
  const rerankStart = Date.now()
  const scores = await rerank('the parable of the prodigal son', [
    'A certain man had two sons. The younger son traveled into a far country and wasted his property with riotous living.',
    'In the beginning God created the heavens and the earth.',
  ])
  if (!scores) throw new Error('Reranker returned null (disabled or failed to load)')
  if (scores[0] <= scores[1]) {
    throw new Error(`Reranker ranking looks inverted: relevant=${scores[0].toFixed(2)} <= irrelevant=${scores[1].toFixed(2)}`)
  }
  console.log(`OK reranker: relevant=${scores[0].toFixed(2)} > irrelevant=${scores[1].toFixed(2)}, ${Date.now() - rerankStart}ms`)
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Prefetch failed:', err)
    process.exit(1)
  })
