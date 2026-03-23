#!/usr/bin/env bash
# ============================================================================
# versions.sh — Show versions of all Paperclip stack components
# ============================================================================
# Usage: bash scripts/versions.sh
# ============================================================================

set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

ok()   { printf "  ${GREEN}%-30s${NC} %s\n" "$1" "$2"; }
miss() { printf "  ${RED}%-30s${NC} %s\n" "$1" "${2:-not found}"; }
warn() { printf "  ${YELLOW}%-30s${NC} %s\n" "$1" "$2"; }

printf "\n${BOLD}Paperclip AI Company Platform — Version Report${NC}\n"
printf "${DIM}$(date -u '+%Y-%m-%d %H:%M:%S UTC')${NC}\n\n"

# ── System Prerequisites ────────────────────────────────────────────────────
printf "${CYAN}System Prerequisites${NC}\n"

if command -v node &>/dev/null; then
  ok "Node.js" "$(node -v)"
else
  miss "Node.js"
fi

if command -v pnpm &>/dev/null; then
  ok "pnpm" "v$(pnpm -v)"
else
  miss "pnpm"
fi

if command -v git &>/dev/null; then
  ok "git" "$(git --version | sed 's/git version //')"
else
  miss "git"
fi

if command -v curl &>/dev/null; then
  ok "curl" "$(curl --version 2>/dev/null | head -1 | awk '{print $2}')"
else
  miss "curl"
fi

# ── Claude Code ─────────────────────────────────────────────────────────────
printf "\n${CYAN}Claude Code${NC}\n"

if command -v claude &>/dev/null; then
  ok "claude" "$(claude --version 2>/dev/null || echo 'installed (version unknown)')"
else
  miss "claude" "not installed (npm i -g @anthropic-ai/claude-code)"
fi

# ── npm Root Dependencies ───────────────────────────────────────────────────
printf "\n${CYAN}RuVector & AI Packages${NC}\n"

