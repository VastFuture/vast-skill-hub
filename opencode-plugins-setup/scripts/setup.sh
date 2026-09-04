#!/usr/bin/env bash
# OpenCode Core Plugins One-Click Setup Script (Linux/macOS/Git Bash)
set -e

CONFIG_DIR="${HOME}/.config/opencode"
echo "🚀 [OpenCode Setup] Installing plugins to ${CONFIG_DIR}..."

mkdir -p "${CONFIG_DIR}"
cd "${CONFIG_DIR}"

# 1. Ensure package.json exists
if [ ! -f "package.json" ]; then
  cat > package.json << 'EOF'
{
  "dependencies": {
    "@opencode-ai/plugin": "1.18.23"
  }
}
EOF
fi

# 2. Install plugins via npm
echo "📦 Installing plugin dependencies..."
npm install opencode-runtime-fallback opencode-wecom-ping cc-adapter-v2 VastFuture/opencode-ralph-loop --save

# 3. Update opencode.json
OPENCODE_JSON="${CONFIG_DIR}/opencode.json"
node -e "
const fs = require('fs');
const file = '${OPENCODE_JSON}';
let cfg = { '\$schema': 'https://opencode.ai/config.json', plugin: [] };
if (fs.existsSync(file)) {
  try {
    cfg = JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (e) {}
}
if (!Array.isArray(cfg.plugin)) {
  cfg.plugin = [];
}
const pluginsToAdd = [
  'cc-adapter-v2',
  'opencode-runtime-fallback',
  'opencode-wecom-ping',
  'ralph-loop'
];
for (const p of pluginsToAdd) {
  if (!cfg.plugin.includes(p)) {
    cfg.plugin.push(p);
  }
}
fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
console.log('✅ Updated plugin list in opencode.json');
"

# 4. Create default fallback config if not present
FALLBACK_JSON="${CONFIG_DIR}/opencode-fallback.jsonc"
if [ ! -f "${FALLBACK_JSON}" ]; then
  cat > "${FALLBACK_JSON}" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "enabled": true,
  "retry_on_errors": [429, 500, 502, 503, 504],
  "max_fallback_attempts": 10,
  "cooldown_seconds": 60,
  "timeout_seconds": 30,
  "notify_on_fallback": true,
  "fallback_models": []
}
EOF
  echo "✅ Created default opencode-fallback.jsonc"
fi

echo "🎉 All plugins installed successfully! Please restart OpenCode to take effect."
