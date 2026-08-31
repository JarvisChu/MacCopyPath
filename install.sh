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

# pbs（系统服务管理进程）用来标识本服务的键。
# 前缀之所以是字面量 "(null)"，是因为 workflow 的 Info.plist 中没有
# CFBundleIdentifier —— 这与 Automator 自己保存的 workflow 行为一致。
SERVICE_KEY='"(null) - Copy Path - runWorkflowAsService"'
ORDERING_KEY='"SERVICE-(null) - Copy Path - runWorkflowAsService"'

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

# 关键步骤：显式启用右键菜单显示。
#
# 仅把 workflow 放进 ~/Library/Services 只能让 pbs 扫描到该服务（它会出现在
# 系统设置的服务列表里），但服务是否真的显示在 Finder 右键菜单，由 pbs 偏好中
# 的 NSServicesStatus.<key>.presentation_modes 决定。全新安装的服务在那里没有
# 任何记录，右键菜单就可能不出现；而在系统设置里手动勾选未必会写入该记录。
# 这里直接写入，保证菜单项可见。重复执行是幂等的。
defaults write pbs NSServicesStatus -dict-add "$SERVICE_KEY" '<dict><key>presentation_modes</key><dict><key>ContextMenu</key><integer>1</integer><key>FinderPreview</key><integer>1</integer><key>ServicesMenu</key><integer>1</integer><key>TouchBar</key><integer>1</integer></dict></dict>'
# 在 Finder 快速操作中的排序位置，仅影响顺序，不影响是否显示
defaults write pbs FinderOrdering -dict-add "$ORDERING_KEY" -int 99
echo "Enabled in Finder context menu."

# 刷新系统服务缓存，让菜单项立即生效（无需注销重登）
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true
echo "Service cache flushed, Finder restarted."

cat <<'TIP'

Done. Usage:
  Finder → right-click a file or folder → Quick Actions → Copy Path

If the menu item still does not show up, see the Troubleshooting section
in README.md.
TIP
