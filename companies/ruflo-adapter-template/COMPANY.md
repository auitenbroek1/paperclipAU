---
name: Ruflo Adapter Template
description: Engineering-first Paperclip company template with CEO, CTO, Lead Engineer, and QA plus Ruflo-enforced Claude local defaults for the technical org
slug: ruflo-adapter-template
schema: agentcompanies/v1
version: 1.0.0
license: MIT
authors:
  - name: Aaron Uitenbroek
goals:
  - Create engineering companies that default technical execution to Claude plus Ruflo local workers
  - Keep the org shallow and reproducible
---

Ruflo Adapter Template is a reusable Paperclip company package for engineering-heavy companies.

It seeds a shallow default org:

- CEO
- CTO reporting to CEO
- Lead Engineer reporting to CTO
- QA reporting to CTO

The technical org defaults to the custom `ruflo_claude_local` adapter so imported companies recreate the validated `Claude + Ruflo (local)` setup directly from package data instead of manual UI configuration.

Use this package when you want:

- a standard CEO + CTO + Lead Engineer + QA starting structure
- Ruflo-required Claude workers for technical roles
- the canonical Lead Engineer engineering policy preserved in version control
- a clean import target from GitHub or a local directory

Import from this subfolder with:

```sh
paperclipai company import https://github.com/auitenbroek1/paperclipAU/tree/main/companies/ruflo-adapter-template --target new
```
