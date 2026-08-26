# Management Commands Reference (指引命令)

Install/deploy-side commands. Less frequent than troubleshooting, but you still need them when actually fixing/building things. Treat as a **reference**, not the main workflow — `SKILL.md` Phase 2 Ops 1-8 are for "X broke, find out why"; this file is for "now fix it".

## M1: Install/Update a Package

```bash
# Debian/Ubuntu
ssh host "sudo apt-get update && sudo apt-get install -y ${PKG}"

# RHEL/CentOS/Rocky
ssh host "sudo dnf install -y ${PKG}"

# Alpine
ssh host "sudo apk add --no-cache ${PKG}"
```

## M2: Create a systemd Service

```bash
ssh host << 'EOF'
set -e
sudo tee /etc/systemd/system/${NAME}.service > /dev/null <<UNIT
[Unit]
Description=${DESCRIPTION}
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${WORKDIR}
ExecStart=${EXEC}
Restart=always
RestartSec=5
Environment="KEY=value"

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable ${NAME}
sudo systemctl start ${NAME}
sudo systemctl status ${NAME} --no-pager
EOF
```

## M3: Run a One-Shot Multi-line Script

```bash
ssh host 'bash -s' << 'EOF'
set -e
cd /opt/myapp
git pull
./deploy.sh
sudo systemctl restart myapp
EOF
```

## M4: Transfer Files

```bash
# Upload
scp -i KEY LOCAL_PATH user@host:/remote/path

# Download
scp -i KEY user@host:/remote/path LOCAL_PATH

# Recursive
scp -i KEY -r LOCAL_DIR/ user@host:/remote/dir/
```

## M5: Run in Background (Survive SSH Exit)

```bash
ssh host "nohup ${CMD} > /tmp/${NAME}.log 2>&1 &"
# Or use systemd (M2) for anything that should persist.
```

## M6: Safe Config Edit

```bash
ssh host << 'EOF'
set -e
CFG=/etc/myapp/config.yaml
cp -p "$CFG" "${CFG}.pre-$(date +%Y%m%d-%H%M%S).bak"   # 1. backup
sed -i 's/old/new/' "$CFG"                                 # 2. edit
myapp --config "$CFG" --check                              # 3. validate
sudo systemctl reload myapp                                 # 4. hot reload
EOF
```

## M7: Tail Logs Live

```bash
ssh host "journalctl -u ${SERVICE} -f --no-pager"
# Plain file:
ssh host "tail -F /var/log/${APP}.log"
```

## M8: User/Group Management

```bash
ssh host << 'EOF'
# Add user
sudo useradd -m -s /bin/bash ${USER}
sudo usermod -aG sudo ${USER}    # Debian/Ubuntu
sudo usermod -aG wheel ${USER}   # RHEL

# Set password
echo "${USER}:${PASS}" | sudo chpasswd

# SSH key for new user
sudo mkdir -p /home/${USER}/.ssh
sudo cp /root/.ssh/authorized_keys /home/${USER}/.ssh/    # OR use ssh-copy-id
sudo chown -R ${USER}:${USER} /home/${USER}/.ssh
sudo chmod 700 /home/${USER}/.ssh
sudo chmod 600 /home/${USER}/.ssh/authorized_keys
EOF
```

## M9: Deploy an app from GitHub

```bash
ssh user@host << 'EOF'
set -e
cd /opt/myapp
git fetch origin
git reset --hard origin/main     # DESTRUCTIVE — backup first
./deploy.sh
sudo systemctl restart myapp
EOF
```

## M10: Backup Before Destructive Ops

```bash
ssh user@host << 'EOF'
tar -czf "/tmp/backup-$(date +%Y%m%d-%H%M%S).tar.gz" \
  /etc/myapp /opt/myapp/data
ls -lh /tmp/backup-*.tar.gz
EOF
```

## M11: Run a One-Shot Script From Local File

```bash
cat script.sh | ssh user@host "bash -s"
```