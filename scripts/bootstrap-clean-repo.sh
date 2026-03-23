#!/usr/bin/env bash
# ============================================================================
# bootstrap-clean-repo.sh — Create a clean private repo with Paperclip
#                            installed as a git subtree
# ============================================================================
#
# Creates a NEW private repository where:
#   - Paperclip (from paperclipai/paperclip) lives in a paperclip/ subtree
#   - Your customizations (.claude/, .ruvector/, scripts/) live at the root
#   - RuVector, Ruflo, and Superpowers are installed as npm packages
#   - Updates from upstream Paperclip are pulled via: git subtree pull
#
# Usage:
#   bash bootstrap-clean-repo.sh <project-name>
#   bash bootstrap-clean-repo.sh <project-name> --dry-run
#
# Prerequisites: Node.js >=20, pnpm >=9, git, curl
#
# Update Paperclip later with:
#   git subtree pull --prefix=paperclip \
#     https://github.com/paperclipai/paperclip.git master --squash
# ============================================================================

set -euo pipefail

# --- Colors & helpers -------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { printf "${CYAN}[INFO]${NC}  %s\n" "$*"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()  { printf "${RED}[FAIL]${NC}  %s\n" "$*"; exit 1; }
step()  { printf "\n${BOLD}━━━ Step %s: %s${NC}\n" "$1" "$2"; }

DRY_RUN=false
PROJECT_NAME="${1:-}"
PAPERCLIP_UPSTREAM="https://github.com/paperclipai/paperclip.git"
PAPERCLIP_BRANCH="master"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

if [[ -z "$PROJECT_NAME" || "$PROJECT_NAME" == --* ]]; then
  echo "Usage: bash bootstrap-clean-repo.sh <project-name> [--dry-run]"
  exit 1
fi

# Write a file (skipped in dry-run, logged either way)
writefile() {
  local filepath="$1"
  if $DRY_RUN; then
    printf "${YELLOW}[DRY-RUN]${NC} write %s\n" "$filepath"
    cat > /dev/null
  else
    mkdir -p "$(dirname "$filepath")"
    cat > "$filepath"
  fi
}

# Run a command (logged in dry-run)
run() {
  if $DRY_RUN; then
    printf "${YELLOW}[DRY-RUN]${NC} %s\n" "$*"
  else
    "$@"
  fi
}

# --- Step 0: Prerequisites --------------------------------------------------
step 0 "Checking prerequisites"

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    fail "$1 is required but not installed. $2"
  fi
  ok "$1 found: $(command -v "$1")"
}

check_cmd node "Install from https://nodejs.org (v20+)"
check_cmd pnpm "Install with: npm install -g pnpm"
check_cmd git  "Install from https://git-scm.com"
check_cmd curl "Install via your system package manager"

NODE_MAJOR=$(node -e 'console.log(process.versions.node.split(".")[0])')
if (( NODE_MAJOR < 20 )); then
  fail "Node.js v20+ required (found v$(node -v))"
fi
ok "Node.js v$(node -v | tr -d v) (meets >=20 requirement)"

PNPM_MAJOR=$(pnpm -v | cut -d. -f1)
if (( PNPM_MAJOR < 9 )); then
  fail "pnpm v9+ required (found v$(pnpm -v))"
fi
ok "pnpm v$(pnpm -v)"

# --- Step 1: Create project directory ---------------------------------------
step 1 "Creating project directory: $PROJECT_NAME"

if [[ -d "$PROJECT_NAME" ]]; then
  fail "Directory '$PROJECT_NAME' already exists"
fi

if $DRY_RUN; then
  printf "${YELLOW}[DRY-RUN]${NC} mkdir -p %s && cd %s\n" "$PROJECT_NAME" "$PROJECT_NAME"
else
  mkdir -p "$PROJECT_NAME"
  cd "$PROJECT_NAME"
fi

# --- Step 2: Git init + initial commit (needed for subtree) -----------------
step 2 "Initializing git repository"

run git init

