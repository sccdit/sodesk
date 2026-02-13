import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../common.dart';
import '../../consts.dart';
import '../../models/model.dart';
import '../models/screen_wall_session.dart';
import '../studio_theme.dart';

/// Read-only remote desktop view for embedding in screen wall cells.
///
/// Renders the remote desktop texture without input forwarding.
/// Uses the same FFI/TextureModel pipeline as RemotePage but stripped
/// down to display-only mode.
class WallRemoteView extends StatefulWidget {
  final String peerId;
  final String peerName;
  final VoidCallback? onDoubleClick;

  const WallRemoteView({
    Key? key,
    required this.peerId,
    required this.peerName,
    this.onDoubleClick,
  }) : super(key: key);

  @override
  State<WallRemoteView> createState() => WallRemoteViewState();
}

class WallRemoteViewState extends State<WallRemoteView> {
  late FFI _ffi;
  final _connectionState = WallSessionState.disconnected.obs;
  final _errorMessage = ''.obs;
  bool _isDisconnecting = false;

  FFI get ffi => _ffi;
  SessionID get sessionId => _ffi.sessionId;

  @override
  void initState() {
    super.initState();
    _ffi = FFI(null);
    _connect();
  }

  void _connect() {
    _connectionState.value = WallSessionState.connecting;
    _errorMessage.value = '';

    try {
      _ffi.ffiModel.updateEventListener(sessionId, widget.peerId);

      _ffi.imageModel.addCallbackOnFirstImage((String peerId) {
        if (mounted) {
          _connectionState.value = WallSessionState.connected;
        }
      });

      _ffi.start(widget.peerId);
    } catch (e) {
      _connectionState.value = WallSessionState.error;
      _errorMessage.value = e.toString();
    }
  }

  void reconnect() {
    if (_connectionState.value == WallSessionState.connecting ||
        _isDisconnecting) return;
    _isDisconnecting = true;
    _disconnect().then((_) {
      _isDisconnecting = false;
      if (mounted) {
        _ffi = FFI(null);
        _connect();
      }
    });
  }

  Future<void> _disconnect() async {
    try {
      _ffi.textureModel.onRemotePageDispose(true);
      _ffi.imageModel.disposeImage();
      _ffi.cursorModel.disposeImages();
      await _ffi.close(closeSession: true);
    } catch (e) {
      debugPrint('WallRemoteView disconnect error: $e');
    }
  }

  @override
  void dispose() {
    // Synchronously mark state to prevent callbacks after dispose
    _connectionState.value = WallSessionState.disconnected;
    _disconnect().catchError((e) {
      debugPrint('WallRemoteView dispose cleanup error: $e');
    });
    super.dispose();
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
    switch (_connectionState.value) {
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
    return ChangeNotifierProvider.value(
      value: _ffi.ffiModel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Remote desktop texture
          Consumer<FfiModel>(
            builder: (context, ffiModel, _) {
              if (ffiModel.pi.isSet.isFalse ||
                  ffiModel.waitForFirstImage.isTrue) {
                return _buildConnecting();
              }
              return _buildTextureView(ffiModel);
            },
          ),
          // Semi-transparent overlay with peer name
          _buildNameOverlay(),
        ],
      ),
    );
  }

  Widget _buildTextureView(FfiModel ffiModel) {
    final curDisplay = ffiModel.pi.currentDisplay;
    final displays = ffiModel.pi.getCurDisplays();
    if (displays.isEmpty) return const SizedBox.shrink();

    // Ensure textures are created for current display
    _ffi.textureModel.updateCurrentDisplay(curDisplay);

    final displayIndex =
        curDisplay == kAllDisplayValue ? 0 : curDisplay;
    final textureId = _ffi.textureModel.getTextureId(displayIndex);

    return Obx(() {
      if (textureId.value == -1) {
        return _buildConnecting();
      }
      return FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: displays.isNotEmpty
              ? displays[0].width.toDouble()
              : 1920,
          height: displays.isNotEmpty
              ? displays[0].height.toDouble()
              : 1080,
          child: Texture(
            textureId: textureId.value,
            filterQuality: FilterQuality.low,
          ),
        ),
      );
    });
  }

  Widget _buildError() {
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
                  _errorMessage.value.isNotEmpty
                      ? _errorMessage.value
                      : '连接失败',
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
                widget.peerName,
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
    switch (_connectionState.value) {
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
        boxShadow: _connectionState.value == WallSessionState.connected
            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)]
            : null,
      ),
    );
  }
}
