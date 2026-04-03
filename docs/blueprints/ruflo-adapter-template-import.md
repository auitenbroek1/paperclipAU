---
title: Importing the Ruflo Adapter Template
summary: Step-by-step instructions for creating a new Paperclip company from the Ruflo Adapter Template package
---

This guide explains how to create a new Paperclip company from the reusable Ruflo template preserved in [`companies/ruflo-adapter-template`](/Users/aaronuitenbroek/Documents/Codex-stack-plan/paperclipAU-source/companies/ruflo-adapter-template/COMPANY.md).

Use this when you want a new company that starts with:

- the custom `Claude + Ruflo (local)` adapter for technical roles
- the preserved Lead Engineer engineering instructions
- a shallow default org
- versioned defaults that do not need to be rebuilt manually in the UI

## Source of Truth

Canonical package root:

- `companies/ruflo-adapter-template/COMPANY.md`

Canonical vendor config:

- `companies/ruflo-adapter-template/.paperclip.yaml`

Canonical role bundles:

- `companies/ruflo-adapter-template/agents/ceo/AGENTS.md`
- `companies/ruflo-adapter-template/agents/cto/AGENTS.md`
- `companies/ruflo-adapter-template/agents/lead-engineer/AGENTS.md`
- `companies/ruflo-adapter-template/agents/qa/AGENTS.md`

Supporting adapter files:

- `docs/ruflo-claude-local.md`
- `packages/adapters/ruflo-claude-local`
- `scripts/setup-ruflo-claude-local.sh`
- `scripts/smoke-ruflo-claude-local.sh`

## What the Template Creates

Default org:

- `CEO`
- `CTO` reporting to `CEO`
- `Lead Engineer` reporting to `CTO`
- `QA` reporting to `CTO`

Adapter defaults:

- `CEO` uses `claude_local`
- `CTO` uses `ruflo_claude_local`
- `Lead Engineer` uses `ruflo_claude_local`
- `QA` uses `ruflo_claude_local`

Technical worker defaults:

- `command: claude`
- `rufloRequired: true`
- `rufloMcpServerName: ruflo`
- `claudeConfigHome: /srv/paperclip/claude-worker-home`
- `HOME=/srv/paperclip/claude-worker-home`
- `XDG_CONFIG_HOME=/srv/paperclip/claude-worker-home/.config`
- `dangerouslySkipPermissions: true`
- `maxTurnsPerRun: 300`
- `timeoutSec: 0`
- `graceSec: 15`
- timer heartbeats disabled on import

## Preconditions

Do not import this template until these are true.

### 1. The target Paperclip build includes the custom adapter

The target deployment must be running a build that includes `ruflo_claude_local`.

If the target Paperclip instance does not know about `ruflo_claude_local`, the import will fail or the imported agents will not run correctly.

### 2. The worker host has Claude and Ruflo installed

For any host that will run `CTO`, `Lead Engineer`, or `QA`, the machine must have:

- Claude Code CLI installed
- Ruflo installed
- Ruflo attached to Claude MCP under the expected MCP server name

### 3. The worker home path matches the template or is intentionally overridden

The template assumes:

- `HOME=/srv/paperclip/claude-worker-home`
- `XDG_CONFIG_HOME=/srv/paperclip/claude-worker-home/.config`

If your deployment uses a different worker home, update the template before import or edit the imported agents afterward.

## Recommended Workflow

1. Ensure the target Paperclip server is running code from `main`.
2. Ensure the worker host has Claude + Ruflo configured.
3. Run the import as a dry run first.
4. Review the preview carefully.
5. Run the real import.
6. Verify the imported company in the UI.
7. Enable heartbeats only after adapter verification.

## Copy/Paste Commands

### Import from GitHub

Dry run:

```sh
paperclipai company import \
  https://github.com/auitenbroek1/paperclipAU/tree/main/companies/ruflo-adapter-template \
  --target new \
  --dry-run
```

Real import:

```sh
paperclipai company import \
  https://github.com/auitenbroek1/paperclipAU/tree/main/companies/ruflo-adapter-template \
  --target new \
  --yes
```

