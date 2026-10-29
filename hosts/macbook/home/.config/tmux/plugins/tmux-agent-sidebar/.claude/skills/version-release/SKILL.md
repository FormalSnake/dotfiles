---
name: version-release
description: Use when bumping version, creating a release tag, or pushing a version tag. Triggers on "version up", "release", "tag push", "bump version".
---

# Version Release

Workflow for updating the version in Cargo.toml, creating a git tag, and pushing it.

## Workflow

1. **Check current version**: Get current version with `grep '^version' Cargo.toml`.
2. **Propose the next version from commits since the last tag**:
   - Find the previous release tag: `git describe --tags --abbrev=0 --match 'v*'`
   - List every commit since that tag: `git log <prev-tag>..HEAD --oneline`
   - Classify the commits using the Pre-1.0 Bump Policy below, decide `patch` / `minor` / `major`, and present the proposed version number to the user **before** editing any files. Do not skip this step even for a single commit — the user should always see the commit range and the classification you used.
3. **Update version**: Edit the `version` field in Cargo.toml using the Edit tool.
4. **Sync the Claude Code plugin manifest**: Edit `.claude-plugin/plugin.json` and update its `version` field to the same value. The two MUST stay in lockstep — `tests/plugin_hooks_tests.rs` enforces this. Without bumping plugin.json, users who installed via `/plugin install` will not see the new release because Claude Code uses this field for update detection.
5. **Regenerate Cargo.lock**: Run `cargo check` to update Cargo.lock
6. **Run checks**: Run `cargo fmt --check && cargo clippy && cargo test`
7. **Commit**: Commit `Cargo.toml`, `Cargo.lock`, and `.claude-plugin/plugin.json` (message example: `Bump version to X.Y.Z`)
8. **Create and push tag**: `git tag vX.Y.Z && git push && git push origin vX.Y.Z`

## Pre-1.0 Bump Policy

This project is still pre-1.0, so SemVer is relaxed: the major stays at `0`
and breaking changes ride on minor bumps.

| Signal in commit range                                                | Bump  | Example       |
|-----------------------------------------------------------------------|-------|---------------|
| Any `feat:` / new user-visible behavior / breaking change             | minor | 0.5.2 → 0.6.0 |
| Only `fix:` / `refactor:` / `chore:` / `docs:` / test-only            | patch | 0.5.2 → 0.5.3 |
| Post-1.0 only: breaking change (`feat!:`, `BREAKING CHANGE` footer)   | major | 1.x → 2.0.0   |

Rules of thumb when classifying:

- Treat any `feat:` commit as a minor bump trigger, even if the rest are fixes.
- Docs-only or CI-only commit ranges still ship as a patch (never skip the
  version bump — the tag is what downstream plugin managers key off).
- If the range is empty (no commits since the last tag), stop and tell the
  user there is nothing to release.
- When in doubt between patch and minor, show the commit list and ask the user.

## Quick Reference

| Bump type | Example       |
|-----------|---------------|
| patch     | 0.2.0 → 0.2.1 |
| minor     | 0.2.0 → 0.3.0 |
| major     | 0.2.0 → 1.0.0 |

## Notes

- Tags use the `v` prefix (e.g., `v0.2.0`)
- Always pass CI checks (fmt, clippy, test) before creating a tag
- Commit `Cargo.lock` together with `Cargo.toml`
