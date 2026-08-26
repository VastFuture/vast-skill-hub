# Changelog

## 2026-08-26 — v1.0

Initial release.

### Added
- `SKILL.md` (~16 KB): Phase 1 onboarding wizard + Phase 2 diagnostic operations
- `references/gotchas.md` — 9 production-killer gotchas (bashrc, sudo -S, scp escaping, etc.)
- `references/management-commands.md` — 11 install/deploy snippets (M1-M11)
- `references/diagnostic-workflows.md` — 4 symptom-driven debug flows
- `scripts/probe-server.sh` — reusable context-probe wrapper for new servers
- `README.md` — human-facing overview

### Design decisions
- Placeholders-first: `${SERVER_HOST}`, `${SSH_USER}`, `${SSH_KEY}` everywhere. Safe to commit.
- Two-section structure: `SKILL.md` (lean, ~16 KB) + `references/` (detail). Avoids skill bloat.
- Diagnostic-first: Phase 2 is troubleshooting (the 90% case), Phase 2.5 is install/deploy (the 10% case).
- No real credentials committed: project IP, usernames, SSH keys, API keys all parameterized.