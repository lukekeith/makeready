/**
 * Cross-Encoder Reranker
 *
 * Second-stage precision pass for Bible concept search. The first stage
 * (semantic-search.ts) casts a wide net with bi-encoder cosine + lexical RRF,
 * which is great for recall but orders by fused rank, not true relevance — so
 * a multiply-retrieved mediocre verse can outrank the single obviously-best
 * passage. A cross-encoder reads (query, passage) TOGETHER in one forward pass
 * and scores their actual relevance, fixing the ordering.
 *
 * Local in-process via @huggingface/transformers (ONNX), same as embeddings.ts.
 * Model: ms-marco-MiniLM-L-6-v2 — a small, battle-tested cross-encoder that
 * loads in ~1s and scores correctly. (Xenova/bge-reranker-base was evaluated
 * and rejected: its transformers.js ONNX export ranks relevant docs LAST and
 * takes ~16s to load. MiniLM is both correct and far faster.)
 *
 * Fail-open by contract: any disable flag, load failure, or timeout returns
 * null and the caller keeps the first-stage (RRF) ordering. Reranking must
 * never break or block search.
 *
 * Env:
 * - RERANKER_ENABLED     'false' disables reranking (default on)
 * - RERANKER_MODEL       HF model id (default Xenova/ms-marco-MiniLM-L-6-v2)
 * - RERANKER_DTYPE       onnx weight dtype (default 'fp32'; q8 degrades ranking)
 * - RERANKER_TIMEOUT_MS  budget for one rerank call (default 3500)
 */

import type { PreTrainedModel, PreTrainedTokenizer, DataType } from '@huggingface/transformers'

const RERANKER_MODEL = process.env.RERANKER_MODEL ?? 'Xenova/ms-marco-MiniLM-L-6-v2'
const RERANKER_DTYPE = (process.env.RERANKER_DTYPE ?? 'fp32') as DataType
const TIMEOUT_MS = parseInt(process.env.RERANKER_TIMEOUT_MS ?? '3500', 10)

export function isRerankerEnabled(): boolean {
  return process.env.RERANKER_ENABLED !== 'false'
}

let modelPromise: Promise<{ model: PreTrainedModel; tokenizer: PreTrainedTokenizer }> | null = null

/**
 * Lazy singleton — the cross-encoder (~70MB q8) is only loaded on first rerank
 * so server boot and the bi-encoder path are unaffected. A failed load is
 * retryable (e.g. transient download error).
 */
function getModel() {
  if (!modelPromise) {
    modelPromise = (async () => {
      const { AutoModelForSequenceClassification, AutoTokenizer, env } = await import('@huggingface/transformers')
      if (process.env.HF_CACHE_DIR) env.cacheDir = process.env.HF_CACHE_DIR
      const [model, tokenizer] = await Promise.all([
        AutoModelForSequenceClassification.from_pretrained(RERANKER_MODEL, { dtype: RERANKER_DTYPE }),
        AutoTokenizer.from_pretrained(RERANKER_MODEL),
      ])
      return { model, tokenizer }
    })()
    modelPromise.catch(() => { modelPromise = null })
  }
  return modelPromise
}

/**
 * Score each document's relevance to the query (higher = more relevant). bge
 * cross-encoders emit a single logit per pair; we return the raw logit (order
 * is all the caller needs — no need to sigmoid). Returns null on disable,
 * timeout, or any failure so the caller keeps its existing order.
 */
export async function rerank(query: string, documents: string[]): Promise<number[] | null> {
  if (!isRerankerEnabled() || documents.length === 0) return null
  try {
    return await Promise.race([score(query, documents), timeout()])
  } catch (err) {
    console.error('Rerank failed:', err instanceof Error ? err.message : err)
    return null
  }
}

async function score(query: string, documents: string[]): Promise<number[]> {
  const { model, tokenizer } = await getModel()
  // One pass over all (query, doc) pairs: same query paired with each document.
  const inputs = tokenizer(new Array(documents.length).fill(query), {
    text_pair: documents,
    padding: true,
    truncation: true,
  })
  const { logits } = await model(inputs)
  // logits shape [N, 1] → flat relevance score per document
  return Array.from(logits.data as Float32Array)
}

function timeout(): Promise<never> {
  return new Promise((_, reject) =>
    setTimeout(() => reject(new Error(`rerank timed out after ${TIMEOUT_MS}ms`)), TIMEOUT_MS).unref()
  )
}
