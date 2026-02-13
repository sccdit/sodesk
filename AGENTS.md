# AGENTS.md

本文件为 AI Agent 提供 SoDesk 项目的开发规范上下文。所有 Agent 在修改代码前必须遵循以下规则。

## 项目背景

SoDesk 是 RustDesk 的 fork，面向游戏工作室客户。需要长期跟踪上游更新，同时维护屏幕墙、后台键盘等自定义功能。

## 核心规则

### 1. 代码隔离——绝对优先

- 新 Flutter 代码只能放在 `flutter/lib/studio/` 目录下
- 新 Rust 代码只能放在 `src/studio/` 目录下
- 新脚本放在 `scripts/` 目录下
- **禁止**在上述目录之外创建新文件

### 2. 修改上游文件——最小侵入

当必须修改上游文件时：

- 用 `// ===== SoDesk Studio Hook =====` 和 `// ===== End SoDesk Studio Hook =====` 注释包裹所有改动
- 改动收敛为 1 行 import + 1 行调用，不要在上游文件中写业务逻辑
- 修改后必须更新 `PATCHES.md`

Dart 示例：
```dart
// ===== SoDesk Studio Hook =====
import 'package:flutter_hbb/studio/pages/studio_home_page.dart';
// ===== End SoDesk Studio Hook =====
```

Rust 示例：
```rust
// ===== SoDesk Studio Hook =====
#[cfg(feature = "studio")]
use crate::studio;
// ===== End SoDesk Studio Hook =====
```

### 3. Rust 条件编译

对上游 Rust 文件的逻辑修改必须用 feature flag 包裹：

```rust
#[cfg(feature = "studio")]
studio::some_function(&data);
```

可用 feature：`studio`、`studio-screen-wall`、`studio-bg-input`

### 4. Flutter 开发规范

- 组合优先于修改：用包装/组合上游组件，不直接改上游类的源码
- 颜色使用 `StudioTheme` 常量（`flutter/lib/studio/studio_theme.dart`）
- 状态管理使用 GetX（`.obs`、`Obx`、`GetxController`）
- 文件命名：`studio/pages/xxx_page.dart`、`studio/widgets/xxx.dart`、`studio/models/xxx.dart`

### 5. 提交规范

```
type(scope): description

type: feat / fix / refactor / docs / chore
scope: studio / screen-wall / bg-input / ui / upstream-sync
```

### 6. 分支策略

| 分支 | 职责 |
|------|------|
| `master` | 纯净跟踪 upstream/master，只做 merge |
| `develop` | 集成分支，master + 所有 custom 功能 |
| `custom/*` | 单功能分支，基于 develop，用 merge 合并（非 rebase） |
| `release/*` | 发布分支，从 develop 切出 |

## 关键文件索引

| 文件 | 用途 |
|------|------|
| `CONTRIBUTING.md` | 完整开发规范（中文） |
| `PATCHES.md` | 上游文件改动追踪表 |
| `CLAUDE.md` | 构建命令和项目架构 |
| `scripts/sync_upstream.sh` | 上游同步脚本 |
| `flutter/lib/studio/studio_theme.dart` | 深色科技风主题定义 |
| `flutter/lib/studio/pages/screen_wall_page.dart` | 屏幕墙页面 |
| `flutter/lib/studio/pages/studio_home_page.dart` | 工作室主页 |
| `flutter/lib/studio/models/screen_wall_model.dart` | 屏幕墙状态管理 |

## Studio 目录结构

```
flutter/lib/studio/
├── pages/
│   ├── screen_wall_page.dart      # 屏幕墙（网格布局 + 工具栏 + 状态栏）
│   └── studio_home_page.dart      # 主页（导航栏 + 中间面板 + 工作区）
├── widgets/
│   ├── wall_cell_widget.dart      # 屏幕墙格子组件
│   ├── studio_nav_sidebar.dart    # 左侧导航栏
│   └── studio_device_tree.dart    # 设备树（分组 + 多选 + 搜索）
├── models/
│   ├── screen_wall_model.dart     # ScreenWallController + ScreenWallCell
│   └── device_group.dart          # DeviceGroup 数据模型
├── studio.dart                    # library 声明
└── studio_theme.dart              # 主题色系
```
