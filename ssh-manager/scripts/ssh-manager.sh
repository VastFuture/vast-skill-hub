#!/bin/bash
# ssh-manager.sh - SSH 服务器管理（新增 / 列出 / 执行 / 移除）
#
# 数据: 与本脚本同级的 servers.json
# 依赖: python3 (Windows/Linux/macOS 都自带)

set -e

# ============ 路径解析 ============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_FILE="${SSH_MANAGER_DATA:-$SKILL_DIR/data/servers.json}"

PY="$(command -v python3 || command -v python)"
[ -z "$PY" ] && { echo "[!] 需要 python3"; exit 1; }

# ============ 颜色（Git Bash/MSYS 支持 ANSI）============
if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
    C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_RST=""
fi

die()  { echo "${C_ERR}[!] $*${C_RST}" >&2; exit 1; }
info() { echo "${C_DIM}[*]${C_RST} $*"; }
ok()   { echo "${C_OK}[+]${C_RST} $*"; }
warn() { echo "${C_WARN}[!]${C_RST} $*"; }

# ============ 数据层（唯一真相源 = servers.json）============

ensure_data_file() {
    [ -f "$DATA_FILE" ] || echo "[]" > "$DATA_FILE"
}

# 通过 Python heredoc 读写 JSON，避免 bash 解析的边角问题
# 关键修复：Python 在 Windows 上不识别 MSYS 的 /c/Users/... 虚拟路径，
# 必须用 cygpath 转成 C:\Users\... 形式，否则 os.path.exists() 永远 False。
to_python_path() {
    if command -v cygpath > /dev/null 2>&1; then
        cygpath -w "$1"
    else
        printf '%s' "$1"  # macOS/Linux 上本来就是原生路径
    fi
}

py_json() {
    local py_path
    py_path=$(to_python_path "$DATA_FILE")

    # 用位置参数 + 单引号 heredoc，彻底避免 bash 转义/展开问题
    $PY - "$py_path" "$1" "$2" "$3" "$4" "$5" "$6" <<'PYEOF'
import json, os, sys

path, action, name, host, port, user, key = sys.argv[1:8]

def load():
    if not os.path.exists(path):
        return []
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)

def save(data):
    parent = os.path.dirname(path)
    if parent and not os.path.exists(parent):
        os.makedirs(parent, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write('\n')

if action == "get":
    data = load()
    for s in data:
        if s.get('name') == name:
            print(json.dumps(s, ensure_ascii=False))
            sys.exit(0)
    sys.exit(1)

elif action == "list":
    data = load()
    if not data:
        print("EMPTY")
    else:
        print(json.dumps(data, ensure_ascii=False, indent=2))

elif action == "exists":
    data = load()
    sys.exit(0 if any(s.get('name') == name for s in data) else 1)

elif action == "has_host":
    data = load()
    sys.exit(0 if any(s.get('host') == host for s in data) else 1)

elif action == "add":
    data = load()
    if any(s.get('name') == name for s in data):
        print("EXISTS"); sys.exit(0)
    data.append({
        "name": name, "host": host,
        "port": int(port), "user": user,
        "key_path": key
    })
    save(data); print("ADDED")

elif action == "remove":
    data = load()
    new = [s for s in data if s.get('name') != name]
    if len(new) == len(data):
        print("NOT_FOUND"); sys.exit(1)
    save(new); print("REMOVED")
PYEOF
}

# ============ ~/.ssh/config 助手 ============

ensure_ssh_config_block() {
    local host="$1" port="$2" user="$3" key="$4" name="$5"
    local config="$HOME/.ssh/config"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$config"
    chmod 600 "$config"

    # 已存在同名 Host 块就跳过（幂等核心）
    if grep -qE "^Host[[:space:]]+${host}[[:space:]]*$" "$config" 2>/dev/null; then
        info "ssh config 中 '$host' 已存在，跳过"
        return
    fi

    cat >> "$config" <<EOF

# ssh-manager: $name
Host $host
    HostName $host
    Port $port
    User $user
    IdentityFile $key
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    ok "已写入 ~/.ssh/config: Host $host"
}

# ============ 子命令 ============

cmd_help() {
    cat <<EOF
ssh-manager - SSH 服务器管理

用法:
  ssh-manager add <user@host> [port] [name]   添加并免密配置
  ssh-manager list                             列出所有服务器
  ssh-manager show <name>                      显示某台详情
  ssh-manager exec <name> "<command>"          在服务器上执行命令
  ssh-manager ssh <name>                       交互登录
  ssh-manager remove <name>                    从列表移除（不删密钥）

数据: $DATA_FILE
EOF
}

