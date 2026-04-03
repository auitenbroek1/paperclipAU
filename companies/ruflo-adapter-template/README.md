# Ruflo Adapter Template

Reusable Paperclip company template for engineering-focused companies that should start with a shallow org and Ruflo-enforced Claude local workers across the full leadership and technical chain.

## Org

- `CEO` — root company operator
- `CTO` — technical executive, reports to `CEO`
- `Lead Engineer` — primary implementation owner, reports to `CTO`
- `QA` — verification owner, reports to `CTO`

## Adapter Defaults

All default roles use `ruflo_claude_local` with:

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
- `CEO` defaults to `claude-opus-4-6`

## Import

From GitHub:

```sh
paperclipai company import https://github.com/auitenbroek1/paperclipAU/tree/main/companies/ruflo-adapter-template --target new
```

From a local checkout:

```sh
paperclipai company import ./companies/ruflo-adapter-template --target new
```

Preview first:

```sh
paperclipai company import ./companies/ruflo-adapter-template --target new --dry-run
```

## Notes

- Imported agents land with timer heartbeats disabled by default. Re-enable them only after adapter validation.
- `CEO`, `CTO`, `Lead Engineer`, and `QA` all use `ruflo_claude_local`.
- The canonical Lead Engineer engineering policy lives in `agents/lead-engineer/AGENTS.md`.
