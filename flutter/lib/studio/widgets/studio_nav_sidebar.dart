import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../studio_theme.dart';

class StudioNavSidebar extends StatelessWidget {
  final ValueChanged<int> onNavChanged;
  final RxInt selectedIndex;
  final RxInt onlineDeviceCount;

  // Navigation index constants
  static const int navDevices = 0;
  static const int navScreenWall = 1;
  static const int navFileTransfer = 2;
  static const int navTerminal = 3;
  static const int navSettings = 10;
  static const int navAccount = 11;
  static const int navQuickAction = 99;

  StudioNavSidebar({
    Key? key,
    required this.onNavChanged,
    RxInt? selectedIndex,
    RxInt? onlineDeviceCount,
  })  : selectedIndex = selectedIndex ?? 0.obs,
        onlineDeviceCount = onlineDeviceCount ?? 0.obs,
        super(key: key);

  static const _topItems = <_NavItem>[
    _NavItem(index: navDevices, icon: Icons.devices, tooltip: 'Devices'),
    _NavItem(index: navScreenWall, icon: Icons.grid_4x4, tooltip: 'Screen Wall'),
    _NavItem(index: navFileTransfer, icon: Icons.folder_open, tooltip: 'File Transfer'),
    _NavItem(index: navTerminal, icon: Icons.terminal, tooltip: 'Terminal'),
  ];

  static const _bottomItems = <_NavItem>[
    _NavItem(index: navSettings, icon: Icons.settings, tooltip: 'Settings'),
    _NavItem(index: navAccount, icon: Icons.account_circle, tooltip: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: StudioTheme.navSidebarWidth,
      color: StudioTheme.navBarBg,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: Text(
                'SD',
                style: TextStyle(
                  color: StudioTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final item in _topItems)
            _buildNavButton(item),
          const Spacer(),
          _buildQuickActionButton(),
          const SizedBox(height: 4),
          for (final item in _bottomItems)
            _buildNavButton(item),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavButton(_NavItem item) {
    return Obx(() {
      final selected = selectedIndex.value == item.index;
      return Tooltip(
        message: item.tooltip,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          onTap: () {
            selectedIndex.value = item.index;
            onNavChanged(item.index);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: item.index == 0
                ? _DevicesNavButton(
                    icon: item.icon,
                    selected: selected,
                    onlineCount: onlineDeviceCount,
                  )
                : _NavButton(
                    icon: item.icon,
                    selected: selected,
                  ),
          ),
        ),
      );
    });
  }

  Widget _buildQuickActionButton() {
    return Tooltip(
      message: 'Quick Actions',
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onTap: () => onNavChanged(navQuickAction),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: const _NavButton(
            icon: Icons.power_settings_new,
            selected: false,
          ),
        ),
      ),
    );
  }
}

/// Shared nav button with hover state management.
class _NavButton extends StatefulWidget {
  final IconData icon;
  final bool selected;

  const _NavButton({required this.icon, required this.selected});

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color iconColor;
    if (widget.selected) {
      bg = StudioTheme.accentBlue;
      iconColor = StudioTheme.textPrimary;
    } else if (_hovering) {
      bg = StudioTheme.hoverOverlay;
      iconColor = StudioTheme.textSecondary;
    } else {
      bg = Colors.transparent;
      iconColor = StudioTheme.textSecondary;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(widget.icon, color: iconColor, size: 24),
      ),
    );
  }
}

/// Devices nav button — wraps [_NavButton] with an online count badge.
class _DevicesNavButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final RxInt onlineCount;

  const _DevicesNavButton({
    required this.icon,
    required this.selected,
    required this.onlineCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _NavButton(icon: icon, selected: selected),
        Positioned(
          right: 2,
          top: 0,
          child: Obx(() {
            final count = onlineCount.value;
            if (count <= 0) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: StudioTheme.accentGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: StudioTheme.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _NavItem {
  final int index;
  final IconData icon;
  final String tooltip;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.tooltip,
  });
}
