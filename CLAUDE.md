# Claude Code Configuration — Paperclip AI Company Platform

## What Is Paperclip

Paperclip is an open-source orchestration platform for autonomous AI companies.
It is the control plane for managing teams of AI agents with organizational
structure, governance, budgets, and accountability. Built with Express 5, React 19,
PostgreSQL (PGlite for dev), Drizzle ORM, and TypeScript.

## Priority Order

1. **User instructions** (direct requests, this file) — highest priority
2. **Superpowers skills** — govern development methodology (HOW to work)
3. **Ruflo swarm/agents** — govern orchestration and scaling (HOW to coordinate)
4. **RuVector** — powers vector intelligence, semantic search, learning, and analysis
5. **Default system prompt** — lowest priority

When a Superpowers skill and a Ruflo agent both apply, use the Superpowers skill
for methodology (brainstorming, TDD, debugging) and Ruflo for execution
(spawning agents, memory, swarm coordination). RuVector provides the underlying
intelligence layer that both can leverage.

---

## Behavioral Rules (Always Enforced)

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary for achieving your goal
- ALWAYS prefer editing an existing file to creating a new one
- NEVER proactively create documentation files (*.md) or README files unless explicitly requested
- NEVER save working files, text/mds, or tests to the root folder
- Never continuously check status after spawning a swarm — wait for results
- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files

## Project Structure

```
paperclipAU/
├── server/src/          # Express REST API (routes/, services/, adapters/, middleware/)
├── ui/src/              # React 19 + Vite frontend (pages/, components/, api/, hooks/)
├── packages/
│   ├── db/src/schema/   # Drizzle ORM schema (45+ tables)
│   ├── shared/src/      # Shared TypeScript types
│   ├── adapters/        # Agent adapters (claude, codex, cursor, gemini, hermes, etc.)
│   └── plugins/         # Plugin system (SDK, scaffolder, examples)
├── skills/              # Paperclip-specific agent skills
├── doc/                 # Product specs (GOAL.md, PRODUCT.md, SPEC.md, TASKS.md)
├── .claude/             # Ruflo + Superpowers (skills/, agents/, commands/, helpers/)
└── node_modules/ruvector/  # RuVector intelligence layer
```

## Paperclip Domain Model

### Core Concepts

- **Company** — first-order entity; all data is company-scoped. One Paperclip instance runs many companies.
- **Agent** — every employee is an AI agent. Organized in a strict tree (`reports_to`). Each has an adapter type (process, http) + config.
- **Goal hierarchy** — company goal → team goals → agent goals → tasks. All work traces back to the company mission.
- **Issue** — the fundamental unit of work. Supports parent-child hierarchy, single assignee, atomic checkout.
- **Heartbeat** — agents wake on schedule, check inbox, do work, report back. Two modes: process (fork subprocess) or http (webhook).
- **Board** — human governance layer. Creates companies, approves hires, intervenes when needed.
- **Adapter** — connects execution environments: `claude-local`, `codex-local`, `cursor-local`, `gemini-local`, `openclaw-gateway`, `hermes`, `pi-local`, `opencode-local`.

### Task Lifecycle

`backlog` → `todo` → `in_progress` (atomic checkout) → `in_review` → `done`
Also: `blocked`, `cancelled`. Single assignee only. No automatic reassignment.

### Key Patterns

- **Agent API auth**: API keys (hashed at rest) + run JWT tokens (short-lived per heartbeat)
- **Environment injection**: agents receive `PAPERCLIP_*` env vars for API access
- **Run tracking**: `PAPERCLIP_RUN_ID` header links all actions to execution context
- **Cost control**: monthly UTC budget per agent, hard-stop auto-pause on overspend
- **Activity log**: immutable audit trail for all mutating actions
- **Real-time**: WebSocket live events for task updates, comments, heartbeats
- **Communication**: tasks + comments only (no separate chat system)

### API Routes (server/src/routes/)

