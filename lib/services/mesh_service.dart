import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nearby_connections/nearby_connections.dart';

import '../models/mesh_packet.dart';
import 'api_service.dart';
import 'offline_outbox_service.dart';

class MeshService extends ChangeNotifier {
  final OfflineOutboxService outbox;
  final ApiService api;
  final String serviceId = 'com.lifetrace.disastermesh';

  final Nearby _nearby = Nearby();
  final Set<String> _connectedEndpoints = {};
  final Set<String> _discoveredEndpoints = {};

  bool _isBroadcasting = false;
  bool _isSyncingGateway = false;
  int _activePeersCount = 0;
  String _statusMessage = 'Mesh Standby';
  DateTime? _lastSyncTime;
  Timer? _dutyCycleTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool get isBroadcasting => _isBroadcasting;
  bool get isSyncingGateway => _isSyncingGateway;
  int get activePeersCount => _activePeersCount;
  String get statusMessage => _statusMessage;
  DateTime? get lastSyncTime => _lastSyncTime;

  MeshService({
    required this.outbox,
    required this.api,
  });

  Future<void> initialize() async {
    await outbox.init();
    _listenConnectivity();
    _startBatteryDutyCycle();
    // Try initial sync if internet is currently available
    trySyncGateway();
  }

  void _listenConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        trySyncGateway();
      }
    });
  }

  /// Energy-conserving duty cycle:
  /// Discovers & advertises for 8 seconds, then sleeps for 35 seconds.
  void _startBatteryDutyCycle() {
    _dutyCycleTimer?.cancel();
    _dutyCycleTimer = Timer.periodic(const Duration(seconds: 45), (timer) async {
      if (!Platform.isAndroid) return;
      await _burstDiscoveryAndAdvertise(duration: const Duration(seconds: 8));
    });
  }

  /// High-priority burst triggered when user submits an emergency response or taps "Sync Now"
  Future<void> triggerEmergencyBurst() async {
    _statusMessage = 'Emergency Mesh Burst active';
    notifyListeners();
    await _burstDiscoveryAndAdvertise(duration: const Duration(seconds: 40));
  }

  Future<void> _burstDiscoveryAndAdvertise({required Duration duration}) async {
    if (!Platform.isAndroid) return;
    try {
      await _startAdvertisingAndDiscovery();
      await Future.delayed(duration);
    } catch (e) {
      debugPrint('Mesh burst error: $e');
    } finally {
      await _stopAdvertisingAndDiscovery();
    }
  }

  Future<void> _startAdvertisingAndDiscovery() async {
    try {
      final locPermission = await Geolocator.checkPermission();
      if (locPermission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final deviceName = 'LT_${DateTime.now().millisecondsSinceEpoch % 10000}';
      final strategy = Strategy.P2P_CLUSTER;

      // Start Advertising
      await _nearby.startAdvertising(
        deviceName,
        strategy,
        serviceId: serviceId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (endpointId, status) {
          if (status == Status.CONNECTED) {
            _connectedEndpoints.add(endpointId);
            _activePeersCount = _connectedEndpoints.length;
            _statusMessage = 'Connected to $_activePeersCount peers';
            _sendPendingPacketsToEndpoint(endpointId);
            notifyListeners();
          } else {
            _connectedEndpoints.remove(endpointId);
            _activePeersCount = _connectedEndpoints.length;
            notifyListeners();
          }
        },
        onDisconnected: (endpointId) {
          _connectedEndpoints.remove(endpointId);
          _activePeersCount = _connectedEndpoints.length;
          notifyListeners();
        },
      );

      // Start Discovery
      await _nearby.startDiscovery(
        deviceName,
        strategy,
        serviceId: serviceId,
        onEndpointFound: (endpointId, endpointName, serviceId) async {
          _discoveredEndpoints.add(endpointId);
          _statusMessage = 'Peer node found ($endpointName)';
          notifyListeners();
          try {
            await _nearby.requestConnection(
              deviceName,
              endpointId,
              onConnectionInitiated: _onConnectionInitiated,
              onConnectionResult: (id, status) {
                if (status == Status.CONNECTED) {
                  _connectedEndpoints.add(id);
                  _activePeersCount = _connectedEndpoints.length;
                  _statusMessage = 'Connected to $_activePeersCount peers';
                  _sendPendingPacketsToEndpoint(id);
                  notifyListeners();
                } else {
                  _connectedEndpoints.remove(id);
                  _activePeersCount = _connectedEndpoints.length;
                  notifyListeners();
                }
              },
              onDisconnected: (id) {
                _connectedEndpoints.remove(id);
                _activePeersCount = _connectedEndpoints.length;
                notifyListeners();
              },
            );
          } catch (e) {
            debugPrint('Failed to request connection to $endpointId: $e');
          }
        },
        onEndpointLost: (endpointId) {
          _discoveredEndpoints.remove(endpointId);
          notifyListeners();
        },
      );

      _isBroadcasting = true;
      _statusMessage = 'Scanning for nearby nodes...';
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting Nearby mesh: $e');
    }
  }

  Future<void> _onConnectionInitiated(String endpointId, ConnectionInfo info) async {
    // Automatically accept all LifeTrace peer mesh connections
    await _nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: (endpointId, payload) {
        final bytes = payload.bytes;
        if (payload.type == PayloadType.BYTES && bytes != null && bytes.isNotEmpty) {
          _handleIncomingPayload(bytes);
        }
      },
    );
  }

  Future<void> _stopAdvertisingAndDiscovery() async {
    try {
      await _nearby.stopAdvertising();
      await _nearby.stopDiscovery();
      _isBroadcasting = false;
      _statusMessage = _activePeersCount > 0
          ? 'Connected to $_activePeersCount peers'
          : 'Mesh Standby (Duty Cycling)';
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping Nearby mesh: $e');
    }
  }

  Future<void> _sendPendingPacketsToEndpoint(String endpointId) async {
    final pending = outbox.allPendingForRelay;
    if (pending.isEmpty) return;

    final jsonPayload = jsonEncode({
      'type': 'LIFETRACE_MESH_BUNDLE',
      'packets': pending.map((p) => p.toJson()).toList(),
    });
    final bytes = Uint8List.fromList(utf8.encode(jsonPayload));
    try {
      await _nearby.sendBytesPayload(endpointId, bytes);
      debugPrint('Transmitted ${pending.length} packets to peer $endpointId');
    } catch (e) {
      debugPrint('Failed to send payload to $endpointId: $e');
    }
  }

  Future<void> _handleIncomingPayload(Uint8List bytes) async {
    try {
      final raw = utf8.decode(bytes);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['type'] == 'LIFETRACE_MESH_BUNDLE') {
        final list = decoded['packets'] as List<dynamic>? ?? [];
        int newIngested = 0;
        final myDeviceId = 'node_${DateTime.now().millisecondsSinceEpoch % 10000}';
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final packet = MeshPacket.fromJson(item);
            final added = await outbox.ingestRelayPacket(packet, myDeviceId);
            if (added) newIngested++;
          }
        }
        if (newIngested > 0) {
          _statusMessage = 'Received $newIngested new alert(s) via Mesh';
          notifyListeners();
          // If we have internet right now, immediately upload these new packets to Render!
          trySyncGateway();
        }
      }
    } catch (e) {
      debugPrint('Error handling incoming mesh payload: $e');
    }
  }

  /// Acts as the Internet Gateway Sink:
  /// Uploads all queued responses (both own and relayed) to Render
  Future<bool> trySyncGateway() async {
    if (_isSyncingGateway) return false;
    final pending = outbox.allPendingForRelay;
    if (pending.isEmpty) return false;

    _isSyncingGateway = true;
    _statusMessage = 'Uplinking ${pending.length} alerts to cloud...';
    notifyListeners();

    try {
      final payload = {
        'packets': pending.map((p) => p.toJson()).toList(),
      };
      final res = await api.post('/responses/mesh-relay', payload);
      final accepted = (res['accepted_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      if (accepted.isNotEmpty) {
        await outbox.clearSyncedIds(accepted);
      }
      _lastSyncTime = DateTime.now();
      _statusMessage = 'Mesh sync complete: ${accepted.length} uploaded';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Mesh gateway sync failed (probably still offline): $e');
      _statusMessage = 'Offline: ${pending.length} alerts buffered in Mesh';
      notifyListeners();
      return false;
    } finally {
      _isSyncingGateway = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _dutyCycleTimer?.cancel();
    _connectivitySubscription?.cancel();
    _nearby.stopAllEndpoints();
    super.dispose();
  }
}
