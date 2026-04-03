# Ruflo Adapter Template

This blueprint preserves the working `Claude + Ruflo (local)` setup that was validated in the Ruflo adapter test environment and turns it into a reusable source-of-truth asset.

## Purpose

Use this template when creating engineering-focused Paperclip companies that should:

- run `claude` locally
- require Ruflo MCP to be attached before execution
- seed a shallow CEO -> CTO -> Lead Engineer / QA org
- default technical roles to the hardened worker-home configuration

## Canonical Components

- Adapter implementation: `packages/adapters/ruflo-claude-local`
- Deployment notes: `docs/ruflo-claude-local.md`
- Worker setup scripts:
  - `scripts/setup-ruflo-claude-local.sh`
  - `scripts/smoke-ruflo-claude-local.sh`
- Importable company package:
  - `companies/ruflo-adapter-template/COMPANY.md`
  - `companies/ruflo-adapter-template/.paperclip.yaml`
  - `companies/ruflo-adapter-template/agents/`

## Default Org

- CEO
- CTO -> CEO
- Lead Engineer -> CTO
- QA -> CTO

## Intended Use

1. Ensure the worker machine has Claude Code and Ruflo installed.
2. Run `scripts/setup-ruflo-claude-local.sh`.
3. Run `scripts/smoke-ruflo-claude-local.sh`.
4. Import the package:

   ```sh
   paperclipai company import https://github.com/auitenbroek1/paperclipAU/tree/main/companies/ruflo-adapter-template --target new
   ```

5. Verify adapter config and then enable any desired heartbeats manually.

## Source-of-Truth Rule

If the live server state and the repo diverge, treat `companies/ruflo-adapter-template` as canonical after reconciliation.

The goal of this blueprint is to prevent future dependency on unversioned VPS runtime state or ad hoc UI-only configuration.
