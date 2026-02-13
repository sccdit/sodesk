import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/peer_model.dart';
import '../../models/platform_model.dart';
import '../models/device_group.dart';
import '../studio_theme.dart';

class StudioDeviceTreeController extends GetxController {
  final selectedGroupId = 'all'.obs;
  final expandedGroups = <String>{}.obs;
  final searchText = ''.obs;
  final multiSelectMode = false.obs;
  final selectedPeerIds = <String>{}.obs;
  final groups = <DeviceGroup>[].obs;

  @override
  void onInit() {
    super.onInit();
    refreshPeers();
  }

  /// Call this to refresh the device tree from real peer data.
  void refreshPeers() {
    final allPeers = <Peer>[];
    final seenIds = <String>{};

    void addUnique(List<Peer> source) {
      for (final p in source) {
        if (p.id.isNotEmpty && seenIds.add(p.id)) {
          allPeers.add(p);
        }
      }
    }

    addUnique(gFFI.recentPeersModel.peers);
    addUnique(gFFI.favoritePeersModel.peers);
    addUnique(gFFI.lanPeersModel.peers);

    // Trigger loads so data stays fresh
    bind.mainLoadRecentPeers();
    bind.mainLoadFavPeers();
    bind.mainLoadLanPeers();

    final onlineCount = allPeers.where((p) => p.online).length;
    final totalCount = allPeers.length;

    // Build recent peers group
    final recentPeers = gFFI.recentPeersModel.peers;
    final recentOnline = recentPeers.where((p) => p.online).length;

    // Build favorite peers group
    final favPeers = gFFI.favoritePeersModel.peers;
    final favOnline = favPeers.where((p) => p.online).length;

    // Build LAN peers group
    final lanPeers = gFFI.lanPeersModel.peers;
    final lanOnline = lanPeers.where((p) => p.online).length;

    groups.value = [
      DeviceGroup(
        id: 'all',
        name: '全部设备',
        icon: Icons.devices,
        onlineCount: onlineCount,
        totalCount: totalCount,
        peerIds: allPeers.map((p) => p.id).toList(),
      ),
      DeviceGroup(
        id: 'online',
        name: '在线设备',
        icon: Icons.wifi,
        color: StudioTheme.accentGreen,
        onlineCount: onlineCount,
        totalCount: onlineCount,
        peerIds: allPeers.where((p) => p.online).map((p) => p.id).toList(),
      ),
      DeviceGroup(
        id: 'recent',
        name: '最近连接',
        icon: Icons.history,
        color: StudioTheme.accentBlue,
        onlineCount: recentOnline,
        totalCount: recentPeers.length,
        peerIds: recentPeers.map((p) => p.id).toList(),
      ),
      DeviceGroup(
        id: 'favorites',
        name: '收藏设备',
        icon: Icons.star,
        color: StudioTheme.accentOrange,
        onlineCount: favOnline,
        totalCount: favPeers.length,
        peerIds: favPeers.map((p) => p.id).toList(),
      ),
      DeviceGroup(
        id: 'lan',
        name: '局域网发现',
        icon: Icons.lan,
        color: StudioTheme.accentCyan,
        onlineCount: lanOnline,
        totalCount: lanPeers.length,
        peerIds: lanPeers.map((p) => p.id).toList(),
      ),
    ];
  }
}

class StudioDeviceTree extends StatefulWidget {
  final ValueChanged<String>? onGroupSelected;

  const StudioDeviceTree({Key? key, this.onGroupSelected}) : super(key: key);

  @override
  State<StudioDeviceTree> createState() => _StudioDeviceTreeState();
}