# Create a minimal file so we have an initial commit (subtree requires one)
if ! $DRY_RUN; then
  echo "# $PROJECT_NAME" > README.md
  git add README.md
  git commit -m "Initial commit" --no-gpg-sign 2>/dev/null \
    || git commit -m "Initial commit" 2>/dev/null \
    || warn "Initial commit failed — configure git user.name/user.email"
fi

# --- Step 3: Add Paperclip as git subtree ----------------------------------
step 3 "Adding Paperclip as git subtree (from $PAPERCLIP_UPSTREAM)"

info "This clones the full Paperclip repo into paperclip/ — may take a minute..."
if ! $DRY_RUN; then
  git subtree add --prefix=paperclip "$PAPERCLIP_UPSTREAM" "$PAPERCLIP_BRANCH" --squash \
    || fail "git subtree add failed. Check network connectivity and repo URL."
  ok "Paperclip added at paperclip/"
else
  printf "${YELLOW}[DRY-RUN]${NC} git subtree add --prefix=paperclip %s %s --squash\n" \
    "$PAPERCLIP_UPSTREAM" "$PAPERCLIP_BRANCH"
fi

# --- Step 4: Root config files ----------------------------------------------
step 4 "Creating root configuration files"

info "Writing package.json (references paperclip/ subtree packages)"
writefile package.json <<EOF
{
  "name": "${PROJECT_NAME}",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "pnpm --filter @paperclipai/server dev:watch",
    "dev:server": "pnpm --filter @paperclipai/server dev",
    "dev:ui": "pnpm --filter @paperclipai/ui dev",
    "build": "pnpm -r build",
    "typecheck": "pnpm -r typecheck",
    "test": "vitest",
    "test:run": "vitest run",
    "db:generate": "pnpm --filter @paperclipai/db generate",
    "db:migrate": "pnpm --filter @paperclipai/db migrate",
    "paperclip:update": "git subtree pull --prefix=paperclip ${PAPERCLIP_UPSTREAM} ${PAPERCLIP_BRANCH} --squash"
  },
  "devDependencies": {
    "esbuild": "^0.27.3",
    "typescript": "^5.7.3",
    "vitest": "^3.0.5"
  },
  "engines": {
    "node": ">=20"
  },
  "packageManager": "pnpm@9.15.4",
  "dependencies": {
    "@ruvector/cluster": "^0.1.0",
    "@ruvector/graph-node": "^2.0.2",
    "@ruvector/router": "^0.1.28",
    "onnxruntime-node": "^1.24.3",
    "ruvector": "^0.2.16"
  }
}
EOF

