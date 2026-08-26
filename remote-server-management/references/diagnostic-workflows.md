# Diagnostic Workflows

Step-by-step debug flows for the 4 most common server problems. Pick the matching symptom, run the steps in order.

## "My service won't start"

```bash
# 1. Direct error
sudo systemctl status ${SERVICE} --no-pager -l

# 2. Recent logs
sudo journalctl -u ${SERVICE} --no-pager -n 50

# 3. Try running the binary directly (sees env, prints errors clearly)
sudo -u ${SERVICE_USER} ${EXEC} --foreground

# 4. Check dependencies (env vars, files, ports)
sudo systemctl show ${SERVICE} -p Environment
sudo -u ${SERVICE_USER} bash -c 'cd ${WORKDIR} && env | sort'
```

**Common findings**:
- `Unit not found` → typo in service name, or `.service` suffix missing
- `Failed with result 'exit-code'` → check journalctl for the actual stderr
- `Failed to load environment files` → syntax error in `/etc/default/${SERVICE}`
- Works manually, fails via systemd → almost always working directory or env vars

## "Network port not reachable"

```bash
# From another host:
nc -zv ${SERVER_HOST} ${PORT}    # test TCP
curl -v http://${SERVER_HOST}:${PORT}/  # test HTTP

# From the server itself:
ss -ltn | grep :${PORT}
sudo iptables -L -n | grep ${PORT}
sudo ufw status  # Ubuntu firewall
```

**Common findings**:
- Connection refused → service not bound to that IP/port (check `ss -ltn`)
- Connection timeout → firewall blocking (ufw / iptables / cloud security group)
- Connection accepted then closes → TLS/SSL cert issue, or app crashes immediately

## "Disk full"

```bash
df -h
du -sh /* 2>/dev/null | sort -hr | head -10
# Look for: /var/log (large logs), /tmp (orphaned), /var/lib/docker (containers)
sudo journalctl --vacuum-size=100M   # shrink systemd logs
sudo docker system prune -a          # nuke docker (DESTRUCTIVE — confirm first)
```

**Common findings**:
- `/var/log` huge → `journalctl --vacuum-size=100M` + check logrotate
- `/var/lib/docker` huge → `docker system prune -a` (verify what's deletable first)
- Many small files in `/tmp` → look for orphan PIDs from dead processes
- `df -h` says full but `du` doesn't add up → deleted-but-open files held by running process
  (`lsof +L1` to find them)

## "High CPU / Load"

```bash
top -bn1 | head -20         # snapshot
uptime                      # load average
ps aux --sort=-%cpu | head  # top CPU consumers
# Check: is this a runaway process? cron job? OOM loop?
dmesg | tail -30
```

**Common findings**:
- One process at 100%+ → runaway. `strace -p PID` to see what it's doing
- High load but low CPU → IO wait (disk slow). Check `iostat -x 1`
- Load = CPU count → system is at capacity, queue building
- Load > CPU count × 2 → serious trouble (or many threads)