# SoDesk 开发规范

本文档定义了 SoDesk 项目（RustDesk fork）的开发规范，核心目标是**最小化与上游的合并冲突**，同时高效开发自定义功能。

---

## 1. 项目结构

```
sodesk/
├── flutter/lib/studio/       # Flutter 自定义代码（上游不存在，零冲突）
│   ├── pages/                 # 自定义页面（屏幕墙、工作室首页等）
│   ├── widgets/               # 自定义组件
│   ├── models/                # 数据模型和状态管理
│   ├── studio.dart            # library 声明
│   └── studio_theme.dart      # 主题定义
├── src/studio/                # Rust 自定义代码（上游不存在，零冲突）
│   └── mod.rs
├── scripts/                   # 自定义脚本
│   └── sync_upstream.sh       # 上游同步脚本
├── CONTRIBUTING.md            # 本文件
├── PATCHES.md                 # 上游文件改动追踪
└── CLAUDE.md                  # AI 辅助开发上下文
```

## 2. 分支策略

| 分支 | 职责 | 来源 |
|------|------|------|
| `master` | 纯净跟踪 upstream/master，只做 merge upstream | upstream/master |
| `develop` | 集成分支，合并 master + 所有 custom 功能 | master |
| `custom/*` | 单功能开发分支 | develop |
| `release/*` | 发布分支 | develop |

### 分支命名规范

```
custom/screen-wall        # 屏幕墙功能
custom/background-input   # 后台键盘功能
custom/background-service # 后台服务
custom/ui-overhaul        # UI 改造
```

### 同步流程

```bash
# 使用同步脚本
./scripts/sync_upstream.sh

# 流程：
# 1. fetch upstream
# 2. master merge upstream/master
# 3. develop merge master
# 4. 各 custom/* 分支 merge develop（非 rebase）
```

### 为什么用 merge 而不是 rebase

- rebase 重写提交历史，多人协作时危险
- rebase 冲突需要逐 commit 解决，merge 只解决一次
- `--force-with-lease` push 在 CI/CD 环境下容易出问题
- merge commit 保留了完整的合并记录，便于追溯

## 3. 代码隔离原则

### 3.1 新功能代码——放独立目录

所有新功能的业务逻辑写在隔离目录中：

- Flutter: `flutter/lib/studio/`
- Rust: `src/studio/`

上游永远不会有这些目录，merge 时零冲突。

### 3.2 修改上游文件——Hook 标记

不可避免要改上游文件时，用统一注释标记包裹改动：

**Flutter (Dart):**
```dart
// ===== SoDesk Studio Hook =====
import 'package:flutter_hbb/studio/pages/studio_home_page.dart';
// ===== End SoDesk Studio Hook =====
```

**Rust:**
```rust
// ===== SoDesk Studio Hook =====
#[cfg(feature = "studio")]
use crate::studio;
// ===== End SoDesk Studio Hook =====
```

### 3.3 改动收敛原则

对上游文件的修改尽量收敛为：
- 1 行 import + 1 行调用
- 或 1 个 `#[cfg(feature)]` 块

**正确示例：**
```dart
// 上游文件 desktop_tab_page.dart
// ===== SoDesk Studio Hook =====
import 'package:flutter_hbb/studio/pages/studio_home_page.dart';
// ===== End SoDesk Studio Hook =====

// 使用处只替换一行：
page: StudioHomePage(key: const ValueKey(kTabLabelHomePage)),
```

**错误示例：**
```dart
// 不要在上游文件中写大段业务逻辑
// 不要在上游文件中定义新的类或函数
```

## 4. Rust Feature Flag 规范

### Cargo.toml 定义

```toml
[features]
studio = []
studio-screen-wall = ["studio"]
studio-bg-input = ["studio"]
```

### 条件编译

```rust
// 在上游 Rust 文件中
#[cfg(feature = "studio")]
use crate::studio;

fn some_upstream_function() {
    // 上游原有逻辑...

    #[cfg(feature = "studio-screen-wall")]
    studio::screen_wall::on_event(&data);
}
```

不开 feature 时，代码完全等同于上游。

## 5. Flutter 开发规范

### 5.1 组合优先于修改

扩展上游组件时，优先用包装/组合：

```dart
// 正确：包装上游组件
class RemoteViewCell extends StatelessWidget {
  Widget build(context) {
    return ClipRect(
      child: FittedBox(
        child: RemotePage(id: peerId, ...),  // 复用上游组件
      ),
    );
  }
}

// 错误：直接修改 RemotePage 源码
```

### 5.2 主题颜色

统一使用 `StudioTheme` 中定义的颜色常量：

```dart
import 'package:flutter_hbb/studio/studio_theme.dart';

Container(
  color: StudioTheme.primaryBg,
  child: Text('Hello', style: TextStyle(color: StudioTheme.textPrimary)),
)
```

### 5.3 状态管理

使用 GetX，遵循现有模式：

```dart
class MyController extends GetxController {
  final items = <Item>[].obs;
  final selectedId = ''.obs;
}

// 注册
Get.put(MyController());

// 使用
Obx(() => Text(controller.selectedId.value));
```

### 5.4 文件命名

- 页面：`studio/pages/xxx_page.dart`
- 组件：`studio/widgets/xxx_widget.dart` 或 `xxx.dart`
- 模型：`studio/models/xxx_model.dart` 或 `xxx.dart`

## 6. 改动追踪

维护 `PATCHES.md` 文件，记录所有对上游文件的改动。

每次修改上游文件时，必须同步更新 PATCHES.md。格式：

```markdown
| 文件路径 | 改动类型 | 说明 |
|---------|---------|------|
| flutter/lib/desktop/pages/desktop_tab_page.dart | 替换组件 | 用 StudioHomePage 替换 DesktopHomePage |
```

merge upstream 前先查看此文件，提前预判冲突点。

## 7. 提交规范

### Commit Message 格式

```
type(scope): description

# 示例
feat(screen-wall): 实现屏幕墙网格布局
fix(bg-input): 修复后台键盘事件丢失问题
refactor(studio): 提取公共主题常量
docs(contributing): 更新开发规范
chore(upstream-sync): 同步上游 v1.3.0
```

**type 类型：**
- `feat` — 新功能
- `fix` — 修复 bug
- `refactor` — 重构（不改变功能）
- `docs` — 文档
- `chore` — 构建/工具/依赖等杂项

**scope 范围：**
- `studio` — 通用 studio 代码
- `screen-wall` — 屏幕墙功能
- `bg-input` — 后台键盘功能
- `ui` — UI 相关
- `upstream-sync` — 上游同步

### PR 流程

```
custom/* → develop（PR + Code Review）→ 测试 → release/*（打 tag 发布）
```

## 8. 注意事项

- 不要在 `flutter/lib/studio/` 之外创建新的 Dart 文件
- 不要在 `src/studio/` 之外创建新的 Rust 文件
- 每次 merge upstream 后运行完整测试
- 保持 PATCHES.md 与实际改动同步
- 上游文件的改动越少越好，能不改就不改
