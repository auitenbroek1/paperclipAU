#!/usr/bin/env bash
# ============================================================================
# bootstrap-paperclip.sh — Create a new Paperclip AI Company Platform project
# ============================================================================
#
# Reproduces the full paperclipAU stack from scratch:
#   Express 5 + React 19 + Drizzle ORM + PGlite + RuVector + Ruflo +
#   Superpowers + Paperclip Memory + Claude Code hooks
#
# Usage:
#   bash bootstrap-paperclip.sh <project-name>
#   bash bootstrap-paperclip.sh <project-name> --dry-run
#
# Prerequisites: Node.js >=20, pnpm >=9, git, curl
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

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
  esac
done

if [[ -z "$PROJECT_NAME" || "$PROJECT_NAME" == --* ]]; then
  echo "Usage: bash bootstrap-paperclip.sh <project-name> [--dry-run]"
  exit 1
fi

# Write a file (skipped in dry-run, logged either way)
writefile() {
  local filepath="$1"
  if $DRY_RUN; then
    printf "${YELLOW}[DRY-RUN]${NC} write %s\n" "$filepath"
    cat > /dev/null  # consume stdin
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

# --- Step 2: Git init -------------------------------------------------------
step 2 "Initializing git repository"

run git init

# --- Step 3: Root config files ----------------------------------------------
step 3 "Creating root configuration files"

info "Writing package.json"
writefile package.json <<EOF
{
  "name": "${PROJECT_NAME}",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "pnpm --filter @${PROJECT_NAME}/server dev:watch",
    "dev:server": "pnpm --filter @${PROJECT_NAME}/server dev",
    "dev:ui": "pnpm --filter @${PROJECT_NAME}/ui dev",
    "build": "pnpm -r build",
    "typecheck": "pnpm -r typecheck",
    "test": "vitest",
    "test:run": "vitest run",
    "db:generate": "pnpm --filter @${PROJECT_NAME}/db generate",
    "db:migrate": "pnpm --filter @${PROJECT_NAME}/db migrate"
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

info "Writing pnpm-workspace.yaml"
writefile pnpm-workspace.yaml <<'EOF'
packages:
  - packages/*
  - packages/adapters/*
  - packages/plugins/*
  - packages/plugins/examples/*
  - server
  - ui
  - cli
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

info "Writing vitest.config.ts"
writefile vitest.config.ts <<'EOF'
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    projects: ["packages/db", "server", "ui"],
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

# --- Step 4: Monorepo package scaffolds -------------------------------------
step 4 "Scaffolding monorepo packages"

# packages/shared
info "Creating packages/shared"
writefile packages/shared/package.json <<EOF
{
  "name": "@${PROJECT_NAME}/shared",
  "version": "0.1.0",
  "type": "module",
  "exports": { ".": "./src/index.ts", "./*": "./src/*.ts" },
  "scripts": { "build": "tsc", "typecheck": "tsc --noEmit" },
  "dependencies": { "zod": "^3.24.2" },
  "devDependencies": { "typescript": "^5.7.3" }
}
EOF
writefile packages/shared/tsconfig.json <<'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "outDir": "dist", "rootDir": "src" },
  "include": ["src"]
}
EOF
writefile packages/shared/src/index.ts <<'EOF'
// Shared types and schemas
export {};
EOF

# packages/db
info "Creating packages/db"
writefile packages/db/package.json <<EOF
{
  "name": "@${PROJECT_NAME}/db",
  "version": "0.1.0",
  "type": "module",
  "exports": { ".": "./src/index.ts", "./*": "./src/*.ts" },
  "scripts": {
    "build": "tsc && cp -r src/migrations dist/migrations 2>/dev/null || true",
    "typecheck": "tsc --noEmit",
    "generate": "tsc -p tsconfig.json && drizzle-kit generate",
    "migrate": "tsx src/migrate.ts"
  },
  "dependencies": {
    "@${PROJECT_NAME}/shared": "workspace:*",
    "drizzle-orm": "^0.38.4",
    "postgres": "^3.4.5"
  },
  "devDependencies": {
    "drizzle-kit": "^0.31.9",
    "tsx": "^4.19.2",
    "typescript": "^5.7.3",
    "vitest": "^3.0.5"
  }
}
EOF
writefile packages/db/tsconfig.json <<'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "outDir": "dist", "rootDir": "src" },
  "include": ["src"]
}
EOF
writefile packages/db/drizzle.config.ts <<'EOF'
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./dist/schema/*.js",
  out: "./src/migrations",
  dialect: "postgresql",
  dbCredentials: { url: process.env.DATABASE_URL! },
});
EOF
writefile packages/db/src/index.ts <<'EOF'
// Database exports
export {};
EOF

# packages/adapter-utils
info "Creating packages/adapter-utils"
writefile packages/adapter-utils/package.json <<EOF
{
  "name": "@${PROJECT_NAME}/adapter-utils",
  "version": "0.1.0",
  "type": "module",
  "exports": { ".": "./src/index.ts", "./*": "./src/*.ts" },
  "scripts": { "build": "tsc", "typecheck": "tsc --noEmit" },
  "devDependencies": { "typescript": "^5.7.3" }
}
EOF
writefile packages/adapter-utils/tsconfig.json <<'EOF'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "outDir": "dist", "rootDir": "src" },
  "include": ["src"]
}
EOF
writefile packages/adapter-utils/src/index.ts <<'EOF'
export {};
EOF

# --- Step 5: Server package -------------------------------------------------
step 5 "Scaffolding Express 5 server"

writefile server/package.json <<EOF
{
  "name": "@${PROJECT_NAME}/server",
  "version": "0.1.0",
  "type": "module",
  "exports": { ".": "./src/index.ts" },
  "scripts": {
    "dev": "tsx src/index.ts",
    "dev:watch": "tsx watch src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@${PROJECT_NAME}/db": "workspace:*",
    "@${PROJECT_NAME}/shared": "workspace:*",
    "dotenv": "^17.0.1",
    "drizzle-orm": "^0.38.4",
    "express": "^5.1.0",
    "pino": "^9.6.0",
    "pino-http": "^10.4.0",
    "pino-pretty": "^13.1.3",
    "ws": "^8.19.0",
    "zod": "^3.24.2"
  },
  "devDependencies": {
    "@types/express": "^5.0.0",
    "@types/express-serve-static-core": "^5.0.0",
    "@types/node": "^24.6.0",
    "@types/ws": "^8.18.1",
    "supertest": "^7.0.0",
    "tsx": "^4.19.2",
    "typescript": "^5.7.3",
    "vitest": "^3.0.5"
  }
}
EOF
writefile server/tsconfig.json <<'EOF'
{
  "extends": "../tsconfig.base.json",
  "compilerOptions": { "outDir": "dist", "rootDir": "src" },
  "include": ["src"],
  "exclude": ["src/__tests__"]
}
EOF
if ! $DRY_RUN; then
  mkdir -p server/src/{routes,services,adapters,middleware}
fi
writefile server/src/index.ts <<'EOF'
import express, { type Express } from "express";

const app: Express = express();
const PORT = process.env.PORT ? parseInt(process.env.PORT) : 3100;

app.use(express.json());

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`[server] listening on http://localhost:${PORT}`);
});

export default app;
EOF

# --- Step 6: UI package -----------------------------------------------------
step 6 "Scaffolding React 19 + Vite frontend"

if ! $DRY_RUN; then
  mkdir -p ui/src/{pages,components,api,hooks}
fi
writefile ui/package.json <<EOF
{
  "name": "@${PROJECT_NAME}/ui",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "typecheck": "tsc -b"
  },
  "dependencies": {
    "@${PROJECT_NAME}/shared": "workspace:*",
    "@radix-ui/react-slot": "^1.2.4",
    "@tanstack/react-query": "^5.90.21",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "lucide-react": "^0.574.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^7.1.5",
    "tailwind-merge": "^3.4.1"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.0.7",
    "@types/react": "^19.0.8",
    "@types/react-dom": "^19.0.3",
    "@vitejs/plugin-react": "^4.3.4",
    "tailwindcss": "^4.0.7",
    "typescript": "^5.7.3",
    "vite": "^6.1.0",
    "vitest": "^3.0.5"
  }
}
EOF
writefile ui/tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "baseUrl": ".",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src"]
}
EOF
writefile ui/vite.config.ts <<'EOF'
import path from "path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
  server: {
    port: 5173,
    proxy: {
      "/api": { target: "http://localhost:3100", ws: true },
    },
  },
});
EOF
writefile ui/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${PROJECT_NAME}</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF
writefile ui/src/main.tsx <<'EOF'
import React from "react";
import ReactDOM from "react-dom/client";

function App() {
  return <div><h1>Welcome</h1><p>Your Paperclip stack is ready.</p></div>;
}

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode><App /></React.StrictMode>
);
EOF

# --- Step 7: Root tsconfig with references ----------------------------------
step 7 "Creating root tsconfig project references"

writefile tsconfig.json <<'EOF'
{
  "extends": "./tsconfig.base.json",
  "files": [],
  "references": [
    { "path": "./packages/adapter-utils" },
    { "path": "./packages/shared" },
    { "path": "./packages/db" },
    { "path": "./server" },
    { "path": "./ui" }
  ]
}
EOF

# --- Step 8: Install dependencies -------------------------------------------
step 8 "Installing npm dependencies (this may take a few minutes)"

run pnpm install
ok "Dependencies installed"

# --- Step 9: RuVector ONNX models -------------------------------------------
step 9 "Downloading RuVector ONNX models (all-MiniLM-L6-v2)"

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

# --- Step 10: RuVector bootstrap script -------------------------------------
step 10 "Creating RuVector bootstrap script"

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

  // VectorDB — do NOT set distanceMetric explicitly (crashes native binding)
  result.db = new ruvector.VectorDB({
    dimensions: embeddingDim,
    storagePath,
    hnswConfig: { m: 16, efConstruction: 200, efSearch: 50 },
  });

  // ONNX Embedder
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

  // Helper: text → Float32Array (ONNX semantic, not n-gram)
  result.embed = async (text) => {
    if (result.embedder) {
      const vec = await result.embedder.embed(text);
      return vec instanceof Float32Array ? vec : new Float32Array(vec);
    }
    throw new Error("ONNX embedder not available — check ~/.ruvector/models/");
  };

  // IntelligenceEngine
  try {
    result.engine = new ruvector.IntelligenceEngine({ enableOnnx: true });
    await result.engine.initialize?.();
  } catch { result.engine = null; }

  // SemanticRouter — use @ruvector/router directly (wrapper is broken)
  try {
    const { SemanticRouter } = await import("@ruvector/router");
    result.router = new SemanticRouter({ dimension: embeddingDim, threshold: 0.5 });
  } catch { result.router = null; }

  // GraphDatabase — nodes require embedding: Float32Array(384)
  try {
    const { GraphDatabase } = await import("@ruvector/graph-node");
    result.graph = new GraphDatabase();
  } catch { result.graph = null; }

  // SonaEngine — constructor takes single number, NOT options object
  try {
    const { SonaEngine } = await import("@ruvector/sona");
    result.sona = new SonaEngine(embeddingDim);
  } catch { result.sona = null; }

  return result;
}
EOF
ok "RuVector bootstrap created"

# --- Step 11: Ruflo (claude-flow) -------------------------------------------
step 11 "Installing Ruflo (claude-flow) orchestration"

info "Running ruflo init (may be skipped if not globally available)..."
if ! $DRY_RUN; then
  npx ruflo@latest init --topology hierarchical-mesh --memory hybrid 2>/dev/null \
    || npx claude-flow@latest init --topology hierarchical-mesh --memory hybrid 2>/dev/null \
    || warn "Ruflo/claude-flow init skipped (install manually: npm i -g ruflo)"
fi
ok "Ruflo step complete"

# --- Step 12: Superpowers ---------------------------------------------------
step 12 "Installing Superpowers skill system"

info "Running superpowers init..."
if ! $DRY_RUN; then
  npx superpowers@latest init 2>/dev/null \
    || warn "Superpowers init skipped (install manually: npm i -g superpowers)"
fi
ok "Superpowers step complete"

# --- Step 13: Paperclip Memory + lessons ------------------------------------
step 13 "Setting up Paperclip Memory and lessons file"

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

## General

- **Search memory before starting work** — avoids repeat mistakes.
- **If approach fails after 2-3 attempts, stop and re-plan** — do not brute-force.
EOF

if ! $DRY_RUN; then
  mkdir -p .ruvector
fi
ok "Memory system scaffolded"

# --- Step 14: Claude Code hooks (settings.json) -----------------------------
step 14 "Configuring Claude Code hooks"

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

# --- Step 15: Verify --------------------------------------------------------
step 15 "Running verification checks"

ERRORS=0

if ! $DRY_RUN; then
  # Check node_modules
  if [[ -d "node_modules" ]]; then
    ok "node_modules present"
  else
    warn "node_modules missing — run 'pnpm install'"
    ERRORS=$((ERRORS + 1))
  fi

  # Check ruvector
  if [[ -d "node_modules/ruvector" ]]; then
    ok "ruvector package installed"
  else
    warn "ruvector not found in node_modules"
    ERRORS=$((ERRORS + 1))
  fi

  # Check ONNX models
  if [[ -f "$MODEL_ONNX" && -f "$MODEL_TOK" ]]; then
    ok "ONNX models present"
  else
    warn "ONNX models missing at $MODELS_DIR"
    ERRORS=$((ERRORS + 1))
  fi

  # Check key files exist
  for f in package.json pnpm-workspace.yaml tsconfig.base.json tsconfig.json \
           server/package.json server/src/index.ts \
           ui/package.json ui/src/main.tsx ui/vite.config.ts \
           packages/shared/package.json packages/db/package.json \
           scripts/ruvector-bootstrap.mjs tasks/lessons.md \
           .claude/settings.json; do
    if [[ -f "$f" ]]; then
      ok "  $f"
    else
      warn "  $f missing"
      ERRORS=$((ERRORS + 1))
    fi
  done

  # Try build
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

# --- Step 16: Initial commit ------------------------------------------------
step 16 "Creating initial git commit"

if ! $DRY_RUN; then
  git add -A
  git commit --no-gpg-sign -m "Initial scaffold: Paperclip AI Company Platform

Stack: Express 5, React 19, Drizzle ORM, Tailwind CSS 4,
RuVector (HNSW + ONNX), Ruflo, Superpowers, Paperclip Memory.
pnpm monorepo with TypeScript project references." 2>/dev/null \
  || git commit -m "Initial scaffold: Paperclip AI Company Platform

Stack: Express 5, React 19, Drizzle ORM, Tailwind CSS 4,
RuVector (HNSW + ONNX), Ruflo, Superpowers, Paperclip Memory.
pnpm monorepo with TypeScript project references." 2>/dev/null \
  || warn "Git commit skipped (configure git user.name/user.email first)"
else
  printf "${YELLOW}[DRY-RUN]${NC} git add -A && git commit\n"
fi

# --- Done -------------------------------------------------------------------
printf "\n${GREEN}${BOLD}━━━ Bootstrap complete! ━━━${NC}\n\n"

if $DRY_RUN; then
  printf "(Dry run — no files were created)\n\n"
fi

printf "Next steps:\n"
printf "  ${CYAN}cd %s${NC}\n" "$PROJECT_NAME"
printf "  ${CYAN}pnpm dev${NC}           # Start dev server\n"
printf "  ${CYAN}pnpm build${NC}         # Production build\n"
printf "  ${CYAN}pnpm test:run${NC}      # Run tests\n"
printf "\n"
printf "Key directories:\n"
printf "  server/src/              Express 5 API\n"
printf "  ui/src/                  React 19 + Vite frontend\n"
printf "  packages/db/             Drizzle ORM schema\n"
printf "  packages/shared/         Shared TypeScript types\n"
printf "  packages/adapter-utils/  Adapter utilities\n"
printf "  scripts/                 RuVector bootstrap + helpers\n"
printf "  .claude/                 Claude Code hooks + memory\n"
printf "  .ruvector/               Vector storage (persistent)\n"
printf "  tasks/lessons.md         Self-improvement loop\n"
printf "\n"

if (( ERRORS > 0 )); then
  warn "$ERRORS verification warning(s) — check output above"
else
  ok "All checks passed"
fi