info "Writing pnpm-workspace.yaml (pointing into paperclip/ subtree)"
writefile pnpm-workspace.yaml <<'EOF'
packages:
  # Paperclip packages (from git subtree)
  - paperclip/packages/*
  - paperclip/packages/adapters/*
  - paperclip/packages/plugins/*
  - paperclip/packages/plugins/examples/*
  - paperclip/server
  - paperclip/ui
  - paperclip/cli
EOF

info "Writing .npmrc"
writefile .npmrc <<'EOF'
auto-install-peers=true
EOF

info "Writing tsconfig.base.json"
writefile tsconfig.base.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "dist",
    "rootDir": "src",
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true
  }
}
EOF

info "Writing tsconfig.json (project references into subtree)"
writefile tsconfig.json <<'EOF'
{
  "extends": "./tsconfig.base.json",
  "files": [],
  "references": [
    { "path": "./paperclip/packages/shared" },
    { "path": "./paperclip/packages/db" },
    { "path": "./paperclip/server" },
    { "path": "./paperclip/ui" }
  ]
}
EOF

info "Writing vitest.config.ts"
writefile vitest.config.ts <<'EOF'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    projects: ["paperclip/packages/db", "paperclip/server", "paperclip/ui"],
  },
});
EOF

info "Writing .gitignore"
writefile .gitignore <<'EOF'
node_modules/
dist/
.env
.env.*
*.tsbuildinfo
drizzle/meta/
.vite/
coverage/
.DS_Store
data/
.paperclip/
.pnpm-store/
tmp-*
tmp/
*.tmp
*.db
EOF

# --- Step 5: Subtree update helper script -----------------------------------
step 5 "Creating subtree update helper"

writefile scripts/update-paperclip.sh <<UPDATEEOF
#!/usr/bin/env bash
# ============================================================================
# update-paperclip.sh — Pull latest changes from upstream Paperclip
# ============================================================================
#
# Usage:
#   bash scripts/update-paperclip.sh              # Pull from master
#   bash scripts/update-paperclip.sh <branch/tag>  # Pull from specific ref
#
# This runs git subtree pull with --squash to merge upstream changes into
# the paperclip/ directory. Conflicts are resolved normally via git.
# ============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

UPSTREAM="${PAPERCLIP_UPSTREAM}"
REF="\${1:-${PAPERCLIP_BRANCH}}"

printf "\${BOLD}Updating Paperclip from upstream...\${NC}\n"
printf "  Remote: \${CYAN}%s\${NC}\n" "\$UPSTREAM"
printf "  Ref:    \${CYAN}%s\${NC}\n" "\$REF"
printf "\n"

if git subtree pull --prefix=paperclip "\$UPSTREAM" "\$REF" --squash; then
  printf "\n\${GREEN}[OK]\${NC} Paperclip updated successfully.\n"
  printf "Run \${CYAN}pnpm install\${NC} if dependencies changed.\n"
else
  printf "\n\${RED}[CONFLICT]\${NC} Merge conflicts detected.\n"
  printf "Resolve conflicts, then: \${CYAN}git add -A && git commit\${NC}\n"
  exit 1
fi
UPDATEEOF

if ! $DRY_RUN; then
  chmod +x scripts/update-paperclip.sh
fi
ok "Update helper created at scripts/update-paperclip.sh"

# --- Step 6: Install dependencies -------------------------------------------
step 6 "Installing npm dependencies (this may take a few minutes)"

run pnpm install
ok "Dependencies installed"

# --- Step 7: RuVector ONNX models -------------------------------------------
step 7 "Downloading RuVector ONNX models (all-MiniLM-L6-v2)"

MODELS_DIR="$HOME/.ruvector/models"
if ! $DRY_RUN; then
  mkdir -p "$MODELS_DIR"
fi

MODEL_ONNX="$MODELS_DIR/all-MiniLM-L6-v2-model.onnx"
MODEL_TOK="$MODELS_DIR/all-MiniLM-L6-v2-tokenizer.json"

if [[ -f "$MODEL_ONNX" && -f "$MODEL_TOK" ]]; then
  ok "ONNX models already present at $MODELS_DIR"
else
  info "Downloading model.onnx (~23MB)..."
  run curl -sL -o "$MODEL_ONNX" \
    "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/onnx/model.onnx"
  info "Downloading tokenizer.json (~700KB)..."
  run curl -sL -o "$MODEL_TOK" \
    "https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2/resolve/main/tokenizer.json"
  ok "ONNX models downloaded"
fi

# --- Step 8: RuVector bootstrap script --------------------------------------
step 8 "Creating RuVector bootstrap script"

writefile scripts/ruvector-bootstrap.mjs <<'EOF'
/**
 * RuVector Bootstrap — Patches global.fetch to serve local ONNX model files
 * and initializes the full RuVector stack.
 *
 * Usage:
 *   import { initRuVector } from "./scripts/ruvector-bootstrap.mjs";
 *   const rv = await initRuVector({ storagePath: ".ruvector/app.db" });
 *   // rv.db, rv.embedder, rv.engine, rv.router, rv.graph, rv.sona, rv.embed()
 */
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const MODEL_DIR = join(homedir(), ".ruvector", "models");
const MODEL_FILES = {
  "model.onnx": join(MODEL_DIR, "all-MiniLM-L6-v2-model.onnx"),
  "tokenizer.json": join(MODEL_DIR, "all-MiniLM-L6-v2-tokenizer.json"),
};

