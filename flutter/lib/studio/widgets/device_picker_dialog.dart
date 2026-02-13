import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common.dart';
import '../../models/peer_model.dart';
import '../../models/platform_model.dart';
import '../studio_theme.dart';

/// Shows the device picker dialog and returns (peerId, peerName) or null.
Future<(String, String)?> showDevicePickerDialog(
  BuildContext context, {
  Set<String> connectedPeerIds = const {},
}) async {
  return showDialog<(String, String)>(
    context: context,
    builder: (_) => DevicePickerDialog(connectedPeerIds: connectedPeerIds),
  );
}

class DevicePickerDialog extends StatefulWidget {
  final Set<String> connectedPeerIds;

  const DevicePickerDialog({
    Key? key,
    this.connectedPeerIds = const {},
  }) : super(key: key);

  @override
  State<DevicePickerDialog> createState() => _DevicePickerDialogState();
}

class _DevicePickerDialogState extends State<DevicePickerDialog> {
  final _searchController = TextEditingController();
  final _searchText = ''.obs;
  final _peers = <Peer>[].obs;
  final _loading = true.obs;

  @override
  void initState() {
    super.initState();
    _loadPeers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPeers() async {
    _loading.value = true;
    try {
      final allPeers = <Peer>[];
      final seenIds = <String>{};

      // Collect from recent peers
      _addPeers(allPeers, seenIds, gFFI.recentPeersModel.peers);
      // Collect from favorite peers
      _addPeers(allPeers, seenIds, gFFI.favoritePeersModel.peers);
      // Collect from LAN peers
      _addPeers(allPeers, seenIds, gFFI.lanPeersModel.peers);

      // Trigger loads to refresh data
      bind.mainLoadRecentPeers();
      bind.mainLoadFavPeers();
      bind.mainLoadLanPeers();

      _peers.value = allPeers;
    } catch (e) {
      debugPrint('DevicePickerDialog._loadPeers error: $e');
    }
    _loading.value = false;
  }

  void _addPeers(List<Peer> dest, Set<String> seenIds, List<Peer> source) {
    for (final p in source) {
      if (p.id.isNotEmpty && seenIds.add(p.id)) {
        dest.add(p);
      }
    }
  }

  List<Peer> get _filteredPeers {
    final query = _searchText.value.toLowerCase().trim();
    var list = _peers.toList();
    if (query.isNotEmpty) {
      list = list.where((p) {
        return p.id.toLowerCase().contains(query) ||
            (p.alias.isNotEmpty && p.alias.toLowerCase().contains(query)) ||
            p.hostname.toLowerCase().contains(query);
      }).toList();
    }
    // Online first
    list.sort((a, b) {
      if (a.online != b.online) return a.online ? -1 : 1;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: StudioTheme.surfaceBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: StudioTheme.border),
      ),
      child: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchField(),
            const Divider(height: 1, color: StudioTheme.divider),
            Expanded(child: _buildList()),
            const Divider(height: 1, color: StudioTheme.divider),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.devices, color: StudioTheme.accentCyan, size: 20),
          const SizedBox(width: 8),
          const Text(
            '选择设备',
            style: TextStyle(
              color: StudioTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Obx(() => Text(
                '${_peers.length} 台设备',
                style: const TextStyle(
                  color: StudioTheme.textSecondary,
                  fontSize: 12,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _searchController,
          onChanged: (v) => _searchText.value = v,
          style:
              const TextStyle(fontSize: 13, color: StudioTheme.textPrimary),
          decoration: InputDecoration(
            hintText: '搜索 ID 或名称...',
            hintStyle:
                const TextStyle(fontSize: 13, color: StudioTheme.textHint),
            prefixIcon: const Icon(Icons.search,
                size: 18, color: StudioTheme.textSecondary),
            contentPadding: EdgeInsets.zero,
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

  Widget _buildList() {
    return Obx(() {
      if (_loading.value) {
        return const Center(
          child: CircularProgressIndicator(color: StudioTheme.accentCyan),
        );
      }
      // Trigger reactivity on searchText
      _searchText.value;
      final peers = _filteredPeers;
      if (peers.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.devices_other,
                  size: 48, color: StudioTheme.textHint),
              const SizedBox(height: 8),
              Text(
                _searchText.value.isEmpty ? '暂无设备' : '未找到匹配设备',
                style: const TextStyle(
                    color: StudioTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: peers.length,
        itemBuilder: (_, i) => _buildPeerItem(peers[i]),
      );
    });
  }

  Widget _buildPeerItem(Peer peer) {
    final isConnected = widget.connectedPeerIds.contains(peer.id);
    final displayName =
        peer.alias.isNotEmpty ? peer.alias : peer.hostname;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isConnected
            ? null
            : () => Navigator.of(context)
                .pop((peer.id, displayName.isNotEmpty ? displayName : peer.id)),
        hoverColor: StudioTheme.cellHover,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Online indicator
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: peer.online
                      ? StudioTheme.accentGreen
                      : StudioTheme.textHint,
                  boxShadow: peer.online
                      ? [
                          BoxShadow(
                            color: StudioTheme.accentGreen.withOpacity(0.4),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
              ),
              // Platform icon
              SizedBox(
                width: 24,
                height: 24,
                child: getPlatformImage(peer.platform, size: 22),
              ),
              const SizedBox(width: 10),
              // Name + ID
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName.isNotEmpty ? displayName : peer.id,
                      style: TextStyle(
                        color: isConnected
                            ? StudioTheme.textHint
                            : StudioTheme.textPrimary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (displayName.isNotEmpty)
                      Text(
                        formatID(peer.id),
                        style: TextStyle(
                          color: isConnected
                              ? StudioTheme.textHint
                              : StudioTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // Connected badge
              if (isConnected)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: StudioTheme.accentBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: StudioTheme.accentBlue.withOpacity(0.3)),
                  ),
                  child: const Text(
                    '已连接',
                    style: TextStyle(
                      color: StudioTheme.accentBlue,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: _loadPeers,
            icon: const Icon(Icons.refresh,
                size: 16, color: StudioTheme.textSecondary),
            label: const Text('刷新',
                style:
                    TextStyle(color: StudioTheme.textSecondary, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: StudioTheme.textSecondary,
            ),
            child: const Text('取消', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
