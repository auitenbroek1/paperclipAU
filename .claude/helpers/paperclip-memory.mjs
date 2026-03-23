#!/usr/bin/env node
/**
 * Paperclip Memory System — Native observation capture, session summaries,
 * and progressive disclosure search over RuVector.
 *
 * Replaces claude-mem patterns with zero external dependencies beyond ruvector.
 *
 * Commands:
 *   observe <json>     - Capture a tool-use observation
 *   summarize <json>   - Generate end-of-session summary
 *   search <query>     - Progressive disclosure search (layer 1: index)
 *   timeline <id>      - Context around an observation (layer 2)
 *   details <id,...>   - Full observation details (layer 3)
 *   context            - Auto-inject relevant context for session start
 *   stats              - Memory statistics
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROJECT_ROOT = join(__dirname, '../..');
const MEMORY_DIR = join(PROJECT_ROOT, '.ruvector');
const DB_PATH = join(MEMORY_DIR, 'paperclip-memory.db');
const INDEX_PATH = join(MEMORY_DIR, 'memory-index.json');

// Ensure storage dir
if (!existsSync(MEMORY_DIR)) mkdirSync(MEMORY_DIR, { recursive: true });

// ============================================================================
// Memory Index — lightweight JSON sidecar for metadata (RuVector stores vectors)
// ============================================================================

class MemoryIndex {
  constructor(indexPath) {
    this.path = indexPath;
    this.data = { observations: [], summaries: [], sessions: {} };
    this.load();
  }

  load() {
    if (existsSync(this.path)) {
      try { this.data = JSON.parse(readFileSync(this.path, 'utf-8')); } catch { /* start fresh */ }
    }
  }

  save() {
    writeFileSync(this.path, JSON.stringify(this.data, null, 2));
  }

  addObservation(obs) {
    this.data.observations.push(obs);
    this.save();
  }

  addSummary(summary) {
    this.data.summaries.push(summary);
    this.save();
  }

  getObservation(id) {
    return this.data.observations.find(o => o.id === id) || null;
  }

  getObservations(ids) {
    const idSet = new Set(ids);
    return this.data.observations.filter(o => idSet.has(o.id));
  }

  getTimeline(anchorId, before = 3, after = 3) {
    const idx = this.data.observations.findIndex(o => o.id === anchorId);
    if (idx === -1) return [];
    const start = Math.max(0, idx - before);
    const end = Math.min(this.data.observations.length, idx + after + 1);
    return this.data.observations.slice(start, end);
  }

  getRecentObservations(limit = 20) {
    return this.data.observations.slice(-limit);
  }

  getSessionSummaries(limit = 5) {
    return this.data.summaries.slice(-limit);
  }

  setSession(sessionId, data) {
    this.data.sessions[sessionId] = data;
    this.save();
  }

  stats() {
    return {
      totalObservations: this.data.observations.length,
      totalSummaries: this.data.summaries.length,
      totalSessions: Object.keys(this.data.sessions).length,
      oldestObservation: this.data.observations[0]?.timestamp || null,
      newestObservation: this.data.observations.at(-1)?.timestamp || null,
    };
  }
}

// ============================================================================
// RuVector Integration — lazy-loaded to avoid startup cost in non-memory hooks
// ============================================================================

let _rv = null;

async function getRuVector() {
  if (_rv) return _rv;

  // Apply fetch patch for local ONNX model serving
  const bootstrapPath = join(PROJECT_ROOT, 'scripts', 'ruvector-bootstrap.mjs');
  if (existsSync(bootstrapPath)) {
    const { initRuVector } = await import(bootstrapPath);
    _rv = await initRuVector({ storagePath: DB_PATH, enableOnnx: true });
  } else {
    // Fallback: basic VectorDB without ONNX
    const ruvector = await import('ruvector');
    _rv = {
      db: new ruvector.VectorDB({ dimensions: 384, storagePath: DB_PATH }),
      embed: async (text) => {
        const svc = new ruvector.EmbeddingService();
        const [vec] = await svc.embed([text]);
        return vec;
      },
    };
  }
  return _rv;
}

// ============================================================================
// Observation Capture — structured observations from tool use
// ============================================================================

function contentHash(text) {
  return createHash('sha256').update(text).digest('hex').slice(0, 16);
}

/**
 * Capture a tool-use observation and store in RuVector.
 *
 * @param {object} input - Hook input from Claude Code
 * @param {string} input.tool_name - Tool that was used
 * @param {string} input.tool_input - Tool input (JSON string or object)
 * @param {string} input.tool_output - Tool output (truncated)
 * @param {string} input.session_id - Current session ID
 */