Import with a custom company name:

```sh
paperclipai company import \
  https://github.com/auitenbroek1/paperclipAU/tree/main/companies/ruflo-adapter-template \
  --target new \
  --new-company-name "My New Company" \
  --yes
```

JSON output:

```sh
paperclipai company import \
  https://github.com/auitenbroek1/paperclipAU/tree/main/companies/ruflo-adapter-template \
  --target new \
  --yes \
  --json
```

### Import from a local checkout

Dry run:

```sh
paperclipai company import \
  ./companies/ruflo-adapter-template \
  --target new \
  --dry-run
```

Real import:

```sh
paperclipai company import \
  ./companies/ruflo-adapter-template \
  --target new \
  --yes
```

## Worker Setup Commands

Run these on a host that will execute the technical workers:

```sh
./scripts/setup-ruflo-claude-local.sh
./scripts/smoke-ruflo-claude-local.sh
```

If the smoke test fails, do not proceed to live runs for `CTO`, `Lead Engineer`, or `QA`.

## Post-Import Verification Checklist

After import, verify these items in the Paperclip UI.

### Company structure

Confirm the org chart is:

- `CEO`
- `CTO -> CEO`
- `Lead Engineer -> CTO`
- `QA -> CTO`

### Adapter configuration

For `CTO`, `Lead Engineer`, and `QA`, confirm:

- adapter type is `Claude + Ruflo (local)`
- command is `claude`
- skip permissions is enabled
- max turns per run is `300`
- timeout is `0`
- interrupt grace is `15`
- `HOME=/srv/paperclip/claude-worker-home`
- `XDG_CONFIG_HOME=/srv/paperclip/claude-worker-home/.config`

### Instructions

Confirm:

- `Lead Engineer` contains the preserved engineering policy
- `CTO` contains the technical coordination policy
- `QA` contains the verification policy
- `CEO` contains the delegation-oriented executive policy

### Heartbeats

Imported timer heartbeats should be disabled by default.

Do not enable them until:

- adapter config is verified
- the worker host passes the Ruflo smoke test
- the company goal and any custom instructions are set

## Recommended First Customizations

After import, customize at least:

1. company name
2. company description
3. company goal
4. CEO instructions for the actual business
5. any project-specific technical context
6. any environment-specific worker home paths if they differ from `/srv/paperclip/claude-worker-home`

## Troubleshooting

### Error: unknown adapter type `ruflo_claude_local`

Cause:

- the target Paperclip deployment is not running the custom adapter build

Action:

1. deploy `paperclipAU/main`
2. confirm the adapter appears in the new-agent UI
3. retry the import

### Error: Ruflo required missing

Cause:

- Claude can run, but Ruflo is not correctly attached or detectable through Claude MCP

Action:

1. run the setup script
2. run the smoke test
3. verify `claude mcp list` shows the Ruflo MCP server
4. retry the agent run

### Imported agents exist but do not run correctly

Cause:

- adapter config imported successfully, but the host environment is not actually prepared

Action:

1. verify worker host install
2. verify `HOME` and `XDG_CONFIG_HOME`
3. verify Claude CLI availability
4. verify Ruflo MCP registration

### The template imports but needs a different org shape

Cause:

- the default template is opinionated

Action:

1. import the template
2. modify reporting lines in the UI
3. change agent instructions as needed
4. if the new pattern becomes standard, update the template in `main`

## Handoff Summary

If you hand this process to another operator or another AI agent, they need only this:

1. Source package:
   - `https://github.com/auitenbroek1/paperclipAU/tree/main/companies/ruflo-adapter-template`
2. Import command:

```sh
paperclipai company import \
  https://github.com/auitenbroek1/paperclipAU/tree/main/companies/ruflo-adapter-template \
  --target new \
  --dry-run
```

3. The target Paperclip build must already support `ruflo_claude_local`.
4. The worker host must already have Claude + Ruflo configured.
5. After import, verify org chart, adapters, env vars, instructions, and disabled heartbeats before enabling anything.