| Route | Description |
|-------|-------------|
| `/api/companies` | Company CRUD |
| `/api/agents` | Agent lifecycle, `/me` identity, `/me/inbox-lite` |
| `/api/issues` | Task CRUD, `/{id}/checkout` atomic assignment, `/{id}/comments` |
| `/api/goals` | Goal hierarchy management |
| `/api/projects` | Project management + workspaces |
| `/api/approvals` | Governance approval workflows |
| `/api/costs` | Cost tracking + budget enforcement |
| `/api/secrets` | Encrypted secret storage (company-scoped) |
| `/api/activity` | Immutable audit log |
| `/api/dashboard` | Company summary metrics |
| `/api/plugins` | Plugin registry, webhooks, jobs |
| `/api/access` | Authorization info |

### Database (packages/db/src/schema/)

45+ tables via Drizzle ORM. Key tables: `companies`, `agents`, `issues`,
`issue_comments`, `goals`, `projects`, `approvals`, `cost_events`,
`heartbeat_runs`, `activity_log`, `documents`, `plugins`, `company_secrets`.
Embedded PGlite for dev, hosted Postgres for production.

### Frontend (ui/src/)

React 19 + Vite + Tailwind CSS 4 + Radix UI. Pages: dashboard, agents (org chart),
issues (kanban), goals, projects, costs, activity, approvals, settings.
TanStack React Query for server state. WebSocket for real-time updates.

## Build & Test

```bash
pnpm dev              # Dev mode (API + UI, watch)
pnpm build            # Production build
pnpm test:run         # All tests (Vitest)
pnpm db:generate      # Generate DB migrations
pnpm db:migrate       # Apply migrations
```

- ALWAYS run tests after making code changes
- ALWAYS verify build succeeds before committing

---

## RuVector — Intelligence Layer

RuVector (`ruvector` npm package) is a high-performance vector database and
ML intelligence engine with Rust NAPI bindings. It provides the semantic
backbone for Paperclip's AI capabilities.

### IMPORTANT: Initialization

RuVector requires the bootstrap script for ONNX semantic embeddings.
Without it, embeddings are character n-gram (NOT semantic — useless for search).

```typescript
// Always use the bootstrap for proper initialization
import { initRuVector } from './scripts/ruvector-bootstrap.mjs';
const rv = await initRuVector({ storagePath: '.ruvector/paperclip.db' });
// rv.db       — VectorDB (HNSW, sub-ms search)
// rv.embedder — ONNX MiniLM-L6-v2 (384d semantic embeddings)
// rv.engine   — IntelligenceEngine (memory + routing + learning)
// rv.router   — SemanticRouter (native, intent matching)
// rv.graph    — GraphDatabase (Cypher, nodes require embeddings)
// rv.sona     — SonaEngine (LoRA, EWC++, trajectory learning)
// rv.embed()  — Helper: text → 384d semantic vector
```

**Model files** are pre-downloaded at `~/.ruvector/models/`. The bootstrap
patches `fetch()` to serve them locally (Node.js DNS issues with HuggingFace).

### Verified Subsystem Status

| Subsystem | Status | Native Package | Notes |
|-----------|--------|---------------|-------|
| **VectorDB** | WORKING | `@ruvector/core` (Rust NAPI) | Real HNSW, sub-ms, cosine distance |
| **ONNX Embedder** | WORKING | bundled WASM + onnxruntime-node | 384d all-MiniLM-L6-v2, SIMD enabled |
| **SemanticRouter** | WORKING | `@ruvector/router` (native) | Use native directly, NOT the ruvector wrapper (API mismatch) |
| **GraphDatabase** | WORKING | `@ruvector/graph-node` (native) | Cypher queries; nodes+edges require Float32Array embeddings |
| **SONA** | WORKING | `@ruvector/sona` (Rust NAPI) | `new SonaEngine(384)` — takes dimension as single number |
| **GNN** | AVAILABLE | `@ruvector/gnn` (native) | Differentiable search, attention mechanisms |
| **Attention** | AVAILABLE | `@ruvector/attention` (native) | Flash, multi-head, hyperbolic attention |
| **RVF Format** | AVAILABLE | `@ruvector/rvf` (native) | Binary vector container format |
| **Cluster** | INSTALLED | `@ruvector/cluster` | Raft consensus, sharding (not yet tested) |
| **IntelligenceEngine** | WORKING | bundled JS | Orchestrates all above; use `enableOnnx: true` |
| **LearningEngine** | WORKING | bundled JS | 9 RL algorithms (Q-learning, SARSA, PPO, etc.) |
| **AdaptiveEmbedder** | WORKING | bundled JS | LoRA adaptation, contrastive learning, EWC++ |
| **Graph Algorithms** | WORKING | bundled JS | Stoer-Wagner, spectral clustering, Louvain, Tarjan |