pkg_version() {
  local pkg="$1"
  local label="${2:-$1}"
  local ver
  # Try direct require (works for root and hoisted packages)
  ver=$(node -e "try{console.log(require('${pkg}/package.json').version)}catch{}" 2>/dev/null)
  if [[ -z "$ver" ]]; then
    # Search .pnpm store (pnpm strict mode symlinks packages here)
    local pnpm_pkg
    pnpm_pkg=$(ls -d node_modules/.pnpm/${pkg//\//@}@*/node_modules/${pkg}/package.json 2>/dev/null \
      || ls -d node_modules/.pnpm/*${pkg##*/}*/node_modules/${pkg}/package.json 2>/dev/null)
    pnpm_pkg=$(echo "$pnpm_pkg" | head -1)
    if [[ -n "$pnpm_pkg" && -f "$pnpm_pkg" ]]; then
      ver=$(node -e "console.log(require('./${pnpm_pkg}').version)" 2>/dev/null)
    fi
  fi
  if [[ -z "$ver" ]]; then
    # Check if declared in any workspace package.json (but not yet installed)
    local declared
    declared=$(grep -rl "\"${pkg}\"" server/package.json ui/package.json packages/*/package.json 2>/dev/null | head -1)
    if [[ -n "$declared" ]]; then
      local spec
      spec=$(node -e "const p=require('./${declared}');const d={...p.dependencies,...p.devDependencies};console.log(d['${pkg}']||'')" 2>/dev/null)
      if [[ -n "$spec" ]]; then
        warn "$label" "${spec} (declared in $(basename $(dirname $declared)), not installed)"
        return
      fi
    fi
  fi
  if [[ -n "$ver" ]]; then
    ok "$label" "v${ver}"
  else
    miss "$label"
  fi
}

pkg_version "ruvector"              "ruvector"
pkg_version "@ruvector/router"      "@ruvector/router"
pkg_version "@ruvector/graph-node"  "@ruvector/graph-node"
pkg_version "@ruvector/cluster"     "@ruvector/cluster"
pkg_version "onnxruntime-node"      "onnxruntime-node"

# Check for optional native packages (may be transitive)
for pkg in "@ruvector/core" "@ruvector/sona" "@ruvector/gnn" "@ruvector/attention" "@ruvector/rvf"; do
  pkg_json="node_modules/${pkg}/package.json"
  if [[ -f "$pkg_json" ]]; then
    ver=$(node -e "console.log(require('./${pkg_json}').version)" 2>/dev/null)
    ok "$pkg" "v${ver}"
  fi
done

# ── ONNX Models ─────────────────────────────────────────────────────────────
printf "\n${CYAN}ONNX Models (~/.ruvector/models/)${NC}\n"

MODELS_DIR="$HOME/.ruvector/models"
MODEL_ONNX="$MODELS_DIR/all-MiniLM-L6-v2-model.onnx"
MODEL_TOK="$MODELS_DIR/all-MiniLM-L6-v2-tokenizer.json"

if [[ -f "$MODEL_ONNX" ]]; then
  size=$(du -h "$MODEL_ONNX" 2>/dev/null | awk '{print $1}')
  ok "model.onnx" "present (${size})"
else
  miss "model.onnx"
fi

if [[ -f "$MODEL_TOK" ]]; then
  size=$(du -h "$MODEL_TOK" 2>/dev/null | awk '{print $1}')
  ok "tokenizer.json" "present (${size})"
else
  miss "tokenizer.json"
fi

# ── Framework Packages ──────────────────────────────────────────────────────
printf "\n${CYAN}Framework Packages${NC}\n"

pkg_version "express"              "Express"
pkg_version "react"                "React"
pkg_version "react-dom"            "React DOM"
pkg_version "vite"                 "Vite"
pkg_version "tailwindcss"          "Tailwind CSS"
pkg_version "drizzle-orm"          "Drizzle ORM"
pkg_version "drizzle-kit"          "Drizzle Kit"
pkg_version "typescript"           "TypeScript"
pkg_version "vitest"               "Vitest"
pkg_version "zod"                  "Zod"
pkg_version "@tanstack/react-query" "TanStack Query"
pkg_version "pino"                 "Pino"

# ── Orchestration Tools ─────────────────────────────────────────────────────
printf "\n${CYAN}Orchestration & Skills${NC}\n"

if [[ -f ".claude-flow/config.json" ]] || [[ -f "claude-flow.json" ]]; then
  if command -v ruflo &>/dev/null; then
    ok "Ruflo (claude-flow)" "$(ruflo --version 2>/dev/null || echo 'config present')"
  else
    ok "Ruflo (claude-flow)" "config present (npx ruflo@latest ...)"
  fi
else
  warn "Ruflo (claude-flow)" "not initialized (npx ruflo@latest init)"
fi

if [[ -d ".claude/skills" ]]; then
  skill_count=$(find .claude/skills -name "*.md" -type f 2>/dev/null | wc -l)
  ok "Superpowers skills" "${skill_count} skills installed"
else
  warn "Superpowers" "not initialized (npx superpowers@latest init)"
fi

# ── Paperclip-Specific ──────────────────────────────────────────────────────
printf "\n${CYAN}Paperclip Components${NC}\n"

if [[ -f ".claude/helpers/paperclip-memory.mjs" ]]; then
  ok "Paperclip Memory" "installed"
else
  miss "Paperclip Memory" ".claude/helpers/paperclip-memory.mjs missing"
fi

if [[ -f "scripts/ruvector-bootstrap.mjs" ]]; then
  ok "RuVector Bootstrap" "installed"
else
  miss "RuVector Bootstrap" "scripts/ruvector-bootstrap.mjs missing"
fi

if [[ -f "tasks/lessons.md" ]]; then
  lesson_count=$(grep -c '^\- \*\*' tasks/lessons.md 2>/dev/null || echo 0)
  ok "Lessons file" "${lesson_count} rules"
else
  miss "Lessons file" "tasks/lessons.md missing"
fi

if [[ -f ".claude/settings.json" ]]; then
  ok "Claude Code hooks" "configured"
else
  warn "Claude Code hooks" ".claude/settings.json missing"
fi

if [[ -d ".ruvector" ]]; then
  ok "Vector storage dir" ".ruvector/ present"
else
  warn "Vector storage dir" ".ruvector/ missing"
fi

# ── Summary ─────────────────────────────────────────────────────────────────
printf "\n${DIM}─────────────────────────────────────────────────${NC}\n"
printf "${DIM}Run 'pnpm build' to verify packages compile correctly.${NC}\n"
printf "${DIM}Run 'pnpm test:run' to verify functional correctness.${NC}\n\n"