const originalFetch = globalThis.fetch;
globalThis.fetch = async function patchedFetch(url, options) {
  const urlStr = typeof url === "string" ? url : url?.toString?.() ?? "";
  if (urlStr.includes("huggingface.co") && urlStr.includes("all-MiniLM-L6-v2")) {
    for (const [filename, localPath] of Object.entries(MODEL_FILES)) {
      if (urlStr.includes(filename) && existsSync(localPath)) {
        const data = await readFile(localPath);
        const ct = filename.endsWith(".json") ? "application/json" : "application/octet-stream";
        return new Response(data, {
          status: 200,
          headers: { "content-type": ct, "content-length": String(data.length) },
        });
      }
    }
  }
  return originalFetch(url, options);
};

export async function initRuVector(opts = {}) {
  const { enableOnnx = true, embeddingDim = 384, storagePath } = opts;
  const ruvector = await import("ruvector");
  const result = {};

  result.db = new ruvector.VectorDB({
    dimensions: embeddingDim,
    storagePath,
    hnswConfig: { m: 16, efConstruction: 200, efSearch: 50 },
  });

  if (enableOnnx) {
    try {
      const emb = new ruvector.OnnxEmbedder();
      await emb.init();
      result.embedder = emb;
      console.log(`[ruvector] ONNX embedder ready (${emb.dimensions || embeddingDim}d)`);
    } catch (e) {
      console.warn(`[ruvector] ONNX embedder failed: ${e.message}`);
      result.embedder = null;
    }
  }

  result.embed = async (text) => {
    if (result.embedder) {
      const vec = await result.embedder.embed(text);
      return vec instanceof Float32Array ? vec : new Float32Array(vec);
    }
    throw new Error("ONNX embedder not available — check ~/.ruvector/models/");
  };

  try {
    result.engine = new ruvector.IntelligenceEngine({ enableOnnx: true });
    await result.engine.initialize?.();
  } catch { result.engine = null; }

  try {
    const { SemanticRouter } = await import("@ruvector/router");
    result.router = new SemanticRouter({ dimension: embeddingDim, threshold: 0.5 });
  } catch { result.router = null; }

  try {
    const { GraphDatabase } = await import("@ruvector/graph-node");
    result.graph = new GraphDatabase();
  } catch { result.graph = null; }

  try {
    const { SonaEngine } = await import("@ruvector/sona");
    result.sona = new SonaEngine(embeddingDim);
  } catch { result.sona = null; }

  return result;
}
EOF
ok "RuVector bootstrap created"

# --- Step 9: Ruflo (claude-flow) --------------------------------------------
step 9 "Installing Ruflo (claude-flow) orchestration"

info "Running ruflo init..."
if ! $DRY_RUN; then
  npx ruflo@latest init --topology hierarchical-mesh --memory hybrid 2>/dev/null \
    || npx claude-flow@latest init --topology hierarchical-mesh --memory hybrid 2>/dev/null \
    || warn "Ruflo/claude-flow init skipped (install manually: npm i -g ruflo)"
fi
ok "Ruflo step complete"

# --- Step 10: Superpowers ---------------------------------------------------
step 10 "Installing Superpowers skill system"

info "Running superpowers init..."
if ! $DRY_RUN; then
  npx superpowers@latest init 2>/dev/null \
    || warn "Superpowers init skipped (install manually: npm i -g superpowers)"
fi
ok "Superpowers step complete"

# --- Step 11: Paperclip Memory + lessons ------------------------------------
step 11 "Setting up Paperclip Memory and lessons file"

writefile tasks/lessons.md <<'EOF'
# Lessons Learned

Rules discovered through corrections. Review at session start. Update after every mistake.

---

## RuVector

- **DO NOT set distanceMetric explicitly** — crashes the native Rust binding. Use the default (cosine).
- **SemanticRouter wrapper is broken** — use `require("@ruvector/router")` directly.
- **SonaEngine constructor takes a single number** — `new SonaEngine(384)`, NOT an options object.
- **IntelligenceEngine.embed() (sync) always falls back to hash** — use `embedAsync()` or `rv.embed()`.
- **GraphDatabase nodes require `embedding: Float32Array(384)`** — cannot skip vectors.
- **ALWAYS use the bootstrap** for RuVector — without it, embeddings are n-gram (not semantic).

## Paperclip Subtree