### API Quirks (Tested, Not Documented)

- **VectorDB**: `distanceMetric` config crashes — use default (cosine). Search scores are distance (lower = more similar).
- **SemanticRouter wrapper is BROKEN** — use `require('@ruvector/router')` directly:
  ```typescript
  import { SemanticRouter } from '@ruvector/router';
  const router = new SemanticRouter({ dimension: 384, threshold: 0.5 });
  router.addIntent({ name: 'backend', utterances: ['api','db'], embedding: Float32Array });
  const match = router.routeWithEmbedding(queryFloat32Array);
  ```
- **GraphDatabase**: Nodes require `embedding: Float32Array(384)`. Edges require `from`, `to`, `edgeType`, `description`, `embedding`.
- **SonaEngine**: Constructor takes a single number `new SonaEngine(384)`, NOT an options object.
- **IntelligenceEngine**: `embed()` (sync) always uses hash fallback. MUST use `embedAsync()` or the bootstrap's `rv.embed()` for real semantic embeddings.

### Paperclip Business Applications

#### 1. Semantic Task Routing

```typescript
// Use @ruvector/router directly (not the broken wrapper)
import { SemanticRouter } from '@ruvector/router';
const router = new SemanticRouter({ dimension: 384, threshold: 0.5 });

// Add intents with pre-computed ONNX embeddings
const backendEmb = new Float32Array(await rv.embed('build REST API endpoint'));
router.addIntent({ name: 'backend', utterances: ['api', 'database'], embedding: backendEmb });
const match = router.routeWithEmbedding(new Float32Array(await rv.embed(task.description)));
// → { intent: 'backend', score: 0.546 }
```

#### 2. Agent Memory & Knowledge Base

```typescript
// Store with ONNX semantic embeddings (NOT n-gram)
const vec = await rv.embed('JWT refresh token rotation pattern');
await rv.db.insert({ id: 'pattern-001', vector: vec, metadata: { agent: 'auth-agent', type: 'pattern' } });

// Search returns results ranked by cosine distance (lower = more similar)
const results = await rv.db.search({ vector: await rv.embed('authentication tokens'), k: 5 });
// → [{id: 'pattern-001', score: 0.502, metadata: {...}}, ...]
```

#### 3. Agent Performance Learning

```typescript
import { LearningEngine } from 'ruvector';

const learner = new LearningEngine();
learner.configure('agent-routing', { algorithm: 'ppo', learningRate: 0.001 });
learner.update('agent-routing', {
  state: 'task:api-endpoint', action: 'assign:backend-agent',
  reward: 0.95, nextState: 'task:complete', done: true,
});
```

#### 4. Company Knowledge Graph

```typescript
// Use @ruvector/graph-node directly (nodes require embeddings)
import { GraphDatabase } from '@ruvector/graph-node';
const graph = new GraphDatabase();

const agentEmb = new Float32Array(await rv.embed('Backend developer TypeScript PostgreSQL'));
const projEmb = new Float32Array(await rv.embed('Billing and payments module'));
const edgeEmb = new Float32Array(await rv.embed('assigned to work on'));

graph.createNode({ id: 'agent-001', labels: ['Agent'], properties: { name: 'Backend Dev' }, embedding: agentEmb });
graph.createNode({ id: 'project-alpha', labels: ['Project'], properties: { name: 'Billing' }, embedding: projEmb });
graph.createEdge({ from: 'agent-001', to: 'project-alpha', edgeType: 'ASSIGNED_TO', description: 'works on', properties: {}, embedding: edgeEmb });

const result = graph.querySync("MATCH (a:Agent)-[:ASSIGNED_TO]->(p:Project) RETURN a");
```

#### 5. Distributed Agent Coordination
Scale across multiple nodes with consensus.

```typescript
import { RuvectorCluster } from 'ruvector';

const cluster = new RuvectorCluster({
  nodeId: 'node-1', address: 'localhost:9001',
  peers: ['localhost:9002', 'localhost:9003'],
  shards: 4, replicationFactor: 2,
});
await cluster.start();
```

