import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/model.dart';
import '../models/screen_wall_session.dart';
import '../studio_theme.dart';
import 'wall_texture_renderer.dart';

/// Fullscreen overlay for a single remote desktop cell in the screen wall.
///
/// Shows the remote desktop texture at full size with additional info
/// (peer ID, connection duration, quality) and optional input forwarding.
/// Receives a [ScreenWallSession] directly — no GlobalKey dependency.
class WallFullscreenView extends StatefulWidget {
  final ScreenWallSession session;
  final VoidCallback onExit;

  const WallFullscreenView({
    Key? key,
    required this.session,
    required this.onExit,
  }) : super(key: key);

  @override
  State<WallFullscreenView> createState() => _WallFullscreenViewState();
}

class _WallFullscreenViewState extends State<WallFullscreenView> {
  final _showToolbar = true.obs;
  final _inputEnabled = false.obs;
  final FocusNode _focusNode = FocusNode(debugLabel: 'wallFullscreen');

  FFI get _ffi => widget.session.ffi!;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    // Restore view-only if input was enabled during fullscreen.
    if (_inputEnabled.isTrue) {
      _toggleViewOnly();
    }
    _focusNode.dispose();
    super.dispose();
  }

  /// Toggle the view-only session option via FFI.
  void _toggleViewOnly() {
    final sid = widget.session.sessionId;
    if (sid != null) {
      bind.sessionToggleOption(sessionId: sid, value: 'view-only');
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onExit();
        }
      },
      child: Container(
        color: StudioTheme.primaryBg,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Remote desktop texture (full area)
            GestureDetector(
              onDoubleTap: widget.onExit,
              onTap: () => _showToolbar.toggle(),
              child: WallTextureRenderer(ffi: _ffi),
            ),
            // Top info bar
            Obx(() => _showToolbar.isTrue
                ? _buildTopBar()
                : const SizedBox.shrink()),
            // Bottom toolbar
            Obx(() => _showToolbar.isTrue
                ? _buildBottomBar()
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final connectedAt = widget.session.connectedAt;
    final elapsed = connectedAt != null
        ? DateTime.now().difference(connectedAt)
        : Duration.zero;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [StudioTheme.overlayScrim, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.desktop_windows, color: StudioTheme.accentCyan, size: 16),
            const SizedBox(width: 8),
            Text(
              widget.session.peerName,
              style: const TextStyle(
                color: StudioTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'ID: ${widget.session.peerId}',
              style: const TextStyle(
                color: StudioTheme.textSecondary,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            const Icon(Icons.timer_outlined, color: StudioTheme.textSecondary, size: 14),
            const SizedBox(width: 4),
            Text(
              _formatDuration(elapsed),
              style: const TextStyle(
                color: StudioTheme.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [StudioTheme.overlayScrim, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _toolbarButton(
              icon: Icons.fullscreen_exit,
              label: '退出全屏',
              onTap: widget.onExit,
            ),
            const SizedBox(width: 16),
            Obx(() => _toolbarButton(
                  icon: _inputEnabled.isTrue
                      ? Icons.mouse
                      : Icons.mouse_outlined,
                  label: _inputEnabled.isTrue ? '输入已启用' : '启用输入',
                  active: _inputEnabled.isTrue,
                  onTap: () {
                    _toggleViewOnly();
                    _inputEnabled.toggle();
                  },
                )),
            const SizedBox(width: 16),
            _toolbarButton(
              icon: Icons.refresh,
              label: '刷新',
              onTap: () => widget.session.reconnect(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? StudioTheme.accentCyan.withOpacity(0.2)
                : StudioTheme.hoverOverlay,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? StudioTheme.accentCyan : StudioTheme.btnBorderIdle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? StudioTheme.accentCyan : StudioTheme.overlayText, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? StudioTheme.accentCyan : StudioTheme.overlayText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
