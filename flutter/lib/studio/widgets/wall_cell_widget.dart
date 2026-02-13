import 'package:flutter/material.dart';
import '../models/screen_wall_model.dart';
import '../studio_theme.dart';
import 'device_picker_dialog.dart';

class WallCellWidget extends StatefulWidget {
  final ScreenWallCell cell;
  final int index;
  final bool isSelected;
  final bool isConnecting;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onAddDevice;
  final void Function(String peerId, String peerName)? onDeviceSelected;
  final Set<String> connectedPeerIds;

  const WallCellWidget({
    Key? key,
    required this.cell,
    required this.index,
    required this.isSelected,
    required this.onTap,
    this.isConnecting = false,
    this.onDoubleTap,
    this.onAddDevice,
    this.onDeviceSelected,
    this.connectedPeerIds = const {},
  }) : super(key: key);

  @override
  State<WallCellWidget> createState() => _WallCellWidgetState();
}

class _WallCellWidgetState extends State<WallCellWidget> {
  bool _hovering = false;

  Future<void> _handleAddDevice() async {
    if (widget.onAddDevice != null) {
      widget.onAddDevice!();
      return;
    }
    // Default: open device picker dialog
    final result = await showDevicePickerDialog(
      context,
      connectedPeerIds: widget.connectedPeerIds,
    );
    if (result != null) {
      widget.onDeviceSelected?.call(result.$1, result.$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.cell.isEmpty ? _handleAddDevice : widget.onTap,
        onDoubleTap: widget.cell.isEmpty ? null : widget.onDoubleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hovering
                ? StudioTheme.cellBg.withOpacity(0.85)
                : StudioTheme.cellBg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.isSelected
                  ? StudioTheme.cellSelected
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: widget.cell.isEmpty
              ? _buildEmpty()
              : (widget.isConnecting ? _buildConnecting() : _buildDevice()),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, color: StudioTheme.overlayLight, size: 32),
          const SizedBox(height: 4),
          const Text(
            '添加设备',
            style: TextStyle(color: StudioTheme.overlayLight, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildConnecting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: StudioTheme.accentCyan,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.cell.peerName ?? widget.cell.peerId ?? '',
            style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          const Text(
            '连接中...',
            style: TextStyle(color: StudioTheme.textHint, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildDevice() {
    // Deterministic placeholder color based on peerId
    final hash = widget.cell.peerId.hashCode;
    final hue = (hash % 360).abs().toDouble();
    final placeholderColor = HSLColor.fromAHSL(1, hue, 0.3, 0.15).toColor();

    return Stack(
      children: [
        // Placeholder for remote screen texture
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: placeholderColor,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Icon(
                Icons.desktop_windows_outlined,
                color: StudioTheme.overlaySubtle,
                size: 48,
              ),
            ),
          ),
        ),
        // Device name label (top-left)
        Positioned(
          left: 0,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: StudioTheme.overlayScrim,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(
              widget.cell.peerName ?? widget.cell.peerId ?? '',
              style: const TextStyle(
                color: StudioTheme.overlayText,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // Connection status indicator (top-right)
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.cell.isConnected
                  ? StudioTheme.accentGreen
                  : StudioTheme.textHint,
              boxShadow: widget.cell.isConnected
                  ? [
                      BoxShadow(
                        color: StudioTheme.accentGreen.withOpacity(0.5),
                        blurRadius: 4,
                      )
                    ]
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
