# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Build Commands
- `cargo run` - Build and run the desktop application (requires libsciter library)
- `python3 build.py --flutter` - Build Flutter version (desktop)
- `python3 build.py --flutter --release` - Build Flutter version in release mode
- `python3 build.py --hwcodec` - Build with hardware codec support
- `python3 build.py --vram` - Build with VRAM feature (Windows only)
- `cargo build --release` - Build Rust binary in release mode
- `cargo build --features hwcodec` - Build with specific features

### Flutter Mobile Commands
- `cd flutter && flutter build android` - Build Android APK
- `cd flutter && flutter build ios` - Build iOS app
- `cd flutter && flutter run` - Run Flutter app in development mode
- `cd flutter && flutter test` - Run Flutter tests

### Testing
- `cargo test` - Run Rust tests
- `cd flutter && flutter test` - Run Flutter tests

### Platform-Specific Build Scripts
- `flutter/build_android.sh` - Android build script
- `flutter/build_ios.sh` - iOS build script
- `flutter/build_fdroid.sh` - F-Droid build script

## Project Architecture

### Directory Structure
- **`src/`** - Main Rust application code
  - `src/ui/` - Legacy Sciter UI (deprecated, use Flutter instead)
  - `src/server/` - Audio/clipboard/input/video services and network connections
  - `src/client.rs` - Peer connection handling
  - `src/platform/` - Platform-specific code
- **`flutter/`** - Flutter UI code for desktop and mobile
- **`libs/`** - Core libraries
  - `libs/hbb_common/` - Video codec, config, network wrapper, protobuf, file transfer utilities
  - `libs/scrap/` - Screen capture functionality
  - `libs/enigo/` - Platform-specific keyboard/mouse control
  - `libs/clipboard/` - Cross-platform clipboard implementation

### Key Components
- **Remote Desktop Protocol**: Custom protocol implemented in `src/rendezvous_mediator.rs` for communicating with rustdesk-server
- **Screen Capture**: Platform-specific screen capture in `libs/scrap/`
- **Input Handling**: Cross-platform input simulation in `libs/enigo/`
- **Audio/Video Services**: Real-time audio/video streaming in `src/server/`
- **File Transfer**: Secure file transfer implementation in `libs/hbb_common/`

### UI Architecture
- **Legacy UI**: Sciter-based (deprecated) - files in `src/ui/`
- **Modern UI**: Flutter-based - files in `flutter/`
  - Desktop: `flutter/lib/desktop/`
  - Mobile: `flutter/lib/mobile/`
  - Shared: `flutter/lib/common/` and `flutter/lib/models/`

## Important Build Notes

### Dependencies
- Requires vcpkg for C++ dependencies: `libvpx`, `libyuv`, `opus`, `aom`
- Set `VCPKG_ROOT` environment variable
- Download appropriate Sciter library for legacy UI support

### Ignore Patterns
When working with files, ignore these directories:
- `target/` - Rust build artifacts
- `flutter/build/` - Flutter build output
- `flutter/.dart_tool/` - Flutter tooling files

### Cross-Platform Considerations
- Windows builds require additional DLLs and virtual display drivers
- macOS builds need proper signing and notarization for distribution
- Linux builds support multiple package formats (deb, rpm, AppImage)
- Mobile builds require platform-specific toolchains (Android SDK, Xcode)

### Feature Flags
- `hwcodec` - Hardware video encoding/decoding
- `vram` - VRAM optimization (Windows only)
- `flutter` - Enable Flutter UI
- `unix-file-copy-paste` - Unix file clipboard support
- `screencapturekit` - macOS ScreenCaptureKit (macOS only)

### Config
All configurations or options are under `libs/hbb_common/src/config.rs` file, 4 types:
- Settings
- Local
- Display
- Built-in

## SoDesk 开发规范（Fork 维护）

本项目是 RustDesk 的 fork，面向游戏工作室客户。开发时必须遵循以下规范以最小化与上游的合并冲突。完整规范见 `CONTRIBUTING.md`。

### 代码隔离原则

- 所有新功能代码放在隔离目录：Flutter → `flutter/lib/studio/`，Rust → `src/studio/`，脚本 → `scripts/`
- 这些目录上游不存在，merge 时零冲突
- 禁止在 `flutter/lib/studio/`、`src/studio/` 和 `scripts/` 之外创建新文件

### 修改上游文件的规范

必须用 Hook 注释标记包裹改动，改动收敛为最少行数：

```dart
// ===== SoDesk Studio Hook =====
import 'package:flutter_hbb/studio/pages/studio_home_page.dart';
// ===== End SoDesk Studio Hook =====
```

```rust
// ===== SoDesk Studio Hook =====
#[cfg(feature = "studio")]
use crate::studio;
// ===== End SoDesk Studio Hook =====
```

每次修改上游文件后，必须同步更新 `PATCHES.md`。

### 分支策略

| 分支 | 职责 |
|------|------|
| `master` | 纯净跟踪 upstream/master |
| `develop` | 集成分支 |
| `custom/*` | 功能分支（screen-wall, background-input, ui-overhaul 等） |

同步上游：`./scripts/sync_upstream.sh`，使用 merge 而非 rebase。

### Rust Feature Flags

自定义功能用 feature flag 隔离：`studio`、`studio-screen-wall`、`studio-bg-input`。对上游 Rust 代码的修改用 `#[cfg(feature = "studio")]` 条件编译包裹。

### Flutter 开发规范

- 组合优先于修改：包装上游组件而非直接改源码
- 颜色统一使用 `StudioTheme` 常量（`flutter/lib/studio/studio_theme.dart`）
- 状态管理使用 GetX（`.obs`、`Obx`、`GetxController`）

### 提交规范

```
type(scope): description
# 例：feat(screen-wall): 实现屏幕墙网格布局
# type: feat / fix / refactor / docs / chore
# scope: studio / screen-wall / bg-input / ui / upstream-sync
```

### Studio 目录结构

```
flutter/lib/studio/
├── pages/          # 页面（screen_wall_page.dart, studio_home_page.dart）
├── widgets/        # 组件（wall_cell_widget.dart, studio_nav_sidebar.dart）
├── models/         # 模型（screen_wall_model.dart, device_group.dart）
├── studio.dart     # library 声明
└── studio_theme.dart  # 深色科技风主题
```
