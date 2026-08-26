#!/usr/bin/env bash
# Probe a remote server to gather basic context.
# Usage: ./probe-server.sh USER@HOST [PORT]
#   or:  SSH_KEY=~/.ssh/id KEY=/path ./probe-server.sh USER@HOST
#
# Output: OS, arch, user, sudo state, disk, memory, tools, services, ports
# Anonymized: pass placeholders, never commit real IPs.

set -u

TARGET="${1:?Usage: $0 USER@HOST [PORT]}"
PORT="${2:-22}"
KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SUDO="${SUDO_PASS:-}"

SSH_OPTS=(-i "$KEY" -p "$PORT" -o BatchMode=no -o ConnectTimeout=10)

cat <<BANNER
=== Probing $TARGET (port $PORT) ===
BANNER

echo
echo "=== OS ==="
ssh "${SSH_OPTS[@]}" "$TARGET" 'cat /etc/os-release 2>/dev/null | head -5 || cat /etc/redhat-release 2>/dev/null || cat /etc/alpine-release 2>/dev/null'

echo
echo "=== Arch / Kernel ==="
ssh "${SSH_OPTS[@]}" "$TARGET" 'uname -m; uname -r'

echo
echo "=== User ==="
ssh "${SSH_OPTS[@]}" "$TARGET" 'whoami; id'

echo
echo "=== Sudo (non-interactive) ==="
ssh "${SSH_OPTS[@]}" "$TARGET" 'sudo -n true 2>&1 | head -1 || echo "needs password"'

echo
echo "=== Home ==="
ssh "${SSH_OPTS[@]}" "$TARGET" 'echo "$HOME"'

echo
echo "=== Disk ==="
ssh "${SSH_OPTS[@]}" "$TARGET" 'df -h / | tail -1'

echo
echo "=== Memory ==="
ssh "${SSH_OPTS[@]}" "$TARGET" 'free -h | head -2'

echo
echo "=== Tools ==="
ssh "${SSH_OPTS[@]}" "$TARGET" \
  'for cmd in jq systemctl docker podman nginx python3 node npm go curl nc; do
     command -v $cmd >/dev/null 2>&1 && echo "  ✓ $cmd: $(command -v $cmd)" || echo "  ✗ $cmd"
   done'

echo
echo "=== Running services (top 10) ==="
ssh "${SSH_OPTS[@]}" "$TARGET" \
  'systemctl list-units --type=service --state=running --no-pager 2>/dev/null | grep -E "\.service" | head -10'

echo
echo "=== Open ports ==="
ssh "${SSH_OPTS[@]}" "$TARGET" \
  'ss -ltn 2>/dev/null | head -10 || netstat -ltn 2>/dev/null | head -10'

echo
echo "=== Done ==="
