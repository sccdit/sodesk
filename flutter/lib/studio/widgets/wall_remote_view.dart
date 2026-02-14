import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/model.dart';
import '../models/screen_wall_session.dart';
import '../studio_theme.dart';
import 'wall_texture_renderer.dart';

/// Read-only remote desktop view for embedding in screen wall cells.
///
/// Renders the remote desktop texture without input forwarding.
/// Receives the FFI instance from [ScreenWallSession] — does NOT create
/// its own connection. Connection lifecycle is managed by the session.
class WallRemoteView extends StatefulWidget {
  final ScreenWallSession session;
  final VoidCallback? onDoubleClick;

  const WallRemoteView({
    Key? key,
    required this.session,
    this.onDoubleClick,
  }) : super(key: key);

  @override
  State<WallRemoteView> createState() => WallRemoteViewState();
}

class WallRemoteViewState extends State<WallRemoteView> {
  FFI get ffi => widget.session.ffi!;
  SessionID get sessionId => ffi.sessionId;

  /// Delegate reconnect to the owning session.
  void reconnect() {
    widget.session.reconnect();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onDoubleClick,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          color: StudioTheme.cellBg,
          child: Obx(() => _buildContent()),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final state = widget.session.state.value;
    switch (state) {
      case WallSessionState.disconnected:
      case WallSessionState.connecting:
        return _buildConnecting();
      case WallSessionState.connected:
        return _buildRemoteView();
      case WallSessionState.error:
        return _buildError();
    }
  }

  Widget _buildConnecting() {
    return Stack(
      children: [
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: StudioTheme.accentCyan,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '连接中...',
                style: TextStyle(
                  color: StudioTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        _buildNameOverlay(),
      ],
    );
  }

  Widget _buildRemoteView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Remote desktop texture
        WallTextureRenderer(
          ffi: ffi,
          placeholder: _buildConnecting(),
        ),
        // Semi-transparent overlay with peer name
        _buildNameOverlay(),
      ],
    );
  }

  Widget _buildError() {
    final errMsg = widget.session.errorMessage;
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: StudioTheme.accentRed,
                size: 28,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  errMsg != null && errMsg.isNotEmpty ? errMsg : '连接失败',
                  style: const TextStyle(
                    color: StudioTheme.textSecondary,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: reconnect,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: StudioTheme.accentCyan),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '重试',
                      style: TextStyle(
                        color: StudioTheme.accentCyan,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildNameOverlay(),
      ],
    );
  }

  Widget _buildNameOverlay() {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              StudioTheme.primaryBg.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.session.peerName,
                style: const TextStyle(
                  color: StudioTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Obx(() => _buildStatusDot()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDot() {
    Color color;
    switch (widget.session.state.value) {
      case WallSessionState.connected:
        color = StudioTheme.accentGreen;
        break;
      case WallSessionState.connecting:
        color = StudioTheme.accentOrange;
        break;
      case WallSessionState.error:
        color = StudioTheme.accentRed;
        break;
      case WallSessionState.disconnected:
        color = StudioTheme.textHint;
        break;
    }
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: widget.session.state.value == WallSessionState.connected
            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
            : null,
      ),
    );
  }
}
