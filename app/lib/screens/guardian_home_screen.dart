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
  bool _hasActiveCrisis = false;
  String? _wardName;
  double _probability = 0;
  String _summary = '데이터를 불러오는 중입니다.';
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _riskSub;
  StreamSubscription<Map<String, dynamic>>? _photoReadySub;
  StreamSubscription<Map<String, dynamic>>? _crisisSub;

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
    _photoReadySub = RiskStreamService.instance.photoReady.listen((_) {
      _fetchAndShowEmergencyPhoto();
    });
    _crisisSub = RiskStreamService.instance.crisisAlerts.listen((_) => _load());
    try {
      final crises = await ApiService.instance.getActiveCrises(loginCode: loginCode);
      final snapshot = await ApiService.instance.getLatestRisk(loginCode);
      if (!mounted) return;
      setState(() {
        _hasActiveCrisis = crises.isNotEmpty;
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

  Future<void> _fetchAndShowEmergencyPhoto() async {
    final loginCode = await SessionStore.loginCode();
    if (loginCode == null || !mounted) return;
    try {
      final bytes = await ApiService.instance.fetchEmergencyPhoto(loginCode);
      if (!mounted || bytes == null) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          title: const Text('긴급 실시간 사진', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '1회만 열람 가능하며, 서버·기기에 사진이 저장되지 않습니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('닫기'),
            ),
          ],
        ),
      );
      setState(() => _photoRequested = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('사진 불러오기 실패: ${ApiService.formatError(e)}')),
      );
    }
  }

  Future<void> _requestPhoto() async {
    final loginCode = await SessionStore.loginCode();
    if (loginCode == null) return;

    if (!_hasActiveCrisis) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('활성 위험 알림이 있을 때만 긴급 사진 요청이 가능합니다.'),
        ),
      );
      return;
    }

    setState(() => _photoRequested = true);
    try {
      await ApiService.instance.requestPhoto(loginCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('피보호자 기기에 긴급 촬영을 요청했습니다. 잠시 후 사진이 표시됩니다.')),
      );

      for (var i = 0; i < 12; i++) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || !_photoRequested) return;
        final bytes = await ApiService.instance.fetchEmergencyPhoto(loginCode);
        if (bytes != null) {
          if (!mounted) return;
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('긴급 실시간 사진'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
              ],
            ),
          );
          setState(() => _photoRequested = false);
          return;
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('요청 실패: ${ApiService.formatError(e)}')),
      );
      setState(() => _photoRequested = false);
    }
  }

  @override
  void dispose() {
    _riskSub?.cancel();
    _photoReadySub?.cancel();
    _crisisSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _photoRequested ? Icons.cloud_sync_rounded : Icons.add_a_photo_rounded,
              size: 100,
              color: _hasActiveCrisis ? subGreen : Colors.grey,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _hasActiveCrisis ? const Color(0xFFFFF5F5) : const Color(0xFFF0F4F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _hasActiveCrisis ? '긴급 위험 활성 — 사진 열람 가능' : '현재 긴급 위험 없음 — 사진 요청 불가',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _hasActiveCrisis ? Colors.red : subGreen,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'AI 위험도 예측: ${(_probability * 100).toStringAsFixed(1)}%',
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
              '긴급 위험 감지 시에만 피보호자 실시간 사진을 1회 열람할 수 있습니다.\n'
              '원본 사진은 전송 후 서버·기기에서 즉시 삭제됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasActiveCrisis ? mainDarkGreen : Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: (_loading || !_hasActiveCrisis) ? null : _requestPhoto,
              child: Text(
                _photoRequested ? '촬영·전송 대기 중...' : '긴급 실시간 사진 요청',
                style: const TextStyle(
                  fontSize: 18,
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
