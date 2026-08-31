#!/bin/bash
#
# 安装 "Copy Path" 快速操作到当前用户的服务目录。
# 安装后即可在 Finder 中右键 → 快速操作 → Copy Path，复制文件/目录完整路径。
#
set -euo pipefail

# 脚本所在目录，保证从任意位置调用都能找到 workflow 源
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_NAME="Copy Path.workflow"
SRC="$SRC_DIR/$WORKFLOW_NAME"
DEST_DIR="$HOME/Library/Services"
DEST="$DEST_DIR/$WORKFLOW_NAME"

if [ ! -d "$SRC" ]; then
    echo "Error: workflow bundle not found at $SRC" >&2
    exit 1
fi

mkdir -p "$DEST_DIR"

# 覆盖安装：先删除旧版本，避免残留文件
if [ -e "$DEST" ]; then
    echo "Removing existing installation..."
    rm -rf "$DEST"
fi

cp -R "$SRC" "$DEST"
echo "Installed: $DEST"

# 刷新系统服务缓存，让菜单项立即生效（无需注销重登）
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
echo "Service cache flushed."

cat <<'TIP'

Done. Usage:
  Finder → right-click a file or folder → Quick Actions → Copy Path

If the menu item does not show up:
  1. System Settings → Keyboard → Keyboard Shortcuts → Services → Files and Folders,
     make sure "Copy Path" is checked (you can also assign a shortcut there).
  2. Restart Finder:  killall Finder
TIP
