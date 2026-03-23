/**
 * RuVector Bootstrap — Patches global.fetch to serve local ONNX model files
 * and provides initialization helpers for the full RuVector stack.
 *
 * Usage:
 *   import { initRuVector } from './scripts/ruvector-bootstrap.mjs';
 *   const { engine, embedder, router, graph } = await initRuVector();
 *
 * Or as a preload:
 *   node --import ./scripts/ruvector-bootstrap.mjs your-app.js
 */

import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

const MODEL_DIR = join(homedir(), '.ruvector', 'models');
const MODEL_FILES = {
  'model.onnx': join(MODEL_DIR, 'all-MiniLM-L6-v2-model.onnx'),
  'tokenizer.json': join(MODEL_DIR, 'all-MiniLM-L6-v2-tokenizer.json'),
};

// Patch global.fetch to intercept HuggingFace model URLs and serve local files
const originalFetch = globalThis.fetch;
globalThis.fetch = async function patchedFetch(url, options) {
  const urlStr = typeof url === 'string' ? url : url?.toString?.() ?? '';
  if (urlStr.includes('huggingface.co') && urlStr.includes('all-MiniLM-L6-v2')) {
    for (const [filename, localPath] of Object.entries(MODEL_FILES)) {
      if (urlStr.includes(filename) && existsSync(localPath)) {
        const data = await readFile(localPath);
        const contentType = filename.endsWith('.json') ? 'application/json' : 'application/octet-stream';
        return new Response(data, {
          status: 200,
          headers: { 'content-type': contentType, 'content-length': String(data.length) },
        });
      }
    }
  }
  return originalFetch(url, options);
};

/**
 * Initialize the full RuVector stack with ONNX semantic embeddings.
 *
 * @param {object} opts
 * @param {boolean} opts.enableOnnx - Enable ONNX embeddings (default: true)
 * @param {number} opts.embeddingDim - Embedding dimensions (default: 384 for MiniLM)
 * @param {string} opts.storagePath - VectorDB persistence path
 * @returns {Promise<{engine, embedder, router, graph, db}>}
 */
export async function initRuVector(opts = {}) {
  const {
    enableOnnx = true,
    embeddingDim = 384,
    storagePath,
  } = opts;

  const ruvector = await import('ruvector');
  const result = {};

  // 1. VectorDB
  result.db = new ruvector.VectorDB({
    dimensions: embeddingDim,
    storagePath,
    hnswConfig: { m: 16, efConstruction: 200, efSearch: 50 },
  });

  // 2. ONNX Embedder
  if (enableOnnx) {
    try {
      const emb = new ruvector.OnnxEmbedder();
      await emb.init();
      // OnnxEmbedder exposes .dimensions property, not getDimensions()
      const dims = emb.dimensions || emb.getDimensions?.() || embeddingDim;
      result.embedder = emb;
      console.log(`[ruvector] ONNX embedder ready (${dims}d)`);
    } catch (e) {
      console.warn(`[ruvector] ONNX embedder failed: ${e.message}, falling back to n-gram`);
      result.embedder = null;
    }
  }

  // 3. IntelligenceEngine
  try {
    result.engine = ruvector.default?.createIntelligenceEngine
      ? ruvector.default.createIntelligenceEngine({ enableOnnx, embeddingDim })
      : new ruvector.IntelligenceEngine({ enableOnnx, embeddingDim });
    if (result.engine.initOnnx) await result.engine.initOnnx();
    console.log('[ruvector] IntelligenceEngine ready');
  } catch (e) {
    console.warn(`[ruvector] IntelligenceEngine init failed: ${e.message}`);
  }

  // 4. SemanticRouter (use native directly, bypass broken wrapper)
  try {
    const routerMod = await import('@ruvector/router');
    const RouterClass = routerMod.SemanticRouter || routerMod.default?.SemanticRouter;
    if (RouterClass) {
      result.router = new RouterClass({ dimension: embeddingDim, threshold: 0.5 });
      // Wire ONNX embedder for async intent matching
      if (result.embedder && result.router.setEmbedder) {
        result.router.setEmbedder(async (text) => {
          const vec = await result.embedder.embed(text);
          return new Float32Array(vec);
        });
      }
      console.log('[ruvector] SemanticRouter ready (native)');
    }
  } catch (e) {
    console.warn(`[ruvector] SemanticRouter init failed: ${e.message}`);
  }

  // 5. CodeGraph (use native directly)
  try {
    const graphMod = await import('@ruvector/graph-node');
    const GraphClass = graphMod.Graph || graphMod.default?.Graph || graphMod.default;
    if (GraphClass) {
      result.graph = typeof GraphClass === 'function' ? new GraphClass() : GraphClass;
      console.log('[ruvector] CodeGraph ready (native)');
    }
  } catch (e) {
    console.warn(`[ruvector] CodeGraph init failed: ${e.message}`);
  }

  // 6. SONA — native SonaEngine takes dimension as a single number
  try {
    if (ruvector.SonaEngine && typeof ruvector.SonaEngine === 'function') {
      result.sona = new ruvector.SonaEngine(embeddingDim);
      console.log('[ruvector] SONA ready');
    }
  } catch (e) {
    console.warn(`[ruvector] SONA init failed: ${e.message}`);
  }

  // 7. Helper: embed text using best available method
  result.embed = async (text) => {
    if (result.embedder) {
      return await result.embedder.embed(text);
    }
    // Fallback to engine's async embed
    if (result.engine?.embedAsync) {
      return await result.engine.embedAsync(text);
    }
    // Last resort: n-gram
    const svc = new ruvector.EmbeddingService();
    const [vec] = await svc.embed([text]);
    return vec;
  };

  return result;
}

// Export model check utility
export function checkModelsDownloaded() {
  const missing = [];
  for (const [name, path] of Object.entries(MODEL_FILES)) {
    if (!existsSync(path)) missing.push(name);
  }
  return { ok: missing.length === 0, missing, modelDir: MODEL_DIR };
}
