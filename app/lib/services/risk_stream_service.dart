import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/api_config.dart';

/// STOMP 구독: /topic/risk/{loginCode}, /topic/photo-request/{loginCode}
class RiskStreamService {
  RiskStreamService._();
  static final RiskStreamService instance = RiskStreamService._();

  StompClient? _client;
  final _riskController = StreamController<Map<String, dynamic>>.broadcast();
  final _photoController = StreamController<Map<String, dynamic>>.broadcast();
  final _photoReadyController = StreamController<Map<String, dynamic>>.broadcast();
  final _crisisController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get riskUpdates => _riskController.stream;
  Stream<Map<String, dynamic>> get photoRequests => _photoController.stream;
  Stream<Map<String, dynamic>> get photoReady => _photoReadyController.stream;
  Stream<Map<String, dynamic>> get crisisAlerts => _crisisController.stream;

  bool get isConnected => _client?.connected ?? false;

  void connect(String loginCode) {
    disconnect();
    final url = ApiConfig.wsUrl(ApiConfig.baseUrl);
    print('Connecting to WebSocket: $url with loginCode: $loginCode');
    _client = StompClient(
      config: StompConfig(
        url: url,
        onConnect: (frame) {
          print('WebSocket Connected successfully.');
          _client?.subscribe(
            destination: '/topic/risk/$loginCode',
            callback: (frame) => _emit(frame, _riskController),
          );
          _client?.subscribe(
            destination: '/topic/photo-request/$loginCode',
            callback: (frame) => _emit(frame, _photoController),
          );
          _client?.subscribe(
            destination: '/topic/photo-ready/$loginCode',
            callback: (frame) => _emit(frame, _photoReadyController),
          );
          _client?.subscribe(
            destination: '/topic/crisis/$loginCode',
            callback: (frame) => _emit(frame, _crisisController),
          );
        },
        onWebSocketError: (err) {
          print('WebSocket Connection Error: $err');
        },
        onDebugMessage: (msg) {
          print('[STOMP Debug] $msg');
        },
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _client!.activate();
  }

  void _emit(StompFrame frame, StreamController<Map<String, dynamic>> target) {
    if (frame.body == null || frame.body!.isEmpty) return;
    try {
      target.add(Map<String, dynamic>.from(jsonDecode(frame.body!) as Map));
    } catch (_) {}
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }

  void dispose() {
    disconnect();
    _riskController.close();
    _photoController.close();
    _photoReadyController.close();
    _crisisController.close();
  }
}
