# DropShelf

一个 macOS 上的「下拉抽屉」式效率工具：把剪贴板历史、文件暂存、快速笔记、待办
事项收进同一个从屏幕顶部滑下的面板里。

平时完全隐藏，需要时一唤即出，用完自动缩回，不占 Dock、不占桌面。使用 Swift 与
SwiftUI 构建。

> DropShelf 是一款原创应用，借鉴了经典的「下拉抽屉」交互形态，与任何现有产品无关联。

![DropShelf 面板](docs/screenshots/App.png)

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
| 按住 `Cmd` + 鼠标移到屏幕顶边 | 面板从顶部滑下 |
| 拖文件到屏幕顶边 | 面板自动弹出接住拖拽 |

面板从屏幕顶部滑下展开；点击面板外区域、再按一次快捷键或选择菜单项即可向上收回。

### 面板可自由定制

- 拖动面板之间的分隔条可调整每个面板的宽度。
- 在「偏好设置 > 面板」中拖拽重排面板顺序。
- 可把任意面板拖出主窗口，变成独立的悬浮置顶窗口；从悬浮窗关闭按钮或面板头部可重新归位。
- 可隐藏不常用的面板，在「偏好设置 > 面板」或菜单栏「面板」子菜单中恢复。

### 菜单栏

点击菜单栏图标（堆叠图标）可看到：

- **Show/Hide DropShelf**（`Cmd + Shift + C`）
- **New Note** / **New Todo**：新建并唤出面板
- **Clear Clipboard History**：清空剪贴板历史
- **Panels**：显示 / 隐藏单个面板
- **Preferences...**（`Cmd + ,`）
- **Quit DropShelf**（`Cmd + Q`）

### 数据与隐私

所有数据以 JSON 形式本地存储在：

```
~/Library/Application Support/DropShelf/
```

无云同步、无遥测、无任何网络请求，你的数据始终留在本机。

---

## 环境要求

- macOS 14.0（Sonoma）或更高版本
- Xcode 命令行工具（`xcode-select --install`）
- Apple Silicon（arm64）；Intel 架构未测试

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

构建产物位于 `dist/DropShelf.app`。

首次启动注意：

- 应用为 ad-hoc 签名，首次打开 macOS 可能弹出 Gatekeeper 提示；右键 > **打开**
  （或在「系统设置 > 隐私与安全性 > 仍要打开」中允许）。
- 全局快捷键与触顶追踪需要 **辅助功能（Accessibility）** 权限，请在
  「系统设置 > 隐私与安全性」中授权给 DropShelf。

---

## 使用方法

1. 启动 DropShelf，它驻留在菜单栏，不会出现在 Dock。
2. 按 `Cmd + Shift + C`（或按住 `Cmd` 把鼠标移到屏幕顶边）唤出面板。
3. 复制内容、暂存文件、随手记笔记、跟踪任务。
4. 点击面板外区域（或再按一次快捷键）收回面板。

截图见下方，英文说明见 [README](README.md)。

---

## 截图

> 截图由 `script/capture_screenshots.sh` 在授权终端 **屏幕录制（Screen Recording）**
> 权限后生成。构建好应用后运行一次，PNG 会输出到 `docs/screenshots/`。

![DropShelf 面板](docs/screenshots/App.png)

> 面板从屏幕顶部滑下，覆盖整屏宽度，剪贴板、文件、笔记、待办并排显示。
> 如需更多截图（设置、菜单栏、单个面板），在终端授予 **屏幕录制** 权限后运行
> `script/capture_screenshots.sh` 即可生成。

---

## 通过 Homebrew 安装（计划中）

发布 GitHub Release 后，DropShelf 可作为 Homebrew Cask 分发。完整 tap 与 formula 配置见
[docs/homebrew.md](docs/homebrew.md)。简而言之，打 tag 发布后：

```bash
brew tap ALLENYGY/tap
brew install --cask dropshelf
```

---

## 目录结构

```
DropShelf/
  App/            # 应用入口、AppDelegate、菜单栏菜单
  Models/         # AppSettings, ClipboardItem, Note, StagedFile, TodoItem
  Services/       # PersistenceManager, ClipboardMonitor, NotesManager 等
  Views/          # 各面板视图、设置、共享 Markdown 预览与主题
  Window/         # DropDownPanel, WindowManager, TopEdgeTracker, 快捷键
  Resources/      # AppIcon、内置 Markdown 库（markdown-it, KaTeX, DOMPurify）
Tests/            # 迁移、服务、边缘追踪、面板帧、Markdown 测试
script/           # build_and_run.sh, capture_screenshots.sh
dist/             # 构建产物 DropShelf.app（已 gitignore）
```

---

## 技术说明

- **Swift / SwiftUI**，目标 macOS 14+。使用 `@Observable`、`MenuBarExtra`、`Settings` 场景。
- **WebKit** 驱动 Markdown 预览。渲染器（`markdown-it`）、数学（`KaTeX`）、净化器
  （`DOMPurify`）全部离线内置在 `DropShelf/Resources/Markdown/`，无网络、无 CDN。
- **无第三方 Swift 依赖**，全部使用标准库与系统框架。
- 自定义触顶鼠标追踪（`TopEdgeTracker`）与定时器驱动的滑动动画（`WindowManager`），
  不依赖任何私有 API。

---

## 许可证

MIT，见 [LICENSE](LICENSE)。`DropShelf/Resources/Markdown/` 中的 JavaScript 库遵循各自许可证，
详见 `DropShelf/Resources/Markdown/THIRD_PARTY_NOTICES.md`。

---

## 致谢

灵感来自 Unclutter 等应用带火的「下拉抽屉」交互形态。DropShelf 为独立实现，从零编写。
返回 [English README](README.md)
