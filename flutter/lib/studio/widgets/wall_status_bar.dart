import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/screen_wall_model.dart';
import '../studio_theme.dart';

/// Bottom status bar for the screen wall page.
class WallStatusBar extends StatelessWidget {
  final ScreenWallController controller;

  const WallStatusBar({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: StudioTheme.statusBarHeight,
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