- **Paperclip lives in `paperclip/`** — it is a git subtree, not a fork.
- **Update via**: `bash scripts/update-paperclip.sh` or `pnpm paperclip:update`
- **Never modify paperclip/ directly for upstream features** — make PRs to paperclipai/paperclip instead.
- **Your customizations go at the root level** — scripts/, .claude/, .ruvector/, etc.

## General

- **Search memory before starting work** — avoids repeat mistakes.
- **If approach fails after 2-3 attempts, stop and re-plan** — do not brute-force.
EOF

if ! $DRY_RUN; then
  mkdir -p .ruvector
fi
ok "Memory system scaffolded"

# --- Step 12: Claude Code hooks (settings.json) -----------------------------
step 12 "Configuring Claude Code hooks"

writefile .claude/settings.json <<'SETTINGS'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'exec node \"${CLAUDE_PROJECT_DIR:-.}/.claude/helpers/paperclip-memory.mjs\" observe'",
            "timeout": 15000
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'exec node \"${CLAUDE_PROJECT_DIR:-.}/.claude/helpers/paperclip-memory.mjs\" observe'",
            "timeout": 15000
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'exec node \"${CLAUDE_PROJECT_DIR:-.}/.claude/helpers/paperclip-memory.mjs\" context'",
            "timeout": 10000
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'exec node \"${CLAUDE_PROJECT_DIR:-.}/.claude/helpers/paperclip-memory.mjs\" summarize'",
            "timeout": 20000
          }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Bash(npx @claude-flow*)",
      "Bash(npx claude-flow*)",
      "Bash(node .claude/*)"
    ],
    "deny": [
      "Read(./.env)",
      "Read(./.env.*)"
    ]
  },
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
SETTINGS
ok "Claude Code settings.json written"

# --- Step 13: CLAUDE.md with subtree instructions ---------------------------
step 13 "Creating CLAUDE.md"

writefile CLAUDE.md <<'CLAUDEMD'
# Claude Code Configuration

## Project Structure

This is a clean private repo with Paperclip installed as a git subtree.

```
.
├── paperclip/           # Git subtree from paperclipai/paperclip (DO NOT fork)
│   ├── server/          # Express REST API
│   ├── ui/              # React 19 + Vite frontend
│   ├── packages/        # Drizzle ORM schema, shared types, adapters, plugins
│   ├── cli/             # CLI onboarding tool
│   └── ...
├── scripts/             # Bootstrap + update helpers (yours)
│   ├── ruvector-bootstrap.mjs
│   ├── update-paperclip.sh
│   └── bootstrap-clean-repo.sh
├── .claude/             # Claude Code hooks + memory (yours)
├── .ruvector/           # Vector storage (yours)
├── tasks/lessons.md     # Self-improvement loop (yours)
└── package.json         # Root workspace referencing paperclip/ packages
```

## Key Rules

- **Your code** goes at the root level (scripts/, .claude/, etc.)
- **Paperclip code** lives in `paperclip/` — modify it freely, but upstream
  features should be PRed to paperclipai/paperclip
- **Update Paperclip**: `bash scripts/update-paperclip.sh` or `pnpm paperclip:update`
- All pnpm workspace packages point into `paperclip/` (see pnpm-workspace.yaml)

## Build & Test

```bash
pnpm dev              # Dev mode (API + UI)
pnpm build            # Production build
pnpm test:run         # All tests
pnpm db:generate      # Generate DB migrations
pnpm db:migrate       # Apply migrations
pnpm paperclip:update # Pull latest upstream Paperclip
```

## Behavioral Rules

- ALWAYS read a file before editing it
- NEVER commit secrets, credentials, or .env files
- NEVER save working files to the root folder
- Search memory before starting work
- If an approach fails after 2-3 attempts, stop and re-plan
CLAUDEMD
ok "CLAUDE.md created"

# --- Step 14: Verify --------------------------------------------------------
step 14 "Running verification checks"

ERRORS=0