cmd_add() {
    local target="${1:?用法: ssh-manager add user@host [port] [name]}"
    local port="${2:-22}"
    local name="$3"

    [[ "$target" == *@* ]] || die "目标必须是 user@host 格式: $target"
    local user="${target%@*}"
    local host="${target#*@}"

    # 默认名 = 主机名替换 . - 为 _
    if [ -z "$name" ]; then
        name="${host//[.-]/_}"
    fi

    ensure_data_file

    # 查重（name 维度）
    if py_json exists "$name" "" "" "" "" > /dev/null 2>&1; then
        die "服务器 '$name' 已存在。先 'remove' 或换名字。"
    fi
    # 查重（host 维度，避免同名密钥/端口冲突）
    if py_json has_host "" "$host" "" "" "" > /dev/null 2>&1; then
        warn "host '$host' 已存在于列表中。可继续但密钥会复用。"
    fi

    local key_path="$HOME/.ssh/${name}_key"

    # 1. 密钥（核心幂等点）
    if [ -f "$key_path" ] && [ -f "${key_path}.pub" ]; then
        info "复用现有密钥: $key_path"
    else
        info "生成密钥: $key_path"
        ssh-keygen -t ed25519 -f "$key_path" -N "" \
            -C "$(whoami)@$(hostname)-$name"
    fi

    # 2. 推送公钥
    info "推送公钥到 ${user}@${host}:${port}"
    ssh-copy-id -i "${key_path}.pub" -p "$port" "${user}@${host}"

    # 3. 强制免密验证（BatchMode=yes 会拒绝密码询问 = 真验证）
    info "验证免密登录..."
    local verify_out
    verify_out=$(ssh -i "$key_path" -p "$port" \
        -o BatchMode=yes -o ConnectTimeout=5 \
        "${user}@${host}" 'echo "[OK] $(whoami)@$(hostname)"' 2>&1)
    echo "$verify_out"
    [[ "$verify_out" == *"[OK]"* ]] || die "免密验证失败。请检查网络/防火墙/账号"

    # 4. ~/.ssh/config
    ensure_ssh_config_block "$host" "$port" "$user" "$key_path" "$name"

    # 5. 写入数据
    local result
    result=$(py_json add "$name" "$host" "$port" "$user" "$key_path" 2>&1)
    if [[ "$result" == *"ADDED"* ]]; then
        ok "已添加: ${C_OK}$name${C_RST} -> $user@$host:$port"
        echo ""
        echo "  ${C_DIM}快捷登录: ssh $host${C_RST}"
        echo "  ${C_DIM}查看所有: ssh-manager list${C_RST}"
    else
        warn "数据写入异常: $result（但密钥和免密已配置好）"
    fi
}

cmd_list() {
    ensure_data_file
    local raw
    raw=$(py_json list "" "" "" "" "" 2>/dev/null)

    if [[ "$raw" == "EMPTY" ]] || [ -z "$raw" ]; then
        echo "  ${C_DIM}(还没有服务器。先用 'ssh-manager add' 添加)${C_RST}"
        return
    fi

    # 表格输出
    echo ""
    printf "  ${C_DIM}%-20s %-25s %-12s %s${C_RST}\n" "NAME" "HOST:PORT" "USER" "KEY"
    printf "  ${C_DIM}%-20s %-25s %-12s %s${C_RST}\n" "----" "---------" "----" "---"
    echo "$raw" | $PY -c "
import json, sys
for s in json.load(sys.stdin):
    name = s['name']
    host = s['host']
    port = s['port']
    user = s['user']
    key  = s.get('key_path', '')
    hp = f'{host}:{port}'
    print(f'  {name:<20} {hp:<25} {user:<12} {key}')
"
    echo ""
}

cmd_show() {
    local name="${1:?用法: ssh-manager show <name>}"
    ensure_data_file
    local entry
    entry=$(py_json get "$name" "" "" "" "" 2>/dev/null) || die "未找到: $name"
    echo "$entry" | $PY -m json.tool
}

cmd_exec() {
    local name="${1:?用法: ssh-manager exec <name> <command...>}"
    shift
    local cmd="$*"
    [ -z "$cmd" ] && die "需要指定要执行的命令"

    ensure_data_file
    local entry
    entry=$(py_json get "$name" "" "" "" "" 2>/dev/null) || die "未找到: $name"

    local host port user key
    host=$(echo "$entry" | $PY -c "import json,sys; print(json.load(sys.stdin)['host'])")
    port=$(echo "$entry" | $PY -c "import json,sys; print(json.load(sys.stdin)['port'])")
    user=$(echo "$entry" | $PY -c "import json,sys; print(json.load(sys.stdin)['user'])")
    key=$(echo "$entry" | $PY -c "import json,sys; print(json.load(sys.stdin)['key_path'])")

    [ -f "$key" ] || die "私钥不存在: $key"

    ssh -i "$key" -p "$port" \
        -o ConnectTimeout=10 \
        "${user}@${host}" "$cmd"
}

cmd_ssh() {
    local name="${1:?用法: ssh-manager ssh <name>}"
    ensure_data_file
    local entry
    entry=$(py_json get "$name" "" "" "" "" 2>/dev/null) || die "未找到: $name"

    local host port user key
    host=$(echo "$entry" | $PY -c "import json,sys; print(json.load(sys.stdin)['host'])")
    port=$(echo "$entry" | $PY -c "import json,sys; print(json.load(sys.stdin)['port'])")
    user=$(echo "$entry" | $PY -c "import json,sys; print(json.load(sys.stdin)['user'])")
    key=$(echo "$entry" | $PY -c "import json,sys; print(json.load(sys.stdin)['key_path'])")

    [ -f "$key" ] || die "私钥不存在: $key"
    exec ssh -i "$key" -p "$port" "${user}@${host}"
}

cmd_remove() {
    local name="${1:?用法: ssh-manager remove <name>}"
    ensure_data_file

    local entry
    entry=$(py_json get "$name" "" "" "" "" 2>/dev/null) || die "未找到: $name"

    warn "确认移除 '$name'? ${C_DIM}(不会删除 ~/.ssh/ 下的密钥文件)${C_RST}"
    read -p "  输入 y 确认: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }

    local result
    result=$(py_json remove "$name" "" "" "" "" 2>&1)
    [[ "$result" == *"REMOVED"* ]] && ok "已移除: $name" || die "移除失败: $result"
}

# ============ 入口 ============

case "${1:-help}" in
    add)         shift; cmd_add "$@" ;;
    list|ls)     cmd_list ;;
    show)        shift; cmd_show "$@" ;;
    exec)        shift; cmd_exec "$@" ;;
    ssh)         shift; cmd_ssh "$@" ;;
    remove|rm)   shift; cmd_remove "$@" ;;
    help|-h|--help) cmd_help ;;
    *)           die "未知命令: $1。运行 'ssh-manager help' 查看用法" ;;
esac