class _StudioDeviceTreeState extends State<StudioDeviceTree> {
  late final StudioDeviceTreeController _ctrl;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(StudioDeviceTreeController());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StudioTheme.surfaceBg,
      child: Column(
        children: [
          _buildSearchField(),
          _buildMultiSelectToggle(),
          Expanded(
            child: Obx(() {
              final query = _ctrl.searchText.value.toLowerCase();
              final nodes = <Widget>[];
              for (final group in _ctrl.groups) {
                _buildNodes(group, 0, query, nodes);
              }
              if (nodes.isEmpty) {
                return const Center(
                  child: Text(
                    '暂无设备',
                    style: TextStyle(
                        color: StudioTheme.textSecondary, fontSize: 13),
                  ),
                );
              }
              return ListView(
                padding: EdgeInsets.zero,
                children: nodes,
              );
            }),
          ),
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: double.infinity,
        height: 30,
        child: TextButton.icon(
          onPressed: _ctrl.refreshPeers,
          icon: const Icon(Icons.refresh,
              size: 14, color: StudioTheme.textSecondary),
          label: const Text('刷新设备列表',
              style:
                  TextStyle(color: StudioTheme.textSecondary, fontSize: 11)),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: const BorderSide(color: StudioTheme.border),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _searchController,
          onChanged: (v) => _ctrl.searchText.value = v,
          style: const TextStyle(fontSize: 13, color: StudioTheme.textPrimary),
          decoration: InputDecoration(
            hintText: '搜索设备...',
            hintStyle: const TextStyle(
              fontSize: 13,
              color: StudioTheme.textHint,
            ),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: StudioTheme.textSecondary,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: StudioTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: StudioTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: StudioTheme.accentCyan),
            ),
            filled: true,
            fillColor: StudioTheme.primaryBg,
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectToggle() {
    return Obx(() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  _ctrl.multiSelectMode.value = !_ctrl.multiSelectMode.value;
                  if (!_ctrl.multiSelectMode.value) _ctrl.selectedPeerIds.clear();
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Row(
                    children: [
                      Icon(
                        _ctrl.multiSelectMode.value
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: _ctrl.multiSelectMode.value
                            ? StudioTheme.accentCyan
                            : StudioTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '多选',
                        style: TextStyle(
                          fontSize: 11,
                          color: _ctrl.multiSelectMode.value
                              ? StudioTheme.accentCyan
                              : StudioTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (_ctrl.multiSelectMode.value && _ctrl.selectedPeerIds.isNotEmpty)
                Text(
                  '已选 ${_ctrl.selectedPeerIds.length} 项',
                  style: const TextStyle(
                    fontSize: 11,
                    color: StudioTheme.accentCyan,
                  ),
                ),
            ],
          ),
        ));
  }

  void _buildNodes(
      DeviceGroup group, int depth, String query, List<Widget> nodes) {
    final matchesSearch =
        query.isEmpty || group.name.toLowerCase().contains(query);
    if (!matchesSearch && group.children.isEmpty) return;

    if (matchesSearch) {
      nodes.add(_TreeNodeRow(
        group: group,
        depth: depth,
        selectedGroupId: _ctrl.selectedGroupId,
        expandedGroups: _ctrl.expandedGroups,
        multiSelectMode: _ctrl.multiSelectMode,
        selectedPeerIds: _ctrl.selectedPeerIds,
        onTap: () {
          _ctrl.selectedGroupId.value = group.id;
          widget.onGroupSelected?.call(group.id);
        },
        onToggleExpand: group.children.isNotEmpty
            ? () {
                if (_ctrl.expandedGroups.contains(group.id)) {
                  _ctrl.expandedGroups.remove(group.id);
                } else {
                  _ctrl.expandedGroups.add(group.id);
                }
              }
            : null,
      ));
    }

    if (group.children.isNotEmpty &&
        (_ctrl.expandedGroups.contains(group.id) || query.isNotEmpty)) {
      for (final child in group.children) {
        _buildNodes(child, depth + 1, query, nodes);
      }
    }
  }
}

class _TreeNodeRow extends StatefulWidget {
  final DeviceGroup group;
  final int depth;
  final RxString selectedGroupId;
  final RxSet<String> expandedGroups;
  final RxBool multiSelectMode;
  final RxSet<String> selectedPeerIds;
  final VoidCallback onTap;
  final VoidCallback? onToggleExpand;

  const _TreeNodeRow({
    required this.group,
    required this.depth,
    required this.selectedGroupId,
    required this.expandedGroups,
    required this.multiSelectMode,
    required this.selectedPeerIds,
    required this.onTap,
    this.onToggleExpand,
  });

  @override
  State<_TreeNodeRow> createState() => _TreeNodeRowState();
}

class _TreeNodeRowState extends State<_TreeNodeRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = widget.selectedGroupId.value == widget.group.id;
      final isExpanded = widget.expandedGroups.contains(widget.group.id);
      final hasChildren = widget.group.children.isNotEmpty;
      final isMultiSelect = widget.multiSelectMode.value;
      final isChecked = widget.selectedPeerIds.contains(widget.group.id);

      Color? bgColor;
      if (isSelected) {
        bgColor = StudioTheme.accentBlue.withOpacity(0.15);
      } else if (_hovering) {
        bgColor = StudioTheme.cellHover;
      }

      return MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 36,
            color: bgColor,
            padding: EdgeInsets.only(left: 12.0 + widget.depth * 16.0),
            child: Row(
              children: [
                // Checkbox for multi-select
                if (isMultiSelect)
                  GestureDetector(
                    onTap: () {
                      if (isChecked) {
                        widget.selectedPeerIds.remove(widget.group.id);
                      } else {
                        widget.selectedPeerIds.add(widget.group.id);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        isChecked
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 16,
                        color: isChecked
                            ? StudioTheme.accentCyan
                            : StudioTheme.textSecondary,
                      ),
                    ),
                  ),
                // Online status indicator (8px dot)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.group.onlineCount > 0
                        ? StudioTheme.accentGreen
                        : StudioTheme.textHint,
                  ),
                ),
                // Expand/collapse arrow
                if (hasChildren)
                  GestureDetector(
                    onTap: widget.onToggleExpand,
                    child: Icon(
                      isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 16,
                      color: StudioTheme.textSecondary,
                    ),
                  )
                else
                  const SizedBox(width: 16),
                // Icon
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    widget.group.icon ?? Icons.folder,
                    size: 18,
                    color: isSelected
                        ? StudioTheme.accentCyan
                        : (widget.group.color ?? StudioTheme.textSecondary),
                  ),
                ),
                // Name
                Expanded(
                  child: Text(
                    widget.group.name,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? StudioTheme.accentCyan
                          : StudioTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Count badge
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: StudioTheme.primaryBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.group.onlineCount}/${widget.group.totalCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: StudioTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