async function captureObservation(input) {
  const index = new MemoryIndex(INDEX_PATH);
  const rv = await getRuVector();

  const toolName = input.tool_name || input.toolName || 'unknown';
  const toolInput = typeof input.tool_input === 'string'
    ? input.tool_input : JSON.stringify(input.tool_input || {});

  // Extract structured fields
  const filePath = extractFilePath(toolInput, toolName);
  const type = classifyObservation(toolName, toolInput);
  const title = buildTitle(toolName, filePath, toolInput);
  const narrative = buildNarrative(toolName, toolInput, input.tool_output);
  const concepts = extractConcepts(toolInput, input.tool_output);
  const hash = contentHash(title + narrative);

  // Deduplicate
  const existing = index.data.observations.find(o => o.hash === hash);
  if (existing) return { deduplicated: true, id: existing.id };

  const id = `obs-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
  const timestamp = new Date().toISOString();

  const observation = {
    id,
    type,
    title,
    narrative,
    concepts,
    files: filePath ? [filePath] : [],
    tool: toolName,
    hash,
    timestamp,
    sessionId: input.session_id || process.env.CLAUDE_SESSION_ID || 'unknown',
  };

  // Store metadata in index
  index.addObservation(observation);

  // Store vector in RuVector for semantic search
  const searchText = `${title} ${narrative} ${concepts.join(' ')}`;
  const embedding = await rv.embed(searchText);
  await rv.db.insert({
    id,
    vector: embedding,
    metadata: { title, type, timestamp, tool: toolName, file: filePath || '' },
  });

  return { id, type, title };
}

function extractFilePath(toolInput, toolName) {
  try {
    const parsed = typeof toolInput === 'string' ? JSON.parse(toolInput) : toolInput;
    return parsed.file_path || parsed.path || parsed.filePath || null;
  } catch {
    // Try regex extraction
    const match = toolInput?.match?.(/(?:file_path|path)["']?\s*[:=]\s*["']([^"']+)/);
    return match?.[1] || null;
  }
}

function classifyObservation(toolName, toolInput) {
  const input = (toolInput || '').toLowerCase();
  if (toolName === 'Bash' && (input.includes('test') || input.includes('vitest'))) return 'test';
  if (toolName === 'Bash' && (input.includes('build') || input.includes('compile'))) return 'build';
  if (toolName === 'Bash' && input.includes('git')) return 'vcs';
  if (toolName === 'Write') return 'create';
  if (toolName === 'Edit' || toolName === 'MultiEdit') return 'change';
  if (toolName === 'Read' || toolName === 'Glob' || toolName === 'Grep') return 'discovery';
  if (toolName === 'Agent') return 'delegation';
  return 'action';
}

function buildTitle(toolName, filePath, toolInput) {
  const file = filePath ? filePath.split('/').pop() : '';
  switch (toolName) {
    case 'Write': return `Created ${file}`;
    case 'Edit': case 'MultiEdit': return `Modified ${file}`;
    case 'Read': return `Read ${file}`;
    case 'Bash': {
      try {
        const parsed = JSON.parse(toolInput);
        const cmd = (parsed.command || '').slice(0, 60);
        return `Ran: ${cmd}`;
      } catch { return `Ran command`; }
    }
    case 'Glob': return `Searched for files`;
    case 'Grep': return `Searched code`;
    case 'Agent': return `Dispatched subagent`;
    default: return `Used ${toolName}${file ? ` on ${file}` : ''}`;
  }
}

function buildNarrative(toolName, toolInput, toolOutput) {
  const parts = [];
  if (toolName) parts.push(`Tool: ${toolName}`);

  try {
    const parsed = typeof toolInput === 'string' ? JSON.parse(toolInput) : toolInput;
    if (parsed.file_path) parts.push(`File: ${parsed.file_path}`);
    if (parsed.command) parts.push(`Command: ${parsed.command.slice(0, 120)}`);
    if (parsed.pattern) parts.push(`Pattern: ${parsed.pattern}`);
    if (parsed.old_string) parts.push(`Replaced: ${parsed.old_string.slice(0, 80)}`);
    if (parsed.description) parts.push(`Description: ${parsed.description.slice(0, 120)}`);
  } catch { /* use raw */ }

  if (toolOutput) {
    const output = typeof toolOutput === 'string' ? toolOutput : JSON.stringify(toolOutput);
    if (output.length > 0 && output.length < 200) {
      parts.push(`Result: ${output.slice(0, 150)}`);
    }
  }
  return parts.join('. ');
}

function extractConcepts(toolInput, toolOutput) {
  const text = `${toolInput || ''} ${toolOutput || ''}`.toLowerCase();
  const concepts = new Set();
  const patterns = {
    'authentication': /\b(auth|jwt|token|login|session|oauth)\b/,
    'database': /\b(database|migration|schema|table|query|postgres|drizzle)\b/,
    'api': /\b(api|route|endpoint|rest|http|express)\b/,
    'frontend': /\b(react|component|ui|css|tailwind|vite)\b/,
    'testing': /\b(test|vitest|playwright|assert|expect|spec)\b/,
    'security': /\b(security|secret|encrypt|permission|cors|xss)\b/,
    'agent': /\b(agent|heartbeat|adapter|swarm|orchestrat)\b/,
    'deployment': /\b(docker|deploy|build|ci|cd|release)\b/,
    'cost': /\b(cost|budget|token|spend|billing)\b/,
    'git': /\b(git|commit|branch|merge|push|pull)\b/,
  };
  for (const [concept, pattern] of Object.entries(patterns)) {
    if (pattern.test(text)) concepts.add(concept);
  }
  return [...concepts];
}

// ============================================================================
// Session Summaries — structured end-of-session synthesis
// ============================================================================

async function generateSessionSummary(input) {
  const index = new MemoryIndex(INDEX_PATH);
  const rv = await getRuVector();
  const sessionId = input.session_id || process.env.CLAUDE_SESSION_ID || 'unknown';

  // Gather this session's observations
  const sessionObs = index.data.observations.filter(o => o.sessionId === sessionId);
  if (sessionObs.length === 0) return { sessionId, empty: true };

  // Synthesize summary fields
  const files = [...new Set(sessionObs.flatMap(o => o.files).filter(Boolean))];
  const concepts = [...new Set(sessionObs.flatMap(o => o.concepts))];
  const types = sessionObs.reduce((acc, o) => { acc[o.type] = (acc[o.type] || 0) + 1; return acc; }, {});

  const summary = {
    id: `sum-${Date.now()}`,
    sessionId,
    timestamp: new Date().toISOString(),
    observationCount: sessionObs.length,
    request: input.request || inferRequest(sessionObs),
    investigated: files.slice(0, 20),
    learned: concepts,
    completed: sessionObs.filter(o => ['create', 'change'].includes(o.type)).map(o => o.title),
    nextSteps: inferNextSteps(sessionObs),
    types,
  };

  // Store in index
  index.addSummary(summary);

  // Store vector for future semantic recall
  const searchText = `${summary.request} ${summary.learned.join(' ')} ${summary.completed.join('. ')}`;
  const embedding = await rv.embed(searchText);
  await rv.db.insert({
    id: summary.id,
    vector: embedding,
    metadata: { type: 'summary', sessionId, timestamp: summary.timestamp },
  });

  return summary;
}

function inferRequest(observations) {
  if (observations.length === 0) return 'Unknown task';
  const creates = observations.filter(o => o.type === 'create');
  const changes = observations.filter(o => o.type === 'change');
  if (creates.length > 0) return `Created: ${creates.map(o => o.title).join(', ')}`;
  if (changes.length > 0) return `Modified: ${changes.map(o => o.title).join(', ')}`;
  return observations[0].title;
}

function inferNextSteps(observations) {
  const steps = [];
  const hasTests = observations.some(o => o.type === 'test');
  const hasChanges = observations.some(o => ['create', 'change'].includes(o.type));
  if (hasChanges && !hasTests) steps.push('Run tests to verify changes');
  if (hasChanges) steps.push('Review changes before committing');
  return steps;
}

// ============================================================================
// Progressive Disclosure Search — 3-layer token-efficient retrieval
// ============================================================================

/**
 * Layer 1: Index search — compact results with IDs (~50-100 tokens per result)
 */
async function searchIndex(query, options = {}) {
  const rv = await getRuVector();
  const index = new MemoryIndex(INDEX_PATH);
  const { limit = 10, type, since } = options;

  const queryVec = await rv.embed(query);
  const results = await rv.db.search({ vector: queryVec, k: limit * 2 });

  // Enrich with index metadata and filter
  const enriched = results
    .map(r => {
      const obs = index.getObservation(r.id);
      if (!obs) return null;
      if (type && obs.type !== type) return null;
      if (since && new Date(obs.timestamp) < new Date(since)) return null;
      return {
        id: obs.id,
        score: r.score,
        type: obs.type,
        title: obs.title,
        timestamp: obs.timestamp,
        concepts: obs.concepts,
      };
    })
    .filter(Boolean)
    .slice(0, limit);

  return { query, count: enriched.length, results: enriched };
}

/**
 * Layer 2: Timeline — chronological context around an observation
 */
function getTimeline(anchorId, options = {}) {
  const index = new MemoryIndex(INDEX_PATH);
  const { before = 3, after = 3 } = options;
  const timeline = index.getTimeline(anchorId, before, after);
  return {
    anchor: anchorId,
    count: timeline.length,
    observations: timeline.map(o => ({
      id: o.id,
      type: o.type,
      title: o.title,
      timestamp: o.timestamp,
      isAnchor: o.id === anchorId,
    })),
  };
}

/**
 * Layer 3: Full details — complete observation data (500-1000 tokens each)
 */
function getDetails(ids) {
  const index = new MemoryIndex(INDEX_PATH);
  const observations = index.getObservations(ids);
  return { count: observations.length, observations };
}

// ============================================================================
// Context Injection — auto-inject relevant memory at session start
// ============================================================================

async function generateContext(options = {}) {
  const index = new MemoryIndex(INDEX_PATH);
  const { maxTokens = 2000 } = options;
  const parts = [];
  let tokenEstimate = 0;

  // Recent session summaries (most valuable, least tokens)
  const summaries = index.getSessionSummaries(3);
  if (summaries.length > 0) {
    parts.push('## Recent Session Summaries');
    for (const s of summaries.reverse()) {
      const entry = `- **${s.timestamp.slice(0, 10)}**: ${s.request} | Files: ${s.investigated.length} | Concepts: ${s.learned.join(', ')}`;
      const tokens = entry.length / 4; // rough estimate
      if (tokenEstimate + tokens > maxTokens * 0.6) break;
      parts.push(entry);
      tokenEstimate += tokens;
    }
  }

  // Recent observations (fill remaining budget)
  const recent = index.getRecentObservations(10);
  if (recent.length > 0 && tokenEstimate < maxTokens * 0.8) {
    parts.push('');
    parts.push('## Recent Activity');
    for (const o of recent.reverse()) {
      const entry = `- [${o.type}] ${o.title} (${o.timestamp.slice(0, 16)})`;
      const tokens = entry.length / 4;
      if (tokenEstimate + tokens > maxTokens) break;
      parts.push(entry);
      tokenEstimate += tokens;
    }
  }

  if (parts.length === 0) return null;
  return parts.join('\n');
}

// ============================================================================
// CLI Entrypoint
// ============================================================================

const [,, command, ...args] = process.argv;

async function main() {
  // Read stdin for hook data
  let stdinData = '';
  if (!process.stdin.isTTY) {
    stdinData = await new Promise((resolve) => {
      let data = '';
      const timer = setTimeout(() => { process.stdin.pause(); resolve(data); }, 500);
      process.stdin.setEncoding('utf8');
      process.stdin.on('data', (chunk) => { data += chunk; });
      process.stdin.on('end', () => { clearTimeout(timer); resolve(data); });
      process.stdin.on('error', () => { clearTimeout(timer); resolve(data); });
      process.stdin.resume();
    });
  }

  let input = {};
  if (stdinData.trim()) {
    try { input = JSON.parse(stdinData); } catch { /* use args */ }
  }
  // Also accept JSON as first arg
  if (args[0] && args[0].startsWith('{')) {
    try { Object.assign(input, JSON.parse(args[0])); } catch { /* ignore */ }
  }

  switch (command) {
    case 'observe': {
      const result = await captureObservation(input);
      console.log(JSON.stringify(result));
      break;
    }

    case 'summarize': {
      const result = await generateSessionSummary(input);
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    case 'search': {
      const query = args[0] || input.query || '';
      const result = await searchIndex(query, input);
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    case 'timeline': {
      const anchorId = args[0] || input.anchor || input.id;
      const result = getTimeline(anchorId, input);
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    case 'details': {
      const ids = args[0]?.split(',') || input.ids || [];
      const result = getDetails(ids);
      console.log(JSON.stringify(result, null, 2));
      break;
    }

    case 'context': {
      const ctx = await generateContext(input);
      if (ctx) console.log(ctx);
      break;
    }

    case 'stats': {
      const index = new MemoryIndex(INDEX_PATH);
      const s = index.stats();
      let vecCount = 0;
      try {
        const rv = await getRuVector();
        vecCount = await rv.db.len();
      } catch { /* ignore */ }
      console.log(JSON.stringify({ ...s, vectorCount: vecCount }, null, 2));
      break;
    }

    default:
      console.error(`Unknown command: ${command}`);
      console.error('Commands: observe, summarize, search, timeline, details, context, stats');
      process.exit(1);
  }
}

main().catch(e => {
  console.error(`[paperclip-memory] ${e.message}`);
  process.exit(1);
});

// Export for programmatic use
export { captureObservation, generateSessionSummary, searchIndex, getTimeline, getDetails, generateContext, MemoryIndex };
