import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../common.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';

/// Connection state for a single screen wall cell.
enum WallSessionState { disconnected, connecting, connected, error }

/// Wraps a single remote desktop session for one screen wall cell.
class ScreenWallSession {
  static const _uuid = Uuid();

  final int cellIndex;
  final String peerId;
  String peerName;
  final Rx<WallSessionState> state;
  FFI? ffi;
  SessionID? sessionId;
  String? errorMessage;
  Timer? _connectTimer;

  ScreenWallSession({
    required this.cellIndex,
    required this.peerId,
    String? peerName,
  })  : peerName = peerName ?? peerId,
        state = WallSessionState.disconnected.obs;

  /// Connect to the remote peer.
  Future<void> connect() async {
    if (state.value == WallSessionState.connecting ||
        state.value == WallSessionState.connected) {
      return;
    }
    state.value = WallSessionState.connecting;
    errorMessage = null;

    try {
      final sid = _uuid.v4obj();
      sessionId = sid;
      final ffiInstance = FFI(sid);
      ffi = ffiInstance;

      // Start the connection — FFI.start handles bind.sessionAddSync + bind.sessionStart internally.
      ffiInstance.start(peerId);

      // Set view-only mode so no keyboard/mouse input is forwarded.
      bind.sessionToggleOption(sessionId: sid, value: 'view-only');

      // Listen for the first image to confirm connection success.
      ffiInstance.imageModel.addCallbackOnFirstImage((String id) {
        if (state.value == WallSessionState.connecting) {
          state.value = WallSessionState.connected;
          debugPrint('[ScreenWall] Cell $cellIndex connected to $peerId');
        }
      });

      // Set a cancellable timeout — if no image arrives within 30s, mark as error.
      _connectTimer?.cancel();
      _connectTimer = Timer(const Duration(seconds: 30), () {
        if (state.value == WallSessionState.connecting) {
          state.value = WallSessionState.error;
          errorMessage = 'Connection timeout';
          debugPrint('[ScreenWall] Cell $cellIndex timeout for $peerId');
        }
      });
    } catch (e) {
      state.value = WallSessionState.error;
      errorMessage = e.toString();
      debugPrint('[ScreenWall] Cell $cellIndex connect error: $e');
    }
  }

  /// Disconnect and release resources.
  Future<void> disconnect() async {
    _connectTimer?.cancel();
    _connectTimer = null;
    final f = ffi;
    if (f != null) {
      debugPrint('[ScreenWall] Cell $cellIndex disconnecting from $peerId');
      f.imageModel.disposeImage();
      f.cursorModel.disposeImages();
      await f.close(closeSession: true);
      ffi = null;
    }
    sessionId = null;
    state.value = WallSessionState.disconnected;
    errorMessage = null;
  }

  /// Reconnect by disconnecting first, then connecting again.
  Future<void> reconnect() async {
    await disconnect();
    await connect();
  }
}

/// Manages multiple concurrent screen wall sessions.
class ScreenWallSessionManager extends GetxController {
  final sessions = <int, ScreenWallSession>{}.obs;
  final int maxConcurrent;

  ScreenWallSessionManager({this.maxConcurrent = 16});

  /// Connect a cell to a remote peer.
  Future<void> connectCell(int cellIndex, String peerId,
      {String? peerName}) async {
    // Check concurrent limit.
    if (connectedCount >= maxConcurrent) {
      debugPrint(
          '[ScreenWall] Max concurrent sessions ($maxConcurrent) reached');
      return;
    }

    // Check if this peer is already connected in another cell.
    if (isPeerConnected(peerId)) {
      debugPrint('[ScreenWall] Peer $peerId is already connected');
      return;
    }

    // Disconnect existing session on this cell if any.
    await _disconnectCellInternal(cellIndex);

    final session = ScreenWallSession(
      cellIndex: cellIndex,
      peerId: peerId,
      peerName: peerName,
    );
    sessions[cellIndex] = session;
    await session.connect();
  }

  /// Disconnect a specific cell.
  Future<void> disconnectCell(int cellIndex) async {
    await _disconnectCellInternal(cellIndex);
  }

  Future<void> _disconnectCellInternal(int cellIndex) async {
    final session = sessions[cellIndex];
    if (session != null) {
      await session.disconnect();
      sessions.remove(cellIndex);
    }
  }

  /// Disconnect all cells.
  Future<void> disconnectAll() async {
    final indices = sessions.keys.toList();
    await Future.wait(indices.map((i) => _disconnectCellInternal(i)));
  }

  /// Get the session for a specific cell.
  ScreenWallSession? getSession(int cellIndex) => sessions[cellIndex];

  /// Number of currently connected (or connecting) sessions.
  int get connectedCount => sessions.values
      .where((s) =>
          s.state.value == WallSessionState.connected ||
          s.state.value == WallSessionState.connecting)
      .length;

  /// Check if a peer ID is already in use by any active session.
  bool isPeerConnected(String peerId) {
    return sessions.values.any((s) =>
        s.peerId == peerId &&
        (s.state.value == WallSessionState.connecting ||
         s.state.value == WallSessionState.connected));
  }

  @override
  void onClose() {
    // Fire-and-forget cleanup; sessions will be torn down.
    disconnectAll();
    super.onClose();
  }
}