#### 6. Smart Cost Optimization
Learn which agent + model tier combo gives best results per cost.

```typescript
// Use the bootstrap-initialized engine (enableOnnx: true)
await rv.engine.recordEpisode({
  state: 'task:simple-crud', action: 'model:haiku',
  reward: 0.9, nextState: 'complete', done: true,
});
const route = await rv.engine.route('Build a CRUD endpoint for users');
// → { agent: 'coder', confidence: 0.5+, reason: 'pattern match' }
// Confidence improves with training data over time
```

#### 7. Document & Issue Semantic Search
Search across company knowledge by meaning, not just keywords.

```typescript
// Use bootstrap rv.embed() for real semantic embeddings (NOT EmbeddingService which is n-gram only)

// Index documents with ONNX embeddings via bootstrap
for (const doc of documents) {
  await rv.db.insert({ id: doc.id, vector: await rv.embed(doc.description), metadata: { type: 'issue', title: doc.title } });
}
// Search by meaning — scores are cosine distance (lower = more similar)
const results = await rv.db.search({ vector: await rv.embed('authentication security'), k: 10 });
```

#### 8. Security & Code Quality Analysis

```typescript
import { security, complexity } from 'ruvector';

// Scan code for vulnerabilities (OWASP patterns)
const vulns = security.scan(sourceCode);
// Measure cyclomatic complexity
const metrics = complexity.analyze(sourceCode);
```

### RuVector Configuration Defaults

```typescript
// Always use the bootstrap (handles ONNX model loading + fetch patching)
import { initRuVector } from './scripts/ruvector-bootstrap.mjs';
const rv = await initRuVector({
  embeddingDim: 384,           // MiniLM-L6 (do not change)
  storagePath: '.ruvector/',   // Persist alongside project
  enableOnnx: true,            // REQUIRED for semantic search
});
// HNSW config: m=16, efConstruction=200, efSearch=50 (set in bootstrap)
// Distance metric: cosine (default, do NOT set explicitly — crashes native)
```

### Integration Points with Paperclip Schema

| Paperclip Table | RuVector Enhancement |
|----------------|---------------------|
| `issues` | Semantic search over descriptions; auto-categorization via SemanticRouter |
| `agents` | Skill-based routing via embeddings; performance learning via LearningEngine |
| `documents` | Full semantic search over company knowledge base |
| `cost_events` | RL-based model tier optimization to minimize cost while maintaining quality |
| `activity_log` | Pattern extraction; anomaly detection via SONA |
| `agent_runtime_state` | Episode tracking via FastAgentDB for agent improvement |
| `company_secrets` | Security scanning of code touching secrets |
| `issue_comments` | Semantic threading; duplicate detection |
| `plugins` | Intent routing for plugin dispatch |
| `goals` | Goal-task alignment scoring via embedding similarity |

---

## Paperclip Memory System

Native persistent memory built on RuVector. Automatically captures observations
from tool use, generates session summaries, and provides semantic search.
Replaces claude-mem patterns with zero external dependencies.

**Storage**: `.ruvector/paperclip-memory.db` (HNSW vectors) + `.ruvector/memory-index.json` (metadata)

### How It Works (Automatic via Hooks)

| Hook | Action | What Happens |
|------|--------|-------------|
| **PostToolUse** | Observation capture | Every Write/Edit/Bash tool use → structured observation (type, title, narrative, concepts, files) → stored as 384d ONNX embedding in RuVector |
| **SessionStart** | Context injection | Recent summaries + activity auto-injected into session context |
| **Stop / SessionEnd** | Session summary | Synthesizes (request, investigated, learned, completed, next_steps) → stored as embedding |

### Progressive Disclosure Search (3-Layer, Token-Efficient)

```bash
# Layer 1: Index — compact results with IDs (~50-100 tokens/result)
node .claude/helpers/paperclip-memory.mjs search "authentication tokens"

# Layer 2: Timeline — chronological context around an observation
node .claude/helpers/paperclip-memory.mjs timeline obs-1234

# Layer 3: Full details — complete observation data (~500-1000 tokens each)
node .claude/helpers/paperclip-memory.mjs details obs-1234,obs-5678
```

### Other Commands

```bash
node .claude/helpers/paperclip-memory.mjs context    # What gets injected at session start
node .claude/helpers/paperclip-memory.mjs stats      # Memory statistics
```

