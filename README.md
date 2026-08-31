# MacCopyPath

在 Finder 右键菜单中增加一个 **Copy Path**，一键把选中文件/目录的**完整路径**复制到剪贴板。

基于 macOS 原生的**快速操作（Quick Action / Service）**实现，本质是一个 Automator `.workflow`：

- 不需要 Xcode，不需要代码签名
- 不常驻后台、不占内存、无网络行为
- 不申请任何系统权限
- 随时可一键卸载，不留残留

## 安装

```bash
git clone https://github.com/JarvisChu/MacCopyPath.git
cd MacCopyPath
./install.sh
```

`install.sh` 做三件事，**立即生效，无需注销或重启**：

1. 把 `Copy Path.workflow` 拷贝到 `~/Library/Services/`
2. 写入 pbs 偏好，显式启用右键菜单显示（**这一步必不可少**，原因见下方「为什么需要显式启用右键菜单」）
3. 刷新服务缓存并重启 Finder

脚本是幂等的，重复执行安全。

## 使用

在 Finder 中右键点击文件或目录 → **快速操作（Quick Actions）→ Copy Path**，路径即已在剪贴板中。

| 场景 | 结果 |
| --- | --- |
| 选中单个文件/目录 | 复制其完整路径，**末尾不带换行**，可直接粘贴进终端而不会立刻执行 |
| 选中多个 | 多个完整路径以换行分隔 |
| 复制完成 | 弹出一条系统通知作为反馈 |

### 绑定快捷键（可选）

**系统设置 → 键盘 → 键盘快捷键 → 服务 → 文件和文件夹**，找到 `Copy Path`，双击右侧空白处即可设置快捷键。

## 卸载

```bash
./uninstall.sh
```

会删除 `~/Library/Services/Copy Path.workflow`，一并清理安装时写入的 pbs 偏好记录，然后刷新服务缓存。不留残留。

## 常见问题

**右键菜单里找不到 Copy Path？**

最常见的原因是**服务被系统识别了，但没有被启用到右键菜单**——典型表现是：
系统设置的服务列表里**看得见** `Copy Path`（甚至已经勾选），但右键菜单里就是没有。

先确认这一点：

```bash
defaults read pbs NSServicesStatus
```

如果输出里**没有** `"(null) - Copy Path - runWorkflowAsService"` 这一条，就是这个问题。
`install.sh` 已经会自动处理；若要手动修复：

```bash
defaults write pbs NSServicesStatus -dict-add '"(null) - Copy Path - runWorkflowAsService"' \
  '<dict><key>presentation_modes</key><dict><key>ContextMenu</key><integer>1</integer><key>FinderPreview</key><integer>1</integer><key>ServicesMenu</key><integer>1</integer><key>TouchBar</key><integer>1</integer></dict></dict>'
/System/Library/CoreServices/pbs -flush
killall Finder
```

> 注意 key 外层的那对**双引号是必需的**。否则 `defaults` 会把 `(null)` 当作 plist 字面量去解析，
> 报错 `Could not parse: (null) - Copy Path - runWorkflowAsService`。

其它排查手段：

1. 菜单项可能在右键菜单**中部的「快速操作」子菜单**，也可能在**底部的「服务」子菜单**，两处都看一下。
2. 重启 Finder：`killall Finder`。
3. 手动刷新服务缓存：`/System/Library/CoreServices/pbs -flush`。
4. macOS 14 之后，快速操作还可以在 **系统设置 → 通用 → 登录项与扩展 → 快速操作** 中管理，
   这与「键盘快捷键 → 服务」是两个不同的地方。

**确认服务是否已注册成功：**

```bash
/System/Library/CoreServices/pbs -dump_pboard | grep -A2 'Copy Path'
```

**菜单项藏在二级菜单里？**

macOS 会把快速操作收进右键菜单的「快速操作」子菜单。若当前目录下的快速操作只有一个，部分系统版本会直接显示在一级菜单。

## 项目结构

```
MacCopyPath/
├── Copy Path.workflow/          # 快速操作 bundle（工具本体）
│   └── Contents/
│       ├── Info.plist           # 服务声明：菜单名、宿主 App、可接收的文件类型
│       └── document.wflow       # Automator 工作流：内嵌的 shell 脚本
├── install.sh                   # 安装（含服务缓存刷新）
├── uninstall.sh                 # 卸载
└── README.md
```

