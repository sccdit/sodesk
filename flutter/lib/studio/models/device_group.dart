import 'package:flutter/material.dart';

class DeviceGroup {
  final String id;
  final String name;
  final IconData? icon;
  final Color? color;
  final List<DeviceGroup> children;
  final List<String> peerIds;
  final int onlineCount;
  final int totalCount;

  const DeviceGroup({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.children = const [],
    this.peerIds = const [],
    this.onlineCount = 0,
    this.totalCount = 0,
  });
}