### Observation Types

`create`, `change`, `discovery`, `test`, `build`, `vcs`, `delegation`, `action`

### Concept Auto-Tagging

Observations are auto-tagged with concepts: `authentication`, `database`, `api`,
`frontend`, `testing`, `security`, `agent`, `deployment`, `cost`, `git`.

---

## Superpowers — Automatic Skill Invocation

Superpowers skills are composable development workflows that MUST be invoked
automatically when they apply. Use the `Skill` tool to invoke them.

### When to Invoke Skills (Non-Negotiable)

| Trigger | Skill to Invoke | Then Use Ruflo/RuVector For |
|---------|----------------|-----------------------------|
| Any new feature, component, or behavior change | `brainstorming` | Swarm agents to implement after design approval |
| Approved design or spec ready for implementation | `writing-plans` | — |
| Written plan ready to execute | `executing-plans` | Dispatch via `dispatching-parallel-agents` or Ruflo swarm |
| Any feature or bugfix implementation | `test-driven-development` | — |
| Any bug, test failure, or unexpected behavior | `systematic-debugging` | RuVector memory search for past patterns |
| 2+ independent tasks that can run in parallel | `dispatching-parallel-agents` | Ruflo swarm for scaling beyond 2-3 agents |
| Implementation complete, claiming "done" | `verification-before-completion` | RuVector security/complexity analysis |
| Completing a task or major feature | `requesting-code-review` | Ruflo `code-reviewer` agent |
| Receiving review feedback | `receiving-code-review` | — |
| Feature work needing isolation | `using-git-worktrees` | — |
| Branch work complete, ready to merge/PR | `finishing-a-development-branch` | — |
| Creating or modifying a skill | `writing-skills` | — |

### Skill Invocation Rules

- **Check for applicable skills BEFORE any response or action**, even clarifying questions
- If there is even a 1% chance a skill applies, invoke it via the `Skill` tool
- Process skills first (brainstorming, debugging), then implementation skills
- Subagents dispatched for specific tasks should SKIP the `using-superpowers` skill
- Never read skill files with the Read tool — always use the `Skill` tool

---

## Ruflo — Swarm Orchestration & Infrastructure

Ruflo handles multi-agent coordination, memory, and background workers.
Use Ruflo when Superpowers skills need to scale beyond a single agent.

### When Ruflo Activates

| Trigger | Ruflo Action |
|---------|-------------|
| Complex multi-file implementation plan | Spawn swarm agents via `dispatching-parallel-agents` skill + Ruflo swarm |
| Need past patterns or context | `memory search --query "..."` |
| Code review requested by Superpowers | Dispatch Ruflo `code-reviewer` agent |
| Security-related changes | `security scan` via daemon |
| Large-scale refactor (5+ files) | Initialize swarm with hierarchical topology |
| Performance investigation | Ruflo `performance-engineer` agent |

### Swarm Configuration

- **Topology**: hierarchical-mesh
- **Max Agents**: 15 (use 6-8 for tight coordination)
- **Memory**: hybrid with HNSW indexing
- **Consensus**: raft (leader maintains authoritative state)

### Swarm Execution Rules

- ALWAYS use `run_in_background: true` for agent Task calls
- ALWAYS put ALL agent Task calls in ONE message for parallel execution
- After spawning, STOP — do NOT add more tool calls or check status
- When agent results arrive, review ALL results before proceeding

### 3-Tier Model Routing (ADR-026)

| Tier | Handler | Use Cases |
|------|---------|-----------|
| **1** | Agent Booster (WASM) | Simple transforms — skip LLM |
| **2** | Haiku | Simple tasks, low complexity (<30%) |
| **3** | Sonnet/Opus | Complex reasoning, architecture, security (>30%) |

---

## Combined Workflow — How All Three Work Together

### Example: "Add semantic search to issues"

```
1. Superpowers: `brainstorming` → design search UX, embedding strategy, index schema
2. Superpowers: `writing-plans` → break into tasks (embedder, index, API route, UI)
3. Superpowers: `executing-plans` →
   └─ RuVector: VectorDB for HNSW index, EmbeddingService for text→vector
   └─ Ruflo: Spawn parallel agents for API route + UI component + tests
   └─ Superpowers: Each task follows `test-driven-development`
4. Superpowers: `verification-before-completion` → verify search quality, run tests
5. Superpowers: `requesting-code-review` → dispatch Ruflo code-reviewer
```

