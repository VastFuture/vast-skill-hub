---
name: remote-server-management
description: Manage remote Linux servers via SSH. Use when user says "ssh到服务器", "ssh远程", "管理远程服务器", "deploy到服务器", "服务器运维", "server config", "上传文件到服务器", "在服务器上跑命令", "服务器起不来", "服务器磁盘满", "服务器连不上" — guides through first-time SSH key setup + safe day-to-day troubleshooting + install/deploy commands.
---

# Remote Server Management (SSH)

Operate a remote Linux server from a local workstation via SSH. **Never** assumes specific IPs, users, or keys — all values are placeholders or collected interactively.

## ⚠️ Core Safety Rules

1. **Never commit real IPs, hostnames, usernames, or key paths.** Use `${SERVER_HOST}`, `${SSH_USER}`, `${SSH_KEY}` placeholders. Real values live in `.env` (gitignored) or session memory only.
2. **Always backup before config edits.** `cp -p /etc/foo /etc/foo.pre-$(date +%Y%m%d).bak`
3. **Prefer dry-run.** Show the command, get confirmation, then execute.
4. **Don't stack two production actions** without explicit OK (deploy+drain, restart+diagnose, etc).
5. **Never `:sys.get_state/1` or full-state dumps** on production processes — blocks them.

## File Map

| File | Purpose |
|---|---|
| `SKILL.md` (this) | Onboarding + 8 diagnostic ops + quick reference |
| `references/gotchas.md` | 9 production-killer gotchas (read first when things break weirdly) |
| `references/management-commands.md` | Install / deploy / user-mgmt reference (M1-M11) |
| `references/diagnostic-workflows.md` | 4 symptom-driven debug flows |
| `scripts/probe-server.sh` | Reusable context-probe wrapper |

## Phase 1: Interactive Onboarding — Setup SSH From Scratch

**Run this once per server**. Guides the user through generating keys, copying them to the server, hardening sshd, and setting up passwordless sudo. **Always** end with a working key-based, passwordless sudo setup before proceeding to Phase 2.

### Step 1.1: Generate Local SSH Key Pair

**Show the user this and ask if they already have a key** at `~/.ssh/id_ed25519` (or `~/.ssh/id_rsa`).

If no key, generate one:

**Linux/macOS**:
```bash
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519 -N ""
# -N "" = no passphrase (or use a passphrase + ssh-agent for security)
```

**Windows (PowerShell)** with OpenSSH:
```powershell
ssh-keygen -t ed25519 -C "your-email@example.com" -f $HOME\.ssh\id_ed25519 -N ""
```

**Verify**:
```bash
ls -la ~/.ssh/id_ed25519*
# Should show: id_ed25519 (private, 600) and id_ed25519.pub (public, 644)
```

### Step 1.2: Collect Target Server Info

