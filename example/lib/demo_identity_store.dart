import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Persistence and fallback identity for the Demo only.
///
/// No widget state, navigator, backend token or provider dependency belongs
/// here; UI state simply reads and writes the values.
class DemoIdentityStore {
  static const deviceIdKey = 'realtime_media_demo_device_id';
  static const displayNameKey = 'realtime_media_demo_display_name';

  Future<String> loadDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(deviceIdKey)?.trim();
      if (existing != null && existing.isNotEmpty) return existing;
      final id = generateDeviceId();
      await prefs.setString(deviceIdKey, id);
      return id;
    } catch (_) {
      return generateDeviceId();
    }
  }

  String defaultDisplayName(String deviceId) {
    final compact = deviceId.replaceAll('-', '');
    final suffix = compact.length >= 6 ? compact.substring(0, 6) : compact;
    return 'user-$suffix';
  }

  Future<String> loadDisplayName(String deviceId) async {
    final fallback = defaultDisplayName(deviceId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(displayNameKey)?.trim();
      if (saved != null && saved.isNotEmpty) return saved;
      await prefs.setString(displayNameKey, fallback);
    } catch (_) {
      // Demo identity is still usable if local persistence is unavailable.
    }
    return fallback;
  }

  Future<void> saveDisplayName(String value) async {
    final name = value.trim();
    if (name.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(displayNameKey, name);
    } catch (_) {
      // Persistence is optional; never prevent joining a media room.
    }
  }

  String generateDeviceId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
