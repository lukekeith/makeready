/**
 * Embeddings Service
 *
 * Local in-process text embeddings via @huggingface/transformers (ONNX).
 * Used for Bible concept search: verses are embedded once (embed-bible.ts
 * script) and queries are embedded at search time, compared with pgvector.
 *
 * Model: bge-small-en-v1.5 (384 dims, q8 quantized, ~34MB).
 * - Queries MUST be prefixed (bge is an asymmetric retrieval model) and
 *   passages must NOT be — both encapsulated here, never by callers.
 * - bge uses CLS pooling + L2 normalization, not mean pooling.
 * - Backfill and query encoding must use the same weights/dtype so vectors
 *   are comparable.
 *
 * Env:
 * - EMBEDDINGS_ENABLED   set to 'false' to disable semantic search (falls back to API.Bible)
 * - EMBEDDINGS_DEVICE    onnxruntime execution provider: 'cpu' (default), 'coreml', 'webgpu'.
 *                        Requires glibc (node:*-slim images, not alpine) — onnxruntime-node has no musl build.
 * - HF_CACHE_DIR         model weight cache directory (baked into Docker image at build)
 */

import type { FeatureExtractionPipeline } from '@huggingface/transformers'

export const EMBEDDING_MODEL = 'Xenova/bge-small-en-v1.5'
export const EMBEDDING_DIMS = 384

const QUERY_PREFIX = 'Represent this sentence for searching relevant passages: '

let extractorPromise: Promise<FeatureExtractionPipeline> | null = null

export function isEmbeddingsEnabled(): boolean {
  return process.env.EMBEDDINGS_ENABLED !== 'false'
}

/**
 * Lazy singleton — the model (~34MB weights, ~150-250MB RSS loaded) is only
 * pulled into memory on first use so server boot and /health are unaffected.
 */
function getExtractor(): Promise<FeatureExtractionPipeline> {
  if (!extractorPromise) {
    extractorPromise = (async () => {
      const { pipeline, env } = await import('@huggingface/transformers')
      if (process.env.HF_CACHE_DIR) {
        env.cacheDir = process.env.HF_CACHE_DIR
      }
      const device = (process.env.EMBEDDINGS_DEVICE ?? 'cpu') as 'cpu'
      return pipeline('feature-extraction', EMBEDDING_MODEL, {
        dtype: 'q8',
        device,
      })
    })()
    // Allow retry on a failed load (e.g. transient download error)
    extractorPromise.catch(() => {
      extractorPromise = null
    })
  }
  return extractorPromise
}

async function embed(texts: string[]): Promise<number[][]> {
  const extractor = await getExtractor()
  const output = await extractor(texts, { pooling: 'cls', normalize: true })
  const flat = output.data as Float32Array
  const vectors: number[][] = []
  for (let i = 0; i < texts.length; i++) {
    vectors.push(Array.from(flat.subarray(i * EMBEDDING_DIMS, (i + 1) * EMBEDDING_DIMS)))
  }
  return vectors
}

/** Embed a search query (bge query prefix applied). */
export async function embedQuery(text: string): Promise<number[]> {
  const [vector] = await embed([QUERY_PREFIX + text])
  return vector
}

/** Embed several search queries in one model pass (bge query prefix applied). */
export async function embedQueries(texts: string[]): Promise<number[][]> {
  if (texts.length === 0) return []
  return embed(texts.map((t) => QUERY_PREFIX + t))
}

/** Embed passage texts for indexing (no prefix). */
export async function embedPassages(texts: string[]): Promise<number[][]> {
  if (texts.length === 0) return []
  return embed(texts)
}
