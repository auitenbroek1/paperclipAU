# Lessons Learned

Rules discovered through corrections. Review at session start. Update after every mistake.

---

## RuVector

- **DO NOT set `distanceMetric: 'cosine'` explicitly** — crashes the native Rust binding. Use the default (which is cosine).
- **SemanticRouter wrapper (`ruvector` package) is broken** — use `require('@ruvector/router')` directly. The wrapper has wrong param names (`dimensions` vs `dimension`) and wrong method names (`match` vs `route`).
- **SonaEngine constructor takes a single number** — `new SonaEngine(384)`, NOT an options object.
- **IntelligenceEngine.embed() (sync) always falls back to hash** — MUST use `embedAsync()` or the bootstrap's `rv.embed()` for real semantic embeddings.
- **GraphDatabase nodes require `embedding: Float32Array(384)`** — cannot create nodes without vectors. Edges require `from`, `to`, `edgeType`, `description`, `embedding`.
- **ONNX model download fails in Node.js** — use the fetch-patch bootstrap (`scripts/ruvector-bootstrap.mjs`) to serve local model files.
- **ALWAYS use the bootstrap for RuVector** — without it, embeddings are character n-gram (not semantic) and search is useless.

## General

- **Search memory before starting work** — avoids repeating past mistakes and rediscovering known patterns.
- **If an approach isn't working after 2-3 attempts, stop and re-plan** — don't brute-force.
