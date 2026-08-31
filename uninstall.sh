#!/bin/bash
#
# 卸载 "Copy Path" 快速操作。
#
set -euo pipefail

DEST="$HOME/Library/Services/Copy Path.workflow"

if [ -e "$DEST" ]; then
    rm -rf "$DEST"
    echo "Removed: $DEST"
    # 刷新服务缓存，让菜单项立即消失
    /System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
    echo "Service cache flushed."
else
    echo "Not installed, nothing to do."
fi
