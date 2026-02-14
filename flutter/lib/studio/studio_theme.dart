import 'package:flutter/material.dart';

class StudioTheme {
  static const String appName = 'SoDesk';

  // 主色调 - 深色科技风
  static const Color primaryBg = Color(0xFF16162A);
  static const Color surfaceBg = Color(0xFF1E1E3A);
  static const Color navBarBg = Color(0xFF12122A);
  static const Color toolbarBg = Color(0xFF1E1E3A);

  // 强调色
  static const Color accentBlue = Color(0xFF0078D4);
  static const Color accentCyan = Color(0xFF00D4FF);
  static const Color accentGreen = Color(0xFF00C853);
  static const Color accentRed = Color(0xFFFF5252);
  static const Color accentOrange = Color(0xFFFF9800);

  // 文字
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textHint = Color(0xFF616161);

  // 边框和分割线
  static const Color border = Color(0xFF2A2A4A);
  static const Color divider = Color(0xFF2A2A4A);

  // 屏幕墙专用
  static const Color cellBg = Color(0xFF1A1A2E);
  static const Color cellBorder = Color(0xFF2A2A4A);
  static const Color cellSelected = Color(0xFF00D4FF);
  static const Color cellHover = Color(0xFF252545);

  // 覆盖层 / UI 辅助色
  static const Color overlayLight = Color(0x61FFFFFF);   // ~Colors.white38
  static const Color overlaySubtle = Color(0x1FFFFFFF);  // ~Colors.white12
  static const Color overlayScrim = Color(0x8A000000);   // ~Colors.black54
  static const Color overlayText = Color(0xB3FFFFFF);    // ~Colors.white70
  static const Color btnBorderIdle = Color(0x3DFFFFFF);  // ~Colors.white24
  static const Color btnTextIdle = Color(0x8AFFFFFF);    // ~Colors.white54
  static const Color hoverOverlay = Color(0x14FFFFFF);   // ~Colors.white.withOpacity(0.08)

  // ── 布局常量 ──
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const int maxConcurrentConnections = 16;
  static const double toolbarHeight = 48.0;
  static const double statusBarHeight = 24.0;
  static const double gridSpacing = 2.0;
  static const double dialogWidth = 400.0;
  static const double dialogHeight = 500.0;
  static const double navSidebarWidth = 60.0;
  static const double middlePanelWidth = 250.0;
  static const double defaultWidth = 1920.0;
  static const double defaultHeight = 1080.0;

  StudioTheme._();
}
