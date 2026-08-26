# Critical Gotchas

> **Read first** — these are the silent-killers that bite every other day. Each one was hit in production.

## 1. Non-interactive bashrc doesn't load under `sudo -S`

**Symptom**: Service fails to start with `SecretRefResolutionError: environment variable XYZ is missing`.

**Root cause**: `/root/.bashrc` (and `~/.bashrc` generally) starts with:
```bash
[ -z "$PS1" ] && return   # ← exits immediately for non-interactive shell
```

So `ssh user@host "echo password | sudo -S bash -c 'systemctl start foo'"` never loads env vars.

**Fix**: Extract env inline before running the service:
```bash
ssh user@host "echo password | sudo -S bash -c '
  set -a
  source <(grep -E \"^export [A-Z_]+=\" ~/.bashrc | sed \"s/^export //\")
  set +a
  systemctl start my-service
'"
```

**For long-running daemons**, write env to `/etc/environment` so it's system-wide.

## 2. `sudo -S` echoes password into process list

`echo "$PASS" | sudo -S cmd` is visible in `/proc/*/cmdline` to any user with `/proc` access.

**Better**: Use `sudo -A` (askpass helper) or NOPASSWD in sudoers for specific commands.

## 3. PowerShell + scp path encoding on Windows

When using **PowerShell** (Windows) to invoke ssh/scp:
- Use **double quotes** around paths with backslashes
- Path separators work both ways (`\` and `/`)
- But SCP destination with `~` may need absolute path: `${SSH_USER}@${SERVER_HOST}:/home/${SSH_USER}/file` not `:~/file`

```powershell
# WRONG: PowerShell will mangle backslashes
scp -i $key C:\Users\me\file.txt user@host:~/file.txt

# RIGHT
scp -i $key "C:\Users\me\file.txt" "user@host:/home/user/file.txt"
```

## 4. Git on Windows + `git add` silently fails on certain paths

**Symptom**: `git status` shows file as untracked, but `git add path/to/file` does nothing.

**Workaround**: Use `git update-index --add path/to/file` directly. Works when `git add` mysteriously fails.

**Why**: Likely related to PowerShell argument quoting or path normalization. Escaping the path differently usually fixes it.

## 5. scp `\` escaping on remote shell

When `scp` invokes commands on the remote side, the remote shell interprets `\` and `$`. For paths with these:

```bash
# WRONG: remote shell expands $HOME
scp file user@host:"$HOME/file"

# RIGHT: scp handles quoting internally
scp file "user@host:/home/user/file"
```

## 6. sudo password prompt vs `-S`

| Flag | Behavior |
|---|---|
| `sudo cmd` | Needs TTY (interactive) |
| `echo "$pass" \| sudo -S cmd` | No TTY, password on stdin |
| `sudo -n cmd` | Non-interactive, fails if password required |

For automation, prefer `sudo -n` (NOPASSWD sudoers entry) over `-S`.

## 7. Background processes die when SSH session ends

**Wrong**:
```bash
ssh user@host "long-task &"
# SSH exits, SIGHUP kills long-task
```

**Right**:
```bash
ssh user@host "nohup long-task > /tmp/long-task.log 2>&1 &"
# nohup ignores SIGHUP, redirects survive
```

Even better for services: systemd unit (see management-commands.md M2).

## 8. `ssh -t` (PTY) breaks pipes

`-t` allocates a TTY, which makes remote command output pass through a PTY. This breaks `| grep`, `| jq`, etc.

**Fix**: Only use `-t` for interactive sessions (vim, htop). Use plain `ssh` for piped commands.

## 9. GitHub Actions / CI SSH host key verification

CI runners don't have your server's host key in `~/.ssh/known_hosts`. Add to `~/.ssh/config`:
```
Host ${SERVER_HOST}
  StrictHostKeyChecking accept-new
```
Or pre-populate known_hosts in the CI image.