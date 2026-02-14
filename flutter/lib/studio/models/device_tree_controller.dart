import 'package:get/get.dart';

import 'device_group.dart';
import 'studio_peer_service.dart';

/// Controller for the studio device tree.
///
/// Manages group selection, expansion state, search, and multi-select.
/// Peer data is loaded via [StudioPeerService].
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

  /// Refresh the device tree from real peer data.
  void refreshPeers() {
    groups.value = StudioPeerService.buildDeviceGroups();
  }

  /// Check whether a group or its peer IDs match the search query.
  ///
  /// Matches against group name, individual peer IDs, and peer names
  /// (via the peerIds list stored on each group).
  bool groupMatchesSearch(DeviceGroup group, String query) {
    if (query.isEmpty) return true;
    // Match group name
    if (group.name.toLowerCase().contains(query)) return true;
    // Match any peer ID in this group
    if (group.peerIds.any((id) => id.toLowerCase().contains(query))) {
      return true;
    }
    return false;
  }
}
