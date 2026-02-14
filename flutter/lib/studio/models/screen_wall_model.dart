import 'package:get/get.dart';

import 'screen_wall_session.dart';

enum WallLayout { grid2x2, grid3x3, grid4x4, adaptive }

class ScreenWallCell {
  final String? peerId;
  final String? peerName;
  final bool isConnected;

  const ScreenWallCell({
    this.peerId,
    this.peerName,
    this.isConnected = false,
  });

  bool get isEmpty => peerId == null;

  ScreenWallCell copyWith({
    String? peerId,
    String? peerName,
    bool? isConnected,
    bool clearPeer = false,
  }) {
    return ScreenWallCell(
      peerId: clearPeer ? null : (peerId ?? this.peerId),
      peerName: clearPeer ? null : (peerName ?? this.peerName),
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class ScreenWallController extends GetxController {
  final cells = <ScreenWallCell>[].obs;
  final layout = WallLayout.grid3x3.obs;
  final selectedIndex = (-1).obs;
  late final ScreenWallSessionManager sessionManager;
  final _cellWorkers = <int, Worker>{};
  final connectedPeerIds = <String>{}.obs;
  Worker? _peerIdWorker;

  int get gridColumns {
    switch (layout.value) {
      case WallLayout.grid2x2:
        return 2;
      case WallLayout.grid3x3:
        return 3;
      case WallLayout.grid4x4:
        return 4;
      case WallLayout.adaptive:
        final count = cells.where((c) => !c.isEmpty).length;
        if (count <= 4) return 2;
        if (count <= 9) return 3;
        return 4;
    }
  }

  int get totalSlots => gridColumns * gridColumns;

  int get connectedCount => cells.where((c) => c.isConnected).length;

  @override
  void onInit() {
    super.onInit();
    sessionManager = Get.put(ScreenWallSessionManager());
    _rebuildGrid();
    _peerIdWorker = ever(cells, (_) => _refreshConnectedPeerIds());
  }

  void _refreshConnectedPeerIds() {
    connectedPeerIds.value = cells
        .where((c) => !c.isEmpty)
        .map((c) => c.peerId!)
        .toSet();
  }

  @override
  void onClose() {
    _peerIdWorker?.dispose();
    for (final w in _cellWorkers.values) {
      w.dispose();
    }
    _cellWorkers.clear();
    sessionManager.disconnectAll();
    Get.delete<ScreenWallSessionManager>();
    super.onClose();
  }

  void _rebuildGrid() {
    final total = totalSlots;
    if (cells.length < total) {
      cells.addAll(List.generate(
        total - cells.length,
        (_) => const ScreenWallCell(),
      ));
    } else if (cells.length > total) {
      // Disconnect sessions on cells being removed
      for (var i = total; i < cells.length; i++) {
        _cellWorkers[i]?.dispose();
        _cellWorkers.remove(i);
        sessionManager.disconnectCell(i);
      }
      cells.removeRange(total, cells.length);
    }
  }

  Future<void> connectCell(int index, String peerId, {String? name}) async {
    if (index < 0 || index >= cells.length) return;
    if (sessionManager.isPeerConnected(peerId)) return;

    cells[index] = ScreenWallCell(
      peerId: peerId,
      peerName: name ?? peerId,
      isConnected: false,
    );
    await sessionManager.connectCell(index, peerId, peerName: name);

    // Update cell state reactively based on session state.
    final session = sessionManager.getSession(index);
    if (session != null) {
      _cellWorkers[index]?.dispose();
      _cellWorkers[index] = ever(session.state, (WallSessionState s) {
        if (index < cells.length && cells[index].peerId == peerId) {
          cells[index] = cells[index].copyWith(
            isConnected: s == WallSessionState.connected,
          );
        }
      });
    }
  }

  Future<void> disconnectCell(int index) async {
    if (index < 0 || index >= cells.length) return;
    _cellWorkers[index]?.dispose();
    _cellWorkers.remove(index);
    await sessionManager.disconnectCell(index);
    cells[index] = const ScreenWallCell();
    if (selectedIndex.value == index) {
      selectedIndex.value = -1;
    }
  }

  void selectCell(int index) {
    if (index < 0 || index >= cells.length) return;
    if (selectedIndex.value == index) {
      selectedIndex.value = -1;
      return;
    }
    selectedIndex.value = index;
  }

  void setLayout(WallLayout newLayout) {
    layout.value = newLayout;
    _rebuildGrid();
  }

  Future<void> clearAll() async {
    selectedIndex.value = -1;
    for (final w in _cellWorkers.values) {
      w.dispose();
    }
    _cellWorkers.clear();
    await sessionManager.disconnectAll();
    for (var i = 0; i < cells.length; i++) {
      cells[i] = const ScreenWallCell();
    }
  }

  Future<void> disconnectAll() async {
    selectedIndex.value = -1;
    for (final w in _cellWorkers.values) {
      w.dispose();
    }
    _cellWorkers.clear();
    await sessionManager.disconnectAll();
    for (var i = 0; i < cells.length; i++) {
      if (!cells[i].isEmpty) {
        cells[i] = cells[i].copyWith(isConnected: false);
      }
    }
  }
}
