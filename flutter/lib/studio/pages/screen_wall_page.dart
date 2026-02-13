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

class ScreenWallPage extends StatefulWidget {
  const ScreenWallPage({Key? key}) : super(key: key);

  @override
  State<ScreenWallPage> createState() => _ScreenWallPageState();
}

class _ScreenWallPageState extends State<ScreenWallPage> {
  final ScreenWallController controller = Get.put(ScreenWallController());
  final _fullscreenIndex = (-1).obs;
  final _remoteViewKeys = <int, GlobalKey<WallRemoteViewState>>{};
  final FocusNode _focusNode = FocusNode(debugLabel: 'screenWallPage');

  GlobalKey<WallRemoteViewState> _getRemoteKey(int index) {
    return _remoteViewKeys.putIfAbsent(
        index, () => GlobalKey<WallRemoteViewState>());
  }

  /// Set of peer IDs currently connected in the wall.
  Set<String> get _connectedPeerIds {
    return controller.cells
        .where((c) => !c.isEmpty)
        .map((c) => c.peerId!)
        .toSet();
  }

  Future<void> _onDeviceSelected(int index, String peerId, String peerName) async {
    await controller.connectCell(index, peerId, name: peerName);
  }

  Future<void> _onCellDisconnect(int index) async {
    _remoteViewKeys.remove(index);
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
    Get.delete<ScreenWallController>();
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
          final key = _getRemoteKey(idx);
          final cell = controller.cells[idx];
          if (key.currentState != null) {
            return WallFullscreenView(
              remoteViewState: key.currentState!,
              peerId: cell.peerId ?? '',
              peerName: cell.peerName ?? '',
              onExit: _exitFullscreen,
            );
          }
        }
        // Normal mode
        return Container(
          color: StudioTheme.primaryBg,
          child: Column(
            children: [
              _buildToolbar(),
              Expanded(child: _buildGrid()),
              _buildStatusBar(),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: StudioTheme.toolbarBg,
        border: Border(bottom: BorderSide(color: StudioTheme.border, width: 1)),
      ),
      child: Obx(() {
        final current = controller.layout.value;
        final connected = controller.sessionManager.connectedCount;
        final total = controller.totalSlots;
        return Row(
          children: [
            _layoutBtn('2×2', WallLayout.grid2x2, current),
            const SizedBox(width: 2),
            _layoutBtn('3×3', WallLayout.grid3x3, current),
            const SizedBox(width: 2),
            _layoutBtn('4×4', WallLayout.grid4x4, current),
            const SizedBox(width: 2),
            _layoutBtn('自适应', WallLayout.adaptive, current),
            const Spacer(),
            Text(
              '已连接 $connected/$total',
              style: const TextStyle(color: StudioTheme.textSecondary, fontSize: 13),
            ),
            const Spacer(),
            _actionBtn(Icons.select_all, '选择下一个', _selectNextConnected),
            const SizedBox(width: 4),
            _actionBtn(Icons.link_off, '断开所有', () async {
              _remoteViewKeys.clear();
              await controller.clearAll();
            }),
            const SizedBox(width: 4),
            _actionBtn(Icons.refresh, '刷新', _refreshAll),
          ],
        );
      }),
    );
  }

  void _selectNextConnected() {
    // Select next non-empty, unselected cell (cycle through them)
    for (var i = 0; i < controller.cells.length; i++) {
      if (!controller.cells[i].isEmpty && !controller.cells[i].isSelected) {
        controller.selectCell(i);
        return;
      }
    }
  }

  void _refreshAll() {
    // Reconnect all active sessions
    for (final entry in controller.sessionManager.sessions.entries) {
      entry.value.reconnect();
    }
  }

  Widget _layoutBtn(String label, WallLayout value, WallLayout current) {
    final selected = value == current;
    return InkWell(
      onTap: () => controller.setLayout(value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? StudioTheme.accentCyan.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? StudioTheme.accentCyan : StudioTheme.btnBorderIdle,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? StudioTheme.accentCyan : StudioTheme.btnTextIdle,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: StudioTheme.border),
          ),
          child: Icon(icon, color: StudioTheme.textSecondary, size: 18),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Obx(() {
      final cols = controller.gridColumns;
      final total = controller.totalSlots;
      return Padding(
        padding: const EdgeInsets.all(2),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 16 / 9,
          ),
          itemCount: total,
          itemBuilder: (context, index) {
            final cell = index < controller.cells.length
                ? controller.cells[index]
                : const ScreenWallCell();
            final session = controller.sessionManager.getSession(index);
            final isConnecting = session?.state.value == WallSessionState.connecting;
            final isConnected = session?.state.value == WallSessionState.connected;

            return DragTarget<String>(
              onAcceptWithDetails: (details) {
                // Accept peer ID dropped from device tree
                _onDeviceSelected(index, details.data, details.data);
              },
              builder: (context, candidateData, rejectedData) {
                final isDragOver = candidateData.isNotEmpty;
                return GestureDetector(
                  onSecondaryTapUp: (details) {
                    _showCellContextMenu(context, index, cell, details.globalPosition);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: isDragOver
                        ? BoxDecoration(
                            border: Border.all(color: StudioTheme.accentCyan, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          )
                        : null,
                    child: _buildCellContent(index, cell, isConnecting, isConnected),
                  ),
                );
              },
            );
          },
        ),
      );
    });
  }

  Widget _buildCellContent(
      int index, ScreenWallCell cell, bool isConnecting, bool isConnected) {
    // Show remote view for connected sessions
    if (isConnected && cell.peerId != null) {
      final key = _getRemoteKey(index);
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: WallRemoteView(
              key: key,
              peerId: cell.peerId!,
              peerName: cell.peerName ?? cell.peerId!,
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

  Widget _buildStatusBar() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: StudioTheme.toolbarBg,
        border: Border(top: BorderSide(color: StudioTheme.border, width: 1)),
      ),
      child: Obx(() {
        final sel = controller.selectedIndex.value;
        final selCell = sel >= 0 && sel < controller.cells.length
            ? controller.cells[sel]
            : null;
        final connected = controller.sessionManager.connectedCount;
        return Row(
          children: [
            Text(
              '连接: $connected',
              style: const TextStyle(color: StudioTheme.textHint, fontSize: 11),
            ),
            const SizedBox(width: 8),
            Text(
              '布局: ${controller.gridColumns}×${controller.gridColumns}',
              style: const TextStyle(color: StudioTheme.textHint, fontSize: 11),
            ),
            const SizedBox(width: 16),
            if (selCell != null && !selCell.isEmpty)
              Text(
                '选中: ${selCell.peerName ?? selCell.peerId ?? ""}',
                style: const TextStyle(color: StudioTheme.accentCyan, fontSize: 11),
              ),
            const Spacer(),
            const Text(
              'Ctrl+1~4 切换布局 | Del 断开 | F11 全屏',
              style: TextStyle(color: StudioTheme.textHint, fontSize: 10),
            ),
          ],
        );
      }),
    );
  }
}
