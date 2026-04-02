# Ruflo Adapter Template

This blueprint preserves the working `Claude + Ruflo (local)` setup that was validated in the Ruflo adapter test environment and turns it into a reusable source-of-truth asset.

## Purpose

Use this blueprint when creating engineering-focused Paperclip agents that should:

- run `claude` locally
- require Ruflo MCP to be attached before execution
- use the managed engineering instruction bundle
- default to the hardened worker-home configuration

## Canonical Components

- Adapter implementation: `packages/adapters/ruflo-claude-local`
- Deployment notes: `docs/ruflo-claude-local.md`
- Worker setup scripts:
  - `scripts/setup-ruflo-claude-local.sh`
  - `scripts/smoke-ruflo-claude-local.sh`
- Canonical engineering instruction asset:
  - `server/src/onboarding-assets/engineering/AGENTS.md`
- Reusable seed data:
  - `blueprints/ruflo-adapter-template/company.json`
  - `blueprints/ruflo-adapter-template/agents/lead-engineer/agent.json`

## Canonical Lead Engineer Defaults

- Adapter type: `ruflo_claude_local`
- Command: `claude`
- Ruflo required: `true`
- Ruflo MCP server name: `ruflo`
- Claude worker home: `/srv/paperclip/claude-worker-home`
- `HOME=/srv/paperclip/claude-worker-home`
- `XDG_CONFIG_HOME=/srv/paperclip/claude-worker-home/.config`
- Skip permissions: `true`
- Max turns per run: `300`
- Timeout seconds: `0`
- Grace seconds: `15`
- Instructions bundle mode: `managed`
- Instructions entry file: `AGENTS.md`
- Heartbeat enabled by default: `false`
- Can create agents by default: `false`

## Intended Use

1. Ensure the worker machine has Claude Code and Ruflo installed.
2. Run `scripts/setup-ruflo-claude-local.sh`.
3. Run `scripts/smoke-ruflo-claude-local.sh`.
4. Create the agent using the config in `blueprints/ruflo-adapter-template/agents/lead-engineer/agent.json`.
5. Materialize the managed instructions from `server/src/onboarding-assets/engineering/AGENTS.md`.

## Source-of-Truth Rule

If the live server state and the repo diverge, treat this repo as canonical after reconciliation.

The goal of this blueprint is to prevent future dependency on unversioned VPS runtime state.
