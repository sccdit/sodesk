import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/screen_wall_model.dart';
import '../models/screen_wall_session.dart';
import '../studio_theme.dart';
import '../widgets/device_picker_dialog.dart';
import '../widgets/wall_cell_widget.dart';
import '../widgets/wall_remote_view.dart';
import '../widgets/wall_fullscreen_view.dart';
import '../widgets/wall_toolbar.dart';
import '../widgets/wall_status_bar.dart';

class ScreenWallPage extends StatefulWidget {
  const ScreenWallPage({Key? key}) : super(key: key);

  @override
  State<ScreenWallPage> createState() => _ScreenWallPageState();
}

class _ScreenWallPageState extends State<ScreenWallPage> {
  final ScreenWallController controller = Get.put(ScreenWallController());
  final _fullscreenIndex = (-1).obs;
  final FocusNode _focusNode = FocusNode(debugLabel: 'screenWallPage');

  /// Set of peer IDs currently connected in the wall (cached in controller).
  Set<String> get _connectedPeerIds => controller.connectedPeerIds;

  Future<void> _onDeviceSelected(int index, String peerId, String peerName) async {
    await controller.connectCell(index, peerId, name: peerName);
  }

  Future<void> _onCellDisconnect(int index) async {
    await controller.disconnectCell(index);
  }

  void _enterFullscreen(int index) {
    final session = controller.sessionManager.getSession(index);
    if (session == null || session.state.value != WallSessionState.connected) {
      return;
    }
    _fullscreenIndex.value = index;
  }

  void _exitFullscreen() {
    _fullscreenIndex.value = -1;
    _focusNode.requestFocus();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    // Ctrl+1/2/3/4 — switch layout
    if (ctrl) {
      if (key == LogicalKeyboardKey.digit1) {
        controller.setLayout(WallLayout.grid2x2);
      } else if (key == LogicalKeyboardKey.digit2) {
        controller.setLayout(WallLayout.grid3x3);
      } else if (key == LogicalKeyboardKey.digit3) {
        controller.setLayout(WallLayout.grid4x4);
      } else if (key == LogicalKeyboardKey.digit4) {
        controller.setLayout(WallLayout.adaptive);
      }
    }

    // Delete — disconnect selected cell
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      final sel = controller.selectedIndex.value;
      if (sel >= 0 && sel < controller.cells.length && !controller.cells[sel].isEmpty) {
        _onCellDisconnect(sel);
      }
    }

    // F11 — fullscreen selected cell
    if (key == LogicalKeyboardKey.f11) {
      final sel = controller.selectedIndex.value;
      if (sel >= 0) _enterFullscreen(sel);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    // Await async session cleanup before deleting the controller.
    controller.sessionManager.disconnectAll().whenComplete(() {
      Get.delete<ScreenWallController>();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Obx(() {
        // Fullscreen mode
        if (_fullscreenIndex.value >= 0) {
          final idx = _fullscreenIndex.value;
          final session = controller.sessionManager.getSession(idx);
          if (session != null &&
              session.state.value == WallSessionState.connected) {
            return WallFullscreenView(
              session: session,
              onExit: _exitFullscreen,
            );
          }
        }
        // Normal mode
        return Container(
          color: StudioTheme.primaryBg,
          child: Column(
            children: [
              WallToolbar(
                controller: controller,
                onSelectNext: _selectNextConnected,
                onDisconnectAll: () async {
                  await controller.clearAll();
                },
                onRefresh: _refreshAll,
              ),
              Expanded(child: _buildGrid()),
              WallStatusBar(controller: controller),
            ],
          ),
        );
      }),
    );
  }

  void _selectNextConnected() {
    final current = controller.selectedIndex.value;
    final len = controller.cells.length;
    for (var offset = 1; offset <= len; offset++) {
      final i = (current + offset) % len;
      if (!controller.cells[i].isEmpty) {
        controller.selectCell(i);
        return;
      }
    }
  }

  void _refreshAll() {
    for (final entry in controller.sessionManager.sessions.entries) {
      entry.value.reconnect();
    }
  }

  Widget _buildGrid() {
    return Obx(() {
      // Outer Obx only reacts to layout changes (grid columns / total slots).
      final cols = controller.gridColumns;
      final total = controller.totalSlots;
      return Padding(
        padding: const EdgeInsets.all(StudioTheme.gridSpacing),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: StudioTheme.gridSpacing,
            mainAxisSpacing: StudioTheme.gridSpacing,
            childAspectRatio: 16 / 9,
          ),
          itemCount: total,
          itemBuilder: (context, index) {
            // Each cell has its own Obx — only rebuilds when this cell or
            // selectedIndex changes.
            return Obx(() {
              final cell = index < controller.cells.length
                  ? controller.cells[index]
                  : const ScreenWallCell();
              final session = controller.sessionManager.getSession(index);
              final isConnecting =
                  session?.state.value == WallSessionState.connecting;
              final isConnected =
                  session?.state.value == WallSessionState.connected;

              return DragTarget<String>(
                onAcceptWithDetails: (details) {
                  _onDeviceSelected(index, details.data, details.data);
                },
                builder: (context, candidateData, rejectedData) {
                  final isDragOver = candidateData.isNotEmpty;
                  return GestureDetector(
                    onSecondaryTapUp: (details) {
                      _showCellContextMenu(
                          context, index, cell, details.globalPosition);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: isDragOver
                          ? BoxDecoration(
                              border: Border.all(
                                  color: StudioTheme.accentCyan, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            )
                          : null,
                      child: _buildCellContent(
                          index, cell, isConnecting, isConnected),
                    ),
                  );
                },
              );
            });
          },
        ),
      );
    });
  }

