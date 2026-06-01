import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/risk_stream_service.dart';
import '../services/session_store.dart';

class GuardianHomeScreen extends StatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  State<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends State<GuardianHomeScreen> {
  bool _photoRequested = false;
  bool _loading = true;
  String? _wardName;
  double _probability = 0;
  String _summary = '데이터를 불러오는 중입니다.';
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _riskSub;

  final Color mainDarkGreen = const Color.fromARGB(255, 30, 82, 49);
  final Color subGreen = const Color(0xFF4F6F52);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loginCode = await SessionStore.loginCode();
    final name = await SessionStore.userName();
    if (loginCode == null) {
      setState(() {
        _loading = false;
        _error = '로그인 정보가 없습니다.';
      });
      return;
    }
    setState(() => _wardName = name);
    RiskStreamService.instance.connect(loginCode);
    _riskSub = RiskStreamService.instance.riskUpdates.listen((data) {
      if (!mounted) return;
      setState(() {
        _probability = (data['solitaryDeathProbability'] as num?)?.toDouble() ?? _probability;
        _summary = data['aiSummary']?.toString() ?? _summary;
      });
    });
    try {
      final snapshot = await ApiService.instance.getLatestRisk(loginCode);
      if (!mounted) return;
      setState(() {
        if (snapshot != null) {
          _probability = snapshot.probability;
          _summary = snapshot.summary;
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _requestPhoto() async {
    final loginCode = await SessionStore.loginCode();
    if (loginCode == null) return;
    setState(() => _photoRequested = true);
    try {
      await ApiService.instance.requestPhoto(loginCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('피보호자 기기에 촬영 요청을 보냈습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청 실패: $e')),
      );
      setState(() => _photoRequested = false);
    }
  }

  @override
  void dispose() {
    _riskSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _photoRequested ? Icons.cloud_sync_rounded : Icons.add_a_photo_rounded,
              size: 100,
              color: subGreen,
            ),
            const SizedBox(height: 24),
            Text(
              _wardName != null ? '$_wardName 님 모니터링' : '피보호자 안전 확인',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: subGreen,
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const CircularProgressIndicator()
            else ...[
              Text(
                '고독사 위험도: ${(_probability * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _probability >= 0.6 ? Colors.red : subGreen,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? _summary,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: _error != null ? Colors.red : Colors.grey,
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              '피보호자 스마트폰 카메라로 현재 공간 상황을 확인할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: mainDarkGreen,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _loading ? null : _requestPhoto,
              child: Text(
                _photoRequested ? '촬영 요청 전송됨' : '실시간 사진 촬영 요청',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
