import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/screen_wall_model.dart';
import '../studio_theme.dart';

/// Toolbar for the screen wall page — layout switcher + action buttons.
class WallToolbar extends StatelessWidget {
  final ScreenWallController controller;
  final VoidCallback onSelectNext;
  final VoidCallback onDisconnectAll;
  final VoidCallback onRefresh;

  const WallToolbar({
    Key? key,
    required this.controller,
    required this.onSelectNext,
    required this.onDisconnectAll,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: StudioTheme.toolbarHeight,
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
            _actionBtn(Icons.select_all, '选择下一个', onSelectNext),
            const SizedBox(width: 4),
            _actionBtn(Icons.link_off, '断开所有', onDisconnectAll),
            const SizedBox(width: 4),
            _actionBtn(Icons.refresh, '刷新', onRefresh),
          ],
        );
      }),
    );
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
}