### Example: "Improve agent task assignment"

```
1. Superpowers: `brainstorming` → design smart routing approach
2. RuVector: SemanticRouter for intent matching + LearningEngine for RL optimization
3. RuVector: IntelligenceEngine to combine memory + routing + learning
4. Superpowers: `test-driven-development` → test routing accuracy
5. Superpowers: `verification-before-completion` → measure improvement
```

### Example: "Fix bug in cost tracking"

```
1. Superpowers: `systematic-debugging` → root cause investigation
   └─ RuVector: memory search for similar past bugs; pattern analysis
2. Superpowers: `test-driven-development` → write failing test, then fix
3. Superpowers: `verification-before-completion` → confirm fix works
4. Superpowers: `requesting-code-review` → review the fix
```

---

## File Organization

- `server/src/` — Express API (routes, services, adapters, middleware)
- `ui/src/` — React frontend (pages, components, hooks, api client)
- `packages/db/src/schema/` — Drizzle ORM schema (45+ tables)
- `packages/shared/src/` — Shared TypeScript types
- `packages/adapters/` — Agent execution adapters
- `packages/plugins/` — Plugin system
- `skills/` — Paperclip-specific skills
- `doc/` — Product specs and plans
- `docs/superpowers/specs/` — Design docs from brainstorming
- `.ruvector/` — RuVector persistent storage (vector indexes, agent memory, knowledge graph)

## Project Architecture

- Follow Domain-Driven Design with bounded contexts
- Keep files under 500 lines
- Use typed interfaces for all public APIs
- Prefer TDD London School (mock-first) for new code
- Use event sourcing for state changes
- Ensure input validation at system boundaries
- Use RuVector for all vector/embedding/ML operations — never roll custom implementations

## Security Rules

- NEVER hardcode API keys, secrets, or credentials in source files
- NEVER commit .env files or any file containing secrets
- Always validate user input at system boundaries
- Always sanitize file paths to prevent directory traversal
- Use `import { security } from 'ruvector'` for code security scanning
- Run `npx ruflo@latest security scan` after security-related changes

## Concurrency: 1 MESSAGE = ALL RELATED OPERATIONS

- All operations MUST be concurrent/parallel in a single message
- ALWAYS batch ALL todos in ONE TodoWrite call
- ALWAYS spawn ALL agents in ONE message with full instructions
- ALWAYS batch ALL file reads/writes/edits in ONE message
- ALWAYS batch ALL Bash commands in ONE message

## Available Agents

### Ruflo Agents (99)
`coder`, `reviewer`, `tester`, `planner`, `researcher`, `security-architect`,
`security-auditor`, `memory-specialist`, `performance-engineer`,
`hierarchical-coordinator`, `mesh-coordinator`, `adaptive-coordinator`,
`pr-manager`, `code-review-swarm`, `issue-tracker`, `release-manager`,
`sparc-coord`, `sparc-coder`, `specification`, `pseudocode`, `architecture`

### Superpowers Agent
`code-reviewer` — dispatched by the `requesting-code-review` skill

## CLI Quick Reference

| Command | Description |
|---------|-------------|
| `pnpm dev` | Start dev server (API + UI) |
| `pnpm build` | Production build |
| `pnpm test:run` | Run all tests |
| `pnpm db:generate` | Generate DB migration |
| `pnpm db:migrate` | Apply DB migrations |
| `npx ruflo@latest daemon start` | Start background workers |
| `npx ruflo@latest swarm init` | Initialize swarm |
| `npx ruflo@latest swarm status` | Check swarm status |
| `npx ruflo@latest memory search --query "..."` | Search memory |
| `npx ruflo@latest agent spawn -t TYPE --name NAME` | Spawn agent |
| `npx ruflo@latest security scan` | Security scan |
| `npx ruvector --help` | RuVector CLI |

## Support

- Paperclip: https://github.com/auitenbroek1/paperclipAU
- Ruflo: https://github.com/ruvnet/ruflo
- Superpowers: https://github.com/obra/superpowers
- RuVector: https://github.com/ruvnet/ruvector