Ask the user one field at a time (don't dump all questions at once):

```
q1. Server host (IP or hostname)?
    e.g., 192.0.2.10  or  my-server.example.com

q2. SSH username on server?
    e.g., deploy, ubuntu, root
    (avoid root long-term — create a regular user + root for emergency)

q3. SSH port? (default 22 — assume unless told)

q4. Do you have root/sudo password for this user?
    (needed for the first key-copy + sshd config steps)
```

**Store in session memory only.** Do not write to disk unless user explicitly asks for `.env` persistence.

### Step 1.3: Copy Public Key to Server

**Option A — `ssh-copy-id` (easiest, requires password auth still enabled)**:
```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub -p ${SSH_PORT:-22} ${SSH_USER}@${SERVER_HOST}
# prompts for password one last time
```

**Option B — manual paste** (when `ssh-copy-id` not available, e.g., minimal Alpine server):
```bash
# 1. Show your public key
cat ~/.ssh/id_ed25519.pub
# 2. On server (via password SSH):
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo "ssh-ed25519 AAAA... your-email@example.com" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Verify**:
```bash
ssh -i ~/.ssh/id_ed25519 -p ${SSH_PORT:-22} ${SSH_USER}@${SERVER_HOST} "echo key auth works"
# Should NOT ask for password
```

### Step 1.4: Harden Server-Side SSH

**Teach the user what each setting does**, then apply via SSH session:

```bash
ssh ${SSH_USER}@${SERVER_HOST} << 'EOF'
set -e
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.pre-$(date +%Y%m%d).bak

# 1. Disable password authentication (CRITICAL — do this AFTER confirming key works)
sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# 2. Disable root login (after confirming you have a sudo user)
sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# 3. Limit auth attempts (slows brute force)
sudo sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config

# 4. Disable empty passwords
sudo sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# 5. Validate config before reload (CRITICAL — bad config = locked out)
sudo sshd -t
# If no output = OK. If error = fix before next step.

# 6. Reload sshd (NOT restart — keeps current sessions alive)
sudo systemctl reload sshd
EOF
```

**⚠️ Critical**: Tell user to **test in a SECOND SSH session before closing the first one**. If config breaks auth, the first session keeps you in.

### Step 1.5: Configure Passwordless Sudo (Optional, Recommended)

Ask user: "Do you want passwordless sudo for specific commands (safer) or all commands (convenient)?"

**Option A — NOPASSWD for specific commands** (recommended for automation):
```bash
ssh ${SSH_USER}@${SERVER_HOST} << 'EOF'
sudo cp /etc/sudoers /etc/sudoers.pre-$(date +%Y%m%d).bak
# Add at end (use visudo for validation!)
echo "${SSH_USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart myapp, /usr/bin/systemctl reload nginx" \
  | sudo tee /etc/sudoers.d/${SSH_USER}-ops
sudo chmod 440 /etc/sudoers.d/${SSH_USER}-ops
# Validate
sudo visudo -c
EOF
```

**Option B — NOPASSWD for all commands** (only for disposable/throwaway VMs):
```bash
ssh ${SSH_USER}@${SERVER_HOST} << 'EOF'
echo "${SSH_USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/${SSH_USER}-nopasswd
sudo chmod 440 /etc/sudoers.d/${SSH_USER}-nopasswd
sudo visudo -c
EOF
```

**Verify**:
```bash
ssh ${SSH_USER}@${SERVER_HOST} "sudo -n systemctl status sshd | head -3"
# Should work without password prompt
```

### Step 1.6: Probe Server Context

Use the included script (preferred):
```bash
SSH_KEY=~/.ssh/id_ed25519 ./scripts/probe-server.sh ${SSH_USER}@${SERVER_HOST} ${SSH_PORT:-22}
```

Or inline (copy-paste version):
```bash
ssh -i ~/.ssh/id_ed25519 -p ${SSH_PORT:-22} ${SSH_USER}@${SERVER_HOST} << 'EOF'
echo "=== OS ==="
cat /etc/os-release | head -3
echo "=== Arch ==="
uname -m
echo "=== User ==="
whoami; id
echo "=== Sudo ==="
sudo -n true 2>&1 | head -1
echo "=== Home ==="
echo $HOME
echo "=== Disk ==="
df -h / | tail -1
echo "=== Memory ==="
free -h | head -2
echo "=== Tools available ==="
for cmd in jq systemctl docker podman nginx python3 node npm go; do
  command -v $cmd >/dev/null 2>&1 && echo "  ✓ $cmd: $(command -v $cmd)" || echo "  ✗ $cmd"
done
echo "=== Running services ==="
systemctl list-units --type=service --state=running --no-pager 2>/dev/null | grep -E "\.service" | head -10
echo "=== Open ports ==="
ss -ltn 2>/dev/null | head -10 || netstat -ltn 2>/dev/null | head -10
EOF
```

### Step 1.7: Save Session State

Summarize for user:

```
Server: ${SERVER_HOST} (${OS} ${ARCH})
User: ${SSH_USER} (sudo NOPASSWD: yes/no)
Tools: jq ✓, docker ✓, systemctl ✓
Services: nginx, postgresql, redis (running)
Disk: 45% used (28G free)
SSH: key auth ✓, password auth DISABLED, root login DISABLED
```

Ask to confirm before proceeding to Phase 2.

## Phase 2: Diagnostic Operations

Real-world work on a server is **mostly troubleshooting**, not installing. Pick from this menu when user says things like "X is broken", "why is Y slow", "find which file...", "can't connect to Z".

**If something looks weird** (env var missing, sudo password prompt out of nowhere, scp mysteriously fails), jump to `references/gotchas.md` — that's where the silent-killers live.

### Op 1: Quick Remote Command (single-shot)

The workhorse. Use this for any one-line inspection.

```bash
ssh -i "${SSH_KEY}" -p "${SSH_PORT:-22}" "${SSH_USER}@${SERVER_HOST}" "${CMD}"
```

**For sudo** (see `references/gotchas.md` #1):
```bash
ssh -i "${SSH_KEY}" "${SSH_USER}@${SERVER_HOST}" "echo '${SUDO_PASSWORD}' | sudo -S ${CMD}"
```

**For interactive** (PTY required):
```bash
ssh -t -i "${SSH_KEY}" "${SSH_USER}@${SERVER_HOST}" "${CMD}"
```

### Op 2: Multi-step Diagnostic Script

For chained commands where output of one informs next. Run once, paste all output to user, then drill into specific failures.

```bash
ssh -i "${SSH_KEY}" "${SSH_USER}@${SERVER_HOST}" 'bash -s' << 'EOF'
set +e   # don't abort on first error — gather everything
echo "=== disk ==="
df -h | head -5
echo "=== memory ==="
free -h
echo "=== service state ==="
systemctl status myapp --no-pager -l 2>&1 | head -20
echo "=== recent logs ==="
journalctl -u myapp -n 30 --no-pager 2>&1
echo "=== process check ==="
pgrep -af myapp || echo "not running"
echo "=== port check ==="
ss -ltnp | grep :8080 || echo "port 8080 not listening"
EOF
```

### Op 3: Search Logs Across Files

When you don't know which log has the error.

```bash
ssh -i "${SSH_KEY}" "${SSH_USER}@${SERVER_HOST}" << 'EOF'
# Grep recent errors across common log locations
grep -rn -E "ERROR|FATAL|panic|refused|timeout" \
  /var/log/myapp/ \
  /var/log/syslog \
  /var/log/nginx/error.log \
  /var/log/auth.log \
  --include="*.log" --include="*.out" \
  -m 5 2>/dev/null | tail -50

# journald errors (last 1h)
sudo journalctl --since "1 hour ago" -p err --no-pager | tail -30

# Kernel ring buffer
dmesg --since "1 hour ago" --level=err,crit,alert,emerg 2>/dev/null | tail -20
EOF
```

**Tip**: always include `-m 5` (max matches per file) to avoid drowning in spam.

### Op 4: Network Connectivity

"Is the port open? Can I reach the host? Is DNS working?"

```bash
ssh -i "${SSH_KEY}" "${SSH_USER}@${SERVER_HOST}" << 'EOF'
# From the server's perspective:
echo "=== listening ports ==="
ss -ltn | head -20

echo "=== outbound DNS ==="
dig +short google.com 2>&1 | head -3 || nslookup google.com | head -5

echo "=== can reach external host ==="
curl -sI --max-time 5 https://example.com | head -3

echo "=== test specific port (local) ==="
nc -zv localhost 8080 2>&1

echo "=== test specific port (remote host) ==="
nc -zv 10.0.0.5 443 2>&1

echo "=== route to host ==="
traceroute -n -m 5 10.0.0.5 2>&1 | head -8
EOF
```

### Op 5: File Discovery

"Find that config file", "what's eating disk in /var", "who changed this file last week".

```bash
ssh -i "${SSH_KEY}" "${SSH_USER}@${SERVER_HOST}" << 'EOF'
# By name
find /etc /opt /home -name "*.conf" -path "*myapp*" 2>/dev/null | head -10

# By content (grep inside files)
grep -rln "secret_api_key" /opt/myapp/ 2>/dev/null | head -10

# By size (find big files eating disk)
find / -size +100M -type f 2>/dev/null | head -20 | xargs -I{} ls -lh {} 2>/dev/null

# By modification time
find /etc -mtime -7 -type f 2>/dev/null | head -20    # modified in last 7 days

# By owner (find files owned by deleted user)
find / -uid 1001 -type f 2>/dev/null | head -10

# By inode (find hardlinks)
find / -inum 12345 2>/dev/null
EOF
```

### Op 6: Permission / Ownership Debugging

"Why can't my service read this file?"

```bash
ssh -i "${SSH_KEY}" "${SSH_USER}@${SERVER_HOST}" << 'EOF'
# Inspect permissions chain
ls -laZ /opt/myapp/config.yaml
stat /opt/myapp/config.yaml | head -10
namei -l /opt/myapp/config.yaml

# Effective user check (for systemd services)
sudo systemctl show myapp -p User -p Group -p WorkingDirectory

# Test as that user
sudo -u myapp_user test -r /opt/myapp/config.yaml && echo "READABLE" || echo "NOT READABLE"
sudo -u myapp_user test -x /opt/myapp/start.sh && echo "EXECUTABLE" || echo "NOT EXECUTABLE"

# SELinux context (RHEL/CentOS)
ls -laZ /opt/myapp/ | head -5
sudo semanage fcontext -l | grep myapp

# Capability check
sudo getcap /opt/myapp/bin/myapp
EOF
```

### Op 7: Resource Exhaustion

"Disk full", "OOM killer", "load average too high", "inode exhausted".

```bash
ssh -i "${SSH_KEY}" "${SSH_USER}@${SERVER_HOST}" << 'EOF'
echo "=== disk space ==="
df -h | grep -vE 'tmpfs|devtmpfs'
echo "=== inodes (can be full even if disk has space) ==="
df -i | grep -vE 'tmpfs|devtmpfs' | head -5
echo "=== biggest dirs ==="
du -sh /var/log /var/lib /tmp /opt 2>/dev/null | sort -hr | head -10
echo "=== biggest files ==="
find / -xdev -type f -size +100M 2>/dev/null -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -10
echo "=== memory ==="
free -h
echo "=== swap ==="
swapon --show
echo "=== OOM kills (kernel) ==="
dmesg | grep -iE 'killed process|out of memory' | tail -10
echo "=== load avg ==="
uptime
echo "=== top cpu consumers ==="
ps aux --sort=-%cpu | head -5
echo "=== top mem consumers ==="
ps aux --sort=-%rss | head -5
EOF
```

### Op 8: Config Inspection & Rollback

"What's actually in this config? Who set it? Can I undo my last change?"

```bash
ssh -i "${SSH_KEY}" "${SSH_USER}@${SERVER_HOST}" << 'EOF'
# Effective config (with comments stripped, includes defaults)
sudo systemctl show myapp -p ExecStart -p Environment -p User -p Restart

# Active config file
sudo systemctl cat myapp

# Diff against last backup
CFG=/etc/myapp/config.yaml
ls -la "${CFG}" "${CFG}".pre-* 2>/dev/null
[ -f "${CFG}.pre-$(date +%Y%m%d)" ] && diff -u "${CFG}.pre-$(date +%Y%m%d)" "${CFG}"

# Who edited it last
ls -la --time-style=full-iso $CFG
stat $CFG | grep -E "Modify|Change"

# git history if it's a git-tracked config dir
cd /etc/myapp 2>/dev/null && git log --oneline -5 -- config.yaml

# Rollback to last backup
# cp -p "${CFG}.pre-YYYYMMDD-HHMMSS.bak" "${CFG}"
EOF
```

### Symptom-driven playbooks

For specific failure modes ("service won't start", "port not reachable", "disk full", "high CPU/load"), see [`references/diagnostic-workflows.md`](references/diagnostic-workflows.md). Each is a step-by-step playbook ending in common root causes.

### Install / deploy commands

Need to install a package, create a systemd unit, add a user, etc.? See [`references/management-commands.md`](references/management-commands.md) (M1-M11).

## Quick Reference

```bash
# Connection
ssh -i KEY USER@HOST "cmd"             # one-off
ssh -i KEY USER@HOST                      # interactive shell
ssh -t -i KEY USER@HOST                  # TTY (interactive apps)

# File transfer
scp -i KEY LOCAL USER@HOST:/path         # upload
scp -i KEY USER@HOST:/path LOCAL         # download
scp -i KEY -r DIR/ USER@HOST:/path       # recursive

# Tunneling (for local dev)
ssh -i KEY -L 8080:localhost:80 USER@HOST

# Background work
nohup cmd > /tmp/log 2>&1 &              # on server
systemctl enable --now SERVICE            # persistent

# Diagnostics
ss -ltn                                    # listening ports
ss -tunap                                  # active connections
ps aux --sort=-%cpu | head                 # top CPU
journalctl -u SERVICE -f --no-pager        # live service logs
```

## Anonymization Reminder

Before committing or sharing:
- Replace `${SERVER_HOST}` with actual IP only in **local**, **gitignored** files
- Never commit SSH keys, passwords, or production hostnames
- Use placeholders in docs: `<your-server>`, `<your-key-path>`, `<ssh-user>`
- For shared docs, use example.com / 192.0.2.0/24 (RFC 5737 documentation range)

---

**Maintainer's note**: The most-iterated sections are `references/gotchas.md` and the diagnostic Op set. When you hit a new silent-killer, add it to gotchas with a `Symptom` / `Root cause` / `Fix` triplet. Don't expand the main file — link to references instead.