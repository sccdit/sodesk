import '../../common.dart';
import '../../models/peer_model.dart';
import '../../models/platform_model.dart';
import 'device_group.dart';
import '../studio_theme.dart';
import 'package:flutter/material.dart';

/// Shared service for aggregating device/peer data from multiple sources.
///
/// Used by [StudioDeviceTreeController] and [DevicePickerDialog] to avoid
/// duplicating the peer collection and deduplication logic.
class StudioPeerService {
  StudioPeerService._();

  /// Load and deduplicate peers from recent, favorite, and LAN sources.
  /// Optionally triggers a refresh of the underlying data.
  static List<Peer> loadPeers({bool triggerRefresh = true}) {
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

    if (triggerRefresh) {
      bind.mainLoadRecentPeers();
      bind.mainLoadFavPeers();
      bind.mainLoadLanPeers();
    }

    return allPeers;
  }

  /// Build the standard device group tree from current peer data.
  static List<DeviceGroup> buildDeviceGroups() {
    final allPeers = loadPeers();

    final onlineCount = allPeers.where((p) => p.online).length;
    final totalCount = allPeers.length;

    final recentPeers = gFFI.recentPeersModel.peers;
    final recentOnline = recentPeers.where((p) => p.online).length;

    final favPeers = gFFI.favoritePeersModel.peers;
    final favOnline = favPeers.where((p) => p.online).length;

    final lanPeers = gFFI.lanPeersModel.peers;
    final lanOnline = lanPeers.where((p) => p.online).length;

    return [
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
