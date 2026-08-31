#!/bin/bash
#
# 卸载 "Copy Path" 快速操作，并清理它写入的 pbs 偏好记录。
#
set -euo pipefail

DEST="$HOME/Library/Services/Copy Path.workflow"
PBS_PLIST="$HOME/Library/Preferences/pbs.plist"
SERVICE_KEY='(null) - Copy Path - runWorkflowAsService'
ORDERING_KEY='SERVICE-(null) - Copy Path - runWorkflowAsService'

if [ -e "$DEST" ]; then
    rm -rf "$DEST"
    echo "Removed: $DEST"
else
    echo "Workflow not installed."
fi

# 清理 install.sh 写入的 pbs 偏好，做到不留残留。
# 先 killall cfprefsd 让偏好守护进程把缓存落盘，改完文件后再让它重新读取，
# 否则内存中的旧值会把修改覆盖回去。
if [ -f "$PBS_PLIST" ]; then
    killall cfprefsd >/dev/null 2>&1 || true
    sleep 1
    /usr/libexec/PlistBuddy -c "Delete :NSServicesStatus:'$SERVICE_KEY'" "$PBS_PLIST" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Delete :FinderOrdering:'$ORDERING_KEY'" "$PBS_PLIST" >/dev/null 2>&1 || true
    killall cfprefsd >/dev/null 2>&1 || true
    echo "Cleaned pbs preferences."
fi

/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true
echo "Service cache flushed, Finder restarted."
