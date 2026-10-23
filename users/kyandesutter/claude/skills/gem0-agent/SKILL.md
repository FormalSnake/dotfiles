---
name: gem0-agent
description: Work in Gem0 (gem0.dev headless CMS) as the signed-in user through an agent token (gem_pat_...) on the Gem0 admin-api - list and create projects, tables (schemes), rows, users, project API keys, publish. Use whenever GEM0_TOKEN is set, the user hands you a gem_pat_ token, or asks Claude to manage their Gem0 content or setup. The live API reference is served by Gem0 itself; always fetch it first. For the legacy apist.gem0.dev/sdk.gem0.dev backend with Auth-Token session headers use gem0-api instead.
---

# Gem0 agent API

This skill is a stub. The contract lives on the server and changes with it.

1. Check the environment: `GEM0_URL` (the admin-api base URL, the same host the dashboard calls) and
   `GEM0_TOKEN` (`gem_pat_...`). If either is missing, ask the user. They mint the token in the
   Gem0 dashboard: Settings, Agent tokens, Create token.
2. Fetch the current reference and follow it over anything you remember:
   `curl -fsS "$GEM0_URL/v3/agent/skill.md"`
3. Find out what this token may do before doing anything:
   `curl -fsS "$GEM0_URL/v3/agent/me" -H "Authorization: Bearer $GEM0_TOKEN"`
   Stay inside `modules` and `projects` from that response. A non-staff user only sees their agency.

Rules that hold whatever the live doc says:

- Never echo, log, commit or paste the token anywhere. Reference it as `$GEM0_TOKEN`.
- Any `remove`, disabling a user, revoking a key or publishing needs the user's explicit yes in this session.
- On `success:false`, show the `data` field verbatim; Gem0 messages name the exact cause.
- A 403 means the token is read-only or the route is human-only (billing, login, minting tokens). Tell the user; do not look for a way around it.