## 实现原理

### Info.plist —— 声明这是一个 Finder 服务

| 键 | 作用 |
| --- | --- |
| `NSMenuItem.default` | 右键菜单中显示的名字，即 `Copy Path` |
| `NSMessage` | 固定为 `runWorkflowAsService`，表示交由 Automator 执行 |
| `NSRequiredContext.NSApplicationIdentifier` | 限定为 `com.apple.finder`，只在 Finder 中出现 |
| `NSSendFileTypes` | `public.item`，即任意文件与目录都可触发 |

### document.wflow —— 工作流本体

只包含一个 `Run Shell Script` 动作，关键参数：

| 键 | 值 | 含义 |
| --- | --- | --- |
| `inputMethod` | `1` | 选中项以**命令行参数**（`"$@"`）传入，而非标准输入 |
| `shell` | `/bin/zsh` | 执行脚本所用的 shell |
| `serviceInputTypeIdentifier` | `com.apple.Automator.fileSystemObject` | 输入类型是文件系统对象 |
| `workflowTypeIdentifier` | `com.apple.Automator.servicesMenu` | 该 workflow 是一个服务（快速操作） |

### 内嵌脚本

```bash
out=""
for f in "$@"
do
    if [ -z "$out" ]; then
        out="$f"
    else
        out="$out
$f"
    fi
done

printf '%s' "$out" | pbcopy
```

两个刻意的设计：

1. **用 `printf '%s'` 而非 `echo`**，末尾不追加换行。否则复制单个路径粘贴进终端时，尾部换行会导致命令被立刻执行。
2. **通知的文本通过 argv 传给 AppleScript**，而不是拼接进脚本源码字符串：

   ```bash
   osascript - "$msg" <<'APPLESCRIPT' >/dev/null 2>&1 || true
   on run argv
       display notification (item 1 of argv) with title "Copy Path"
   end run
   APPLESCRIPT
   ```

   这样文件名里含双引号或反斜杠也不会破坏脚本；末尾的 `|| true` 保证通知失败绝不影响复制结果。

### 为什么需要显式启用右键菜单

把 workflow 放进 `~/Library/Services/` 只完成了一半：`pbs`（系统的服务管理进程）会扫描到它，
于是它出现在系统设置的服务列表中。但**它是否真的显示在 Finder 右键菜单里，是另一个开关**，
存放在 pbs 偏好 `~/Library/Preferences/pbs.plist` 中：

```
NSServicesStatus
  └── "(null) - Copy Path - runWorkflowAsService"
        └── presentation_modes
              ├── ContextMenu   = 1   ← 决定是否出现在右键菜单
              ├── FinderPreview = 1
              ├── ServicesMenu  = 1
              └── TouchBar      = 1
```

全新安装的服务在这里**没有任何记录**，右键菜单里就可能不出现。这正是「服务列表里看得见、
右键菜单里找不到」的成因。而且这份偏好属于系统状态，**不随 git 仓库分发**——所以每台机器
首次安装都可能遇到，`install.sh` 因此主动写入这条记录。

键名前缀是字面量 `(null)`，因为 workflow 的 `Info.plist` 里没有 `CFBundleIdentifier`；
Automator 自己保存的 workflow 同样如此。

## 二次开发

直接双击 `Copy Path.workflow` 会用「自动操作」打开，可图形化修改其中的 shell 脚本，改完重新执行 `./install.sh` 生效。

把脚本换成下面这些，就能得到其它变体：

```bash
# 复制为 file:// URL（单选场景）
printf 'file://%s' "$1" | pbcopy

# 只复制文件名
printf '%s' "${1##*/}" | pbcopy

# 把家目录前缀替换为 ~
printf '%s' "${out/#$HOME/~}" | pbcopy
```

## 顺带一提：系统内置的等价操作

macOS 本身已有类似能力，无需安装任何东西：

- 在 Finder 中选中文件，**按住 Option(⌥)**，右键菜单里的「拷贝 xxx」会变成「**拷贝 xxx 为路径名称**」
- 或直接按 **⌥⌘C**

本项目的价值在于：不必按修饰键、菜单项固定可见、可绑定快捷键，且脚本行为可以自由定制。