  Widget _buildCellContent(
      int index, ScreenWallCell cell, bool isConnecting, bool isConnected) {
    // Show remote view for connected sessions
    if (isConnected && cell.peerId != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: WallRemoteView(
              session: controller.sessionManager.getSession(index)!,
              onDoubleClick: () => _enterFullscreen(index),
            ),
          ),
          // Selection border
          if (controller.selectedIndex.value == index)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: StudioTheme.cellSelected, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      );
    }

    // Show cell widget for empty/connecting states
    return WallCellWidget(
      cell: cell,
      index: index,
      isSelected: controller.selectedIndex.value == index,
      isConnecting: isConnecting,
      onTap: () => controller.selectCell(index),
      onDoubleTap: cell.isEmpty ? null : () => _enterFullscreen(index),
      connectedPeerIds: _connectedPeerIds,
      onDeviceSelected: (peerId, peerName) {
        _onDeviceSelected(index, peerId, peerName);
      },
    );
  }

  void _showCellContextMenu(
      BuildContext context, int index, ScreenWallCell cell, Offset position) {
    final items = <PopupMenuEntry<String>>[];

    if (!cell.isEmpty) {
      items.addAll([
        const PopupMenuItem(value: 'fullscreen', child: Text('全屏查看')),
        const PopupMenuItem(value: 'reconnect', child: Text('重新连接')),
        const PopupMenuItem(value: 'disconnect', child: Text('断开连接')),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: Text(
            'ID: ${cell.peerId}',
            style: const TextStyle(fontSize: 12, color: StudioTheme.textHint),
          ),
        ),
      ]);
    } else {
      items.addAll([
        const PopupMenuItem(value: 'add', child: Text('添加设备')),
        const PopupMenuItem(value: 'paste', child: Text('粘贴 ID 连接')),
      ]);
    }

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: items,
      color: StudioTheme.surfaceBg,
    ).then((value) async {
      if (value == null) return;
      switch (value) {
        case 'fullscreen':
          _enterFullscreen(index);
          break;
        case 'reconnect':
          final session = controller.sessionManager.getSession(index);
          session?.reconnect();
          break;
        case 'disconnect':
          _onCellDisconnect(index);
          break;
        case 'add':
          final result = await showDevicePickerDialog(
            context,
            connectedPeerIds: _connectedPeerIds,
          );
          if (result != null) {
            _onDeviceSelected(index, result.$1, result.$2);
          }
          break;
        case 'paste':
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final id = data?.text?.trim();
          if (id != null && id.isNotEmpty) {
            _onDeviceSelected(index, id, id);
          }
          break;
      }
    });
  }
}
