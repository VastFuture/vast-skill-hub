# Remote Server Management (SSH)

SSH into remote Linux servers safely — generate keys, harden `sshd`, run diagnostic and management commands, all with anonymized placeholders so nothing sensitive ever leaks into version control.

## Why this exists

Most "SSH to a server" tutorials are riddled with real IPs, user names, and example commands that get copy-pasted into wikis. This skill is built **placeholders-first**: `${SERVER_HOST}`, `${SSH_USER}`, `${SSH_KEY}` everywhere. Safe to commit. Safe to share.

## What's inside

```
.
├── SKILL.md                                   # Main skill (use this in AI workflows)
├── references/
│   ├── gotchas.md                            # 9 production-killer gotchas
│   ├── management-commands.md                # Install/deploy reference (M1-M11)
│   └── diagnostic-workflows.md               # 4 symptom-driven debug flows
└── scripts/
    └── probe-server.sh                       # Reusable context probe wrapper
```

## Quick start

### First time with a new server (5-step wizard)

1. **Generate a key locally**
   ```bash
   ssh-keygen -t ed25519 -C "you@example.com" -f ~/.ssh/id_ed25519 -N ""
   ```

2. **Copy the public key to the server**
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519.pub you@your-server
   ```

3. **Harden `sshd_config`** — disable password auth, root login, limit retries. Reload (don't restart) and test in a second SSH window before closing the first.

4. **Set up passwordless sudo** for the commands you automate (optional but recommended)

5. **Probe the server** to know what you're working with:
   ```bash
   ./scripts/probe-server.sh you@your-server 22
   ```

   Output: OS, arch, sudo state, disk, memory, available tools, running services, open ports.

### Day-to-day troubleshooting (8 diagnostic ops)

For "service won't start", "port not reachable", "disk full", "permission denied" — see `SKILL.md` Phase 2 Ops 1-8. Pick by symptom, not by tool.

For weird failures (env vars missing, scp silently drops files, `git add` does nothing on Windows) — read `references/gotchas.md` first.

### Install / deploy

Need to add a user, create a systemd unit, deploy from GitHub? See `references/management-commands.md` (M1-M11).

## Anonymization rules (non-negotiable)

- ❌ Never commit a real IP, hostname, username, or key path
- ✅ Always use `${SERVER_HOST}`, `${SSH_USER}`, `${SSH_KEY}` placeholders in docs
- ✅ Real values live in `.env` (gitignored) or session memory only
- ✅ Example addresses use `example.com` / `192.0.2.0/24` (RFC 5737 doc range)

## Who this is for

- AI agents / LLM workflows that need to manage remote servers
- Human ops folks who want a battle-tested playbook
- Anyone tired of typing `scp` syntax from memory and getting it wrong

## Contributing

**Adding a new gotcha?** Edit `references/gotchas.md` directly. Keep the `Symptom` / `Root cause` / `Fix` triplet format.

**Adding a new diagnostic workflow?** Edit `references/diagnostic-workflows.md`. Each workflow should end with "Common findings" so the next person doesn't have to re-discover the usual suspects.

**Adding a new management command?** Append to `references/management-commands.md`. Keep the format `M{N}: <Title>`.

**Don't** expand `SKILL.md` — it's already at its sweet spot (~16 KB). Link to references instead.

## License

MIT — do whatever, no warranty.

## Credits

Patterns distilled from real production debugging sessions. Most gotchas were learned the hard way; this skill exists so the next person learns them the easy way.