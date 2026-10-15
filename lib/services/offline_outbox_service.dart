import 'package:shared_preferences/shared_preferences.dart';
import '../models/mesh_packet.dart';

class OfflineOutboxService {
  static const String _keyOwnPending = 'lifetrace_own_pending_packet';
  static const String _keyRelayCache = 'lifetrace_mesh_relay_cache';
  static const String _keySeenIds = 'lifetrace_mesh_seen_ids';

  MeshPacket? _ownPendingPacket;
  final List<MeshPacket> _relayCache = [];
  final Set<String> _seenPacketIds = {};
  bool _initialized = false;

  bool get hasPendingItems => _ownPendingPacket != null || _relayCache.isNotEmpty;
  int get pendingCount => (_ownPendingPacket != null ? 1 : 0) + _relayCache.length;
  MeshPacket? get ownPendingPacket => _ownPendingPacket;
  List<MeshPacket> get allPendingForRelay => [
        ?_ownPendingPacket,
        ..._relayCache,
      ];

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();

    final rawOwn = prefs.getString(_keyOwnPending);
    if (rawOwn != null) {
      _ownPendingPacket = MeshPacket.fromRawPayload(rawOwn);
    }

    final rawRelay = prefs.getStringList(_keyRelayCache) ?? [];
    _relayCache.clear();
    for (final raw in rawRelay) {
      final packet = MeshPacket.fromRawPayload(raw);
      if (packet != null) _relayCache.add(packet);
    }

    final rawSeen = prefs.getStringList(_keySeenIds) ?? [];
    _seenPacketIds.addAll(rawSeen);
    _initialized = true;
  }

  Future<void> saveOwnPacket(MeshPacket packet) async {
    await init();
    _ownPendingPacket = packet;
    _seenPacketIds.add(packet.packetId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOwnPending, packet.toRawPayload());
    await _persistSeenIds(prefs);
  }

  Future<bool> ingestRelayPacket(MeshPacket packet, String currentDeviceId) async {
    await init();
    if (_seenPacketIds.contains(packet.packetId)) {
      return false;
    }
    if (packet.hopCount >= 5) {
      return false;
    }
    _seenPacketIds.add(packet.packetId);

    final forwarded = packet.incrementHop(currentDeviceId);
    _relayCache.add(forwarded);

    final prefs = await SharedPreferences.getInstance();
    final rawList = _relayCache.map((p) => p.toRawPayload()).toList();
    await prefs.setStringList(_keyRelayCache, rawList);
    await _persistSeenIds(prefs);
    return true;
  }

  Future<void> clearSyncedIds(List<String> syncedIds) async {
    await init();
    if (_ownPendingPacket != null && syncedIds.contains(_ownPendingPacket!.packetId)) {
      _ownPendingPacket = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyOwnPending);
    }

    _relayCache.removeWhere((p) => syncedIds.contains(p.packetId));
    final prefs = await SharedPreferences.getInstance();
    final rawList = _relayCache.map((p) => p.toRawPayload()).toList();
    await prefs.setStringList(_keyRelayCache, rawList);
  }

  Future<void> _persistSeenIds(SharedPreferences prefs) async {
    final list = _seenPacketIds.toList();
    if (list.length > 500) {
      list.removeRange(0, list.length - 500);
    }
    await prefs.setStringList(_keySeenIds, list);
  }
}
