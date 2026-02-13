#!/bin/bash
set -e

# ============================================================
# SoDesk macOS 开发环境一键安装脚本
# 适用于 Apple Silicon (arm64) macOS
# 安装完成后支持 Flutter 热加载开发
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ---- Step 0: Xcode ----
info "Step 0: 切换 xcode-select 到 Xcode.app..."
if [ -d "/Applications/Xcode.app" ]; then
    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    sudo xcodebuild -license accept 2>/dev/null || true
    info "Xcode: $(xcodebuild -version | head -1)"
else
    error "未找到 /Applications/Xcode.app，请先从 App Store 安装 Xcode"
    exit 1
fi

# ---- Step 1: Homebrew 依赖 ----
info "Step 1: 安装 Homebrew 依赖..."
brew install cmake nasm yasm pkg-config ninja cocoapods curl wget 2>/dev/null || true
info "Homebrew 依赖安装完成"

# ---- Step 2: Rust ----
info "Step 2: 安装 Rust 工具链..."
if command -v rustc &>/dev/null; then
    info "Rust 已安装: $(rustc --version)"
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
    source "$HOME/.cargo/env"
    info "Rust 安装完成: $(rustc --version)"
fi

# 确保 cargo env 在当前 shell 可用
source "$HOME/.cargo/env" 2>/dev/null || true

# ---- Step 3: Flutter ----
info "Step 3: 安装 Flutter SDK..."
FLUTTER_DIR="$HOME/flutter"
if command -v flutter &>/dev/null; then
    info "Flutter 已安装: $(flutter --version | head -1)"
elif [ -d "$FLUTTER_DIR" ]; then
    info "Flutter 目录已存在，添加到 PATH"
else
    info "克隆 Flutter SDK (stable channel)..."
    git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_DIR"
fi

# 添加 Flutter 到 PATH（当前 session）
export PATH="$FLUTTER_DIR/bin:$PATH"

# 写入 shell profile（持久化）
SHELL_PROFILE=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_PROFILE="$HOME/.bashrc"
elif [ -f "$HOME/.bash_profile" ]; then
    SHELL_PROFILE="$HOME/.bash_profile"
fi

if [ -n "$SHELL_PROFILE" ]; then
    # Rust PATH
    if ! grep -q '.cargo/env' "$SHELL_PROFILE" 2>/dev/null; then
        echo '' >> "$SHELL_PROFILE"
        echo '# Rust' >> "$SHELL_PROFILE"
        echo 'source "$HOME/.cargo/env"' >> "$SHELL_PROFILE"
    fi
    # Flutter PATH
    if ! grep -q 'flutter/bin' "$SHELL_PROFILE" 2>/dev/null; then
        echo '' >> "$SHELL_PROFILE"
        echo '# Flutter' >> "$SHELL_PROFILE"
        echo "export PATH=\"\$HOME/flutter/bin:\$PATH\"" >> "$SHELL_PROFILE"
    fi
    # VCPKG_ROOT
    if ! grep -q 'VCPKG_ROOT' "$SHELL_PROFILE" 2>/dev/null; then
        echo '' >> "$SHELL_PROFILE"
        echo '# vcpkg' >> "$SHELL_PROFILE"
        echo "export VCPKG_ROOT=\"\$HOME/vcpkg\"" >> "$SHELL_PROFILE"
    fi
    info "已写入 $SHELL_PROFILE"
fi

# 预下载 Flutter 工具
flutter precache --macos 2>/dev/null || true

# ---- Step 4: vcpkg + C++ 依赖 ----
info "Step 4: 安装 vcpkg 和 C++ 依赖..."
VCPKG_DIR="$HOME/vcpkg"
export VCPKG_ROOT="$VCPKG_DIR"

if [ -d "$VCPKG_DIR" ]; then
    info "vcpkg 目录已存在"
else
    git clone https://github.com/microsoft/vcpkg.git "$VCPKG_DIR"
    "$VCPKG_DIR/bootstrap-vcpkg.sh" -disableMetrics
fi

info "安装 vcpkg 包 (libvpx, libyuv, opus, aom)... 这一步耗时较长"
"$VCPKG_DIR/vcpkg" install libvpx libyuv opus aom --triplet arm64-osx || {
    warn "vcpkg 安装部分包失败，可能需要手动处理"
}

# ---- Step 5: Flutter 项目依赖 ----
info "Step 5: 安装 Flutter 项目依赖..."
cd "$PROJECT_DIR/flutter"
flutter pub get

# ---- Step 6: 首次编译 Rust native library ----
info "Step 6: 编译 Rust native library (首次编译较慢)..."
cd "$PROJECT_DIR"
# 生成 Flutter-Rust bridge 代码并编译
python3 build.py --flutter 2>&1 | tail -20 || {
    warn "build.py 执行失败，尝试直接 cargo build..."
    cargo build --features flutter --lib 2>&1 | tail -10 || {
        warn "Rust 编译失败，可能需要手动排查依赖问题"
    }
}

# ---- Step 7: 验证 ----
info "========================================="
info "环境检查:"
echo ""
echo "  Xcode:   $(xcodebuild -version 2>/dev/null | head -1 || echo 'N/A')"
echo "  Rust:    $(rustc --version 2>/dev/null || echo 'N/A')"
echo "  Cargo:   $(cargo --version 2>/dev/null || echo 'N/A')"
echo "  Flutter: $(flutter --version 2>/dev/null | head -1 || echo 'N/A')"
echo "  cmake:   $(cmake --version 2>/dev/null | head -1 || echo 'N/A')"
echo "  vcpkg:   $VCPKG_ROOT"
echo "  CocoaPods: $(pod --version 2>/dev/null || echo 'N/A')"
echo ""

# Flutter doctor
info "运行 flutter doctor..."
flutter doctor 2>&1 || true

echo ""
info "========================================="
info "安装完成！"
echo ""
info "热加载开发命令："
echo ""
echo "  cd $PROJECT_DIR/flutter"
echo "  flutter run -d macos"
echo ""
info "说明："
echo "  - flutter run 启动后，按 'r' 热重载，按 'R' 热重启"
echo "  - studio/ 目录下的 UI 改动支持热重载"
echo "  - Rust 层改动需要重新运行 python3 build.py --flutter"
echo "  - 如果遇到 PATH 问题，请重新打开终端或执行: source $SHELL_PROFILE"
echo ""
