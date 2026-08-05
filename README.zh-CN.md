# OverShelf

一个 macOS 上的「下拉抽屉」式效率工具：把剪贴板历史、文件暂存、快速笔记、待办
事项收进同一个从屏幕顶部逐步展开的面板里。

平时完全隐藏，需要时一唤即出，用完自动缩回，不占 Dock、不占桌面。使用 Swift 与
SwiftUI 构建。

> OverShelf 是一款原创应用，借鉴了经典的「下拉抽屉」交互形态，与任何现有产品无关联。

![OverShelf 顶边展开动效](docs/screenshots/App.png)

---

## 功能

### 一个面板，四件小事

- **剪贴板历史**：自动记录你复制过的文本、图片、文件。可浏览最近条目、搜索、收藏常用
  条目，点击任意一条即可重新粘贴。历史在应用重启、系统重启后仍然保留。
- **文件暂存**：临时停放区。把文件拖进来「搁着」，之后拖到任意应用或 Finder 位置使用。
  文件本体不会被移动或复制，只是引用。跨窗口、跨桌面拖拽的中转站。
- **笔记**：桌面便利贴式笔记，想建多少张建多少张。支持全文搜索、置顶重要笔记，可在「编辑」
  与「Markdown 预览」之间切换（预览支持 KaTeX 数学公式 `$$...$$` 与 `$...$`）。
- **待办**：轻量任务清单，支持搜索、筛选（全部 / 未完成 / 已完成）、优先级、截止日期、
  一键完成。

### 唤出与收回

| 触发方式 | 动作 |
| --- | --- |
| `Cmd + Shift + C` | 全局快捷键唤出 / 收回面板 |
| 按住 `Cmd` + 鼠标移到屏幕顶边 | 面板从顶边逐步展开 |
| 拖文件到屏幕顶边 | 面板自动弹出接住拖拽 |

面板从屏幕顶边向下逐步展开；点击面板外区域、再按一次快捷键或选择菜单项即可收回。
内容始终保持最终布局尺寸，不再把整个窗口从屏幕外长距离移动进来。

### 自适应外观

- 使用不透明的柔和分层表面，不再使用毛玻璃模糊。
- 默认跟随 macOS 外观。
- 可在「偏好设置 > 通用」中选择「系统 / 浅色 / 深色」。
- 遵循 macOS 的「减少动态效果」辅助功能设置。

### 面板可自由定制

- 拖动面板之间的分隔条可调整每个面板的宽度。
- 在「偏好设置 > 面板」中拖拽重排面板顺序。
- 可从面板管理菜单把任意面板分离成悬浮置顶窗口；关闭悬浮窗或使用菜单即可重新归位。
- 可隐藏不常用的面板，在「偏好设置 > 面板」或菜单栏「面板」子菜单中恢复。

### 菜单栏

点击菜单栏图标（堆叠图标）可看到：

- **Show/Hide OverShelf**（`Cmd + Shift + C`）
- **New Note** / **New Todo**：新建并唤出面板
- **Clear Clipboard History**：清空剪贴板历史
- **Panels**：显示 / 隐藏单个面板
- **Preferences...**（`Cmd + ,`）
- **Quit OverShelf**（`Cmd + Q`）

### 数据与隐私

所有数据以 JSON 形式本地存储在：

```txt
~/Library/Application Support/OverShelf/
```

无云同步、无遥测、无任何网络请求，你的数据始终留在本机。

---

## 环境要求

- macOS 14.0（Sonoma）或更高版本
- Apple Silicon（arm64）；当前发布包不包含 Intel 二进制文件
- 仅从源码构建时需要 Xcode 命令行工具（`xcode-select --install`）

---

## 通过 Homebrew 安装

正式发布的 Cask 已可从 `ALLENYGY/tap` 安装：

```bash
brew tap ALLENYGY/tap
brew install --cask overshelf
```

后续升级或卸载：

```bash
brew upgrade --cask overshelf
brew uninstall --cask overshelf
```

如需同时删除剪贴板历史、笔记、待办和偏好设置：

```bash
brew uninstall --cask --zap overshelf
```

应用目前采用 ad-hoc 签名。首次启动时，macOS 可能要求右键点击
**OverShelf.app > 打开**，或在「系统设置 > 隐私与安全性」中允许。

---

## 构建与运行

本项目直接用 `swiftc` 编译（无 SPM 依赖，无需 Xcode 工程）。一个脚本即可完成编译、打包、
签名与启动。

```bash
# 编译、打包并启动
./script/build_and_run.sh run

# 仅编译（不启动）
./script/build_and_run.sh build

# 运行测试套件
./script/build_and_run.sh test

# 编译并验证可正常启动后退出
./script/build_and_run.sh verify
```

构建产物位于 `dist/OverShelf.app`。

首次启动注意：

- 应用为 ad-hoc 签名，首次打开 macOS 可能弹出 Gatekeeper 提示；右键 > **打开**
  （或在「系统设置 > 隐私与安全性 > 仍要打开」中允许）。
- 触顶与拖拽追踪可能需要在「系统设置 > 隐私与安全性」中授予
  **辅助功能** 或 **输入监控** 权限；Carbon 全局快捷键本身不需要辅助功能权限。

---

## 使用方法

1. 启动 OverShelf，它驻留在菜单栏，不会出现在 Dock。
2. 按 `Cmd + Shift + C`（或按住 `Cmd` 把鼠标移到屏幕顶边）唤出面板。
3. 复制内容、暂存文件、随手记笔记、跟踪任务。
4. 点击面板外区域（或再按一次快捷键）收回面板。

动效演示见下方，英文说明见 [README](README.md)。

---

## 目录结构

```txt
OverShelf/
  App/            # 应用入口、AppDelegate、菜单栏菜单
  Models/         # AppSettings, ClipboardItem, Note, StagedFile, TodoItem
  Services/       # PersistenceManager, ClipboardMonitor, NotesManager 等
  Views/          # 各面板视图、设置、共享 Markdown 预览与主题
  Window/         # DropDownPanel, WindowManager, TopEdgeTracker, 快捷键
  Resources/      # AppIcon、内置 Markdown 库（markdown-it, KaTeX, DOMPurify）
Tests/            # 迁移、服务、边缘追踪、面板帧、Markdown 测试
script/           # 构建、静态截图与动图生成脚本
dist/             # 构建产物 OverShelf.app（已 gitignore）
```

---

## 技术说明

- **Swift / SwiftUI**，目标 macOS 14+。使用 `@Observable`、`MenuBarExtra`、`Settings` 场景。
- **WebKit** 驱动 Markdown 预览。渲染器（`markdown-it`）、数学（`KaTeX`）、净化器
  （`DOMPurify`）全部离线内置在 `OverShelf/Resources/Markdown/`，无网络、无 CDN。
- **无第三方 Swift 依赖**，全部使用标准库与系统框架。
- 自定义触顶鼠标追踪（`TopEdgeTracker`）与裁切式展开状态（`WindowManager`），
  不依赖任何私有 API。

---

## 许可证

MIT，见 [LICENSE](LICENSE)。`OverShelf/Resources/Markdown/` 中的 JavaScript 库遵循各自许可证，
详见 `OverShelf/Resources/Markdown/THIRD_PARTY_NOTICES.md`。

---

## 致谢

灵感来自 Unclutter 等应用带火的「下拉抽屉」交互形态。OverShelf 为独立实现，从零编写。
返回 [English README](README.md)
