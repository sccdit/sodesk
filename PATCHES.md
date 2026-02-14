# SoDesk 上游文件改动追踪

本文件记录所有对 RustDesk 上游文件的修改，用于 merge upstream 时快速定位冲突点。

每次修改上游文件时，必须同步更新此文件。

## 改动清单

| 文件路径 | 改动类型 | 说明 | 分支 |
|---------|---------|------|------|
| `flutter/lib/desktop/pages/desktop_tab_page.dart` | 替换组件 | L5: 添加 StudioHomePage import；L55-57: 替换 DesktopHomePage 为 StudioHomePage | custom/ui-overhaul |
| `Cargo.toml` | 添加 feature | [features] 部分添加 studio、studio-screen-wall、studio-bg-input feature flags | custom/ui-overhaul |
| `src/lib.rs` | 添加模块 | 末尾添加 `#[cfg(feature = "studio")] mod studio;` 条件编译引入 | custom/ui-overhaul |

## 统计

- 上游文件改动数：3
- 涉及分支：custom/ui-overhaul
