# Claude Code Configuration — Ruflo V3 + Superpowers

## Priority Order

1. **User instructions** (direct requests, this file) — highest priority
2. **Superpowers skills** — govern development methodology (HOW to work)
3. **Ruflo swarm/agents** — govern orchestration and scaling (HOW to coordinate)
4. **Default system prompt** — lowest priority

When a Superpowers skill and a Ruflo agent both apply, use the Superpowers skill
for methodology (brainstorming, TDD, debugging) and Ruflo for execution
(spawning agents, memory, swarm coordination).

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

## Superpowers — Automatic Skill Invocation

Superpowers skills are composable development workflows that MUST be invoked
automatically when they apply. Use the `Skill` tool to invoke them.

### When to Invoke Skills (Non-Negotiable)

| Trigger | Skill to Invoke | Then Use Ruflo For |
|---------|----------------|--------------------|
| Any new feature, component, or behavior change | `brainstorming` | Swarm agents to implement after design approval |
| Approved design or spec ready for implementation | `writing-plans` | — |
| Written plan ready to execute | `executing-plans` | Dispatch via `dispatching-parallel-agents` or Ruflo swarm |
| Any feature or bugfix implementation | `test-driven-development` | — |
| Any bug, test failure, or unexpected behavior | `systematic-debugging` | Memory search for past patterns |
| 2+ independent tasks that can run in parallel | `dispatching-parallel-agents` | Ruflo swarm for scaling beyond 2-3 agents |
| Implementation complete, claiming "done" | `verification-before-completion` | — |
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

```bash
# Initialize swarm for complex tasks
npx ruflo@latest swarm init --topology hierarchical --max-agents 8 --strategy specialized

# Memory operations
npx ruflo@latest memory search --query "authentication patterns"
npx ruflo@latest memory store --key "pattern-auth" --value "JWT with refresh" --namespace patterns
```

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

## Combined Workflow — How They Work Together

### Example: "Add feature X"

```
1. Superpowers: Invoke `brainstorming` → collaborative design with user
2. Superpowers: Invoke `writing-plans` → break into tasks
3. Superpowers: Invoke `executing-plans` → execute with checkpoints
   └─ Ruflo: Spawn swarm agents for parallel independent tasks
   └─ Superpowers: Each task follows `test-driven-development`
4. Superpowers: Invoke `verification-before-completion` → evidence before claims
5. Superpowers: Invoke `requesting-code-review` → dispatch Ruflo code-reviewer
6. Superpowers: Invoke `finishing-a-development-branch` → merge/PR decision
```

### Example: "Fix bug Y"

```
1. Superpowers: Invoke `systematic-debugging` → root cause investigation
   └─ Ruflo: `memory search` for similar past bugs
2. Superpowers: Invoke `test-driven-development` → write failing test, then fix
3. Superpowers: Invoke `verification-before-completion` → confirm fix works
4. Superpowers: Invoke `requesting-code-review` → review the fix
```

### Example: "Refactor module Z"

```
1. Superpowers: Invoke `brainstorming` → design the refactor approach
2. Superpowers: Invoke `writing-plans` → plan the changes
3. Ruflo: Spawn swarm for parallel file changes
   └─ Superpowers: Each agent follows `test-driven-development`
4. Superpowers: Invoke `verification-before-completion`
5. Superpowers: Invoke `requesting-code-review`
```

## File Organization

- `/src` — source code
- `/tests` — test files
- `/docs` — documentation (including `docs/superpowers/specs/` for design docs)
- `/config` — configuration files
- `/scripts` — utility scripts
- `/examples` — example code

## Project Architecture

- Follow Domain-Driven Design with bounded contexts
- Keep files under 500 lines
- Use typed interfaces for all public APIs
- Prefer TDD London School (mock-first) for new code
- Use event sourcing for state changes
- Ensure input validation at system boundaries

## Build & Test

```bash
npm run build    # Build
npm test         # Test
npm run lint     # Lint
```

- ALWAYS run tests after making code changes
- ALWAYS verify build succeeds before committing

## Security Rules

- NEVER hardcode API keys, secrets, or credentials in source files
- NEVER commit .env files or any file containing secrets
- Always validate user input at system boundaries
- Always sanitize file paths to prevent directory traversal
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

## V3 CLI Quick Reference

| Command | Description |
|---------|-------------|
| `npx ruflo@latest daemon start` | Start background workers |
| `npx ruflo@latest swarm init` | Initialize swarm |
| `npx ruflo@latest swarm status` | Check swarm status |
| `npx ruflo@latest memory search --query "..."` | Search memory |
| `npx ruflo@latest memory store --key K --value V` | Store to memory |
| `npx ruflo@latest agent spawn -t TYPE --name NAME` | Spawn agent |
| `npx ruflo@latest security scan` | Security scan |
| `npx ruflo@latest doctor --fix` | Diagnose and fix |

## Support

- Ruflo: https://github.com/ruvnet/ruflo
- Superpowers: https://github.com/obra/superpowers