if ! $DRY_RUN; then
  if [[ -d "paperclip/server" && -d "paperclip/ui" && -d "paperclip/packages" ]]; then
    ok "Paperclip subtree present with server/, ui/, packages/"
  else
    warn "Paperclip subtree appears incomplete"
    ERRORS=$((ERRORS + 1))
  fi

  if [[ -d "node_modules" ]]; then
    ok "node_modules present"
  else
    warn "node_modules missing — run 'pnpm install'"
    ERRORS=$((ERRORS + 1))
  fi

  if [[ -d "node_modules/ruvector" ]]; then
    ok "ruvector package installed"
  else
    warn "ruvector not found in node_modules"
    ERRORS=$((ERRORS + 1))
  fi

  if [[ -f "$MODEL_ONNX" && -f "$MODEL_TOK" ]]; then
    ok "ONNX models present"
  else
    warn "ONNX models missing at $MODELS_DIR"
    ERRORS=$((ERRORS + 1))
  fi

  for f in package.json pnpm-workspace.yaml tsconfig.base.json tsconfig.json \
           scripts/ruvector-bootstrap.mjs scripts/update-paperclip.sh \
           tasks/lessons.md .claude/settings.json CLAUDE.md; do
    if [[ -f "$f" ]]; then
      ok "  $f"
    else
      warn "  $f missing"
      ERRORS=$((ERRORS + 1))
    fi
  done

  info "Running pnpm build..."
  if pnpm build 2>&1; then
    ok "Build succeeded"
  else
    warn "Build had issues (check output above)"
    ERRORS=$((ERRORS + 1))
  fi
else
  info "Skipping verification in dry-run mode"
fi

# --- Step 15: Commit everything ---------------------------------------------
step 15 "Creating commit with full setup"

if ! $DRY_RUN; then
  git add -A
  git commit --no-gpg-sign -m "Bootstrap: clean repo with Paperclip subtree

Paperclip installed as git subtree from paperclipai/paperclip.
RuVector (HNSW + ONNX), Ruflo, Superpowers, Paperclip Memory.
pnpm workspace references into paperclip/ subtree." 2>/dev/null \
  || git commit -m "Bootstrap: clean repo with Paperclip subtree

Paperclip installed as git subtree from paperclipai/paperclip.
RuVector (HNSW + ONNX), Ruflo, Superpowers, Paperclip Memory.
pnpm workspace references into paperclip/ subtree." 2>/dev/null \
  || warn "Git commit skipped (configure git user.name/user.email first)"
else
  printf "${YELLOW}[DRY-RUN]${NC} git add -A && git commit\n"
fi

# --- Done -------------------------------------------------------------------
printf "\n${GREEN}${BOLD}━━━ Bootstrap complete! ━━━${NC}\n\n"

if $DRY_RUN; then
  printf "(Dry run — no files were created)\n\n"
fi

printf "Your repo structure:\n"
printf "  ${CYAN}%s/${NC}\n" "$PROJECT_NAME"
printf "  ├── paperclip/           Paperclip (git subtree)\n"
printf "  ├── scripts/             Your bootstrap + update scripts\n"
printf "  ├── .claude/             Claude Code config + memory\n"
printf "  ├── .ruvector/           Vector storage\n"
printf "  ├── tasks/lessons.md     Self-improvement loop\n"
printf "  └── CLAUDE.md            Project instructions\n"
printf "\n"
printf "Next steps:\n"
printf "  ${CYAN}cd %s${NC}\n" "$PROJECT_NAME"
printf "  ${CYAN}pnpm dev${NC}                          # Start dev server\n"
printf "  ${CYAN}pnpm build${NC}                        # Production build\n"
printf "  ${CYAN}pnpm test:run${NC}                     # Run tests\n"
printf "  ${CYAN}pnpm paperclip:update${NC}             # Pull latest Paperclip\n"
printf "  ${CYAN}bash scripts/update-paperclip.sh${NC}  # Same, with conflict guidance\n"
printf "\n"
printf "To connect to GitHub:\n"
printf "  ${CYAN}git remote add origin git@github.com:YOU/%s.git${NC}\n" "$PROJECT_NAME"
printf "  ${CYAN}git push -u origin main${NC}\n"
printf "\n"

if (( ERRORS > 0 )); then
  warn "$ERRORS verification warning(s) — check output above"
else
  ok "All checks passed"
fi
