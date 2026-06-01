import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'dart:async';

import '../services/api_service.dart';
import '../services/risk_stream_service.dart';
import '../services/session_store.dart';

class GuardianNotificationScreen extends StatefulWidget {
  const GuardianNotificationScreen({super.key});

  @override
  State<GuardianNotificationScreen> createState() =>
      _GuardianNotificationScreenState();
}

class _GuardianNotificationScreenState extends State<GuardianNotificationScreen> {
  final List<CrisisItem> _resolvedArchive = [];
  List<CrisisItem> _active = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _crisisSub;

  @override
  void initState() {
    super.initState();
    _load();
    _crisisSub = RiskStreamService.instance.crisisAlerts.listen((_) => _load());
  }

  @override
  void dispose() {
    _crisisSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loginCode = await SessionStore.loginCode();
      final items = await ApiService.instance.getActiveCrises(loginCode: loginCode);
      if (!mounted) return;
      setState(() {
        _active = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _resolve(CrisisItem item) async {
    try {
      await ApiService.instance.resolveCrisis(item.id);
      if (!mounted) return;
      setState(() {
        _resolvedArchive.insert(0, item);
        _active.removeWhere((c) => c.id == item.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('해제 실패: $e')),
      );
    }
  }

  String _dateGroup(DateTime? dt) {
    if (dt == null) return '기타';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${DateFormat('yyyy.MM.dd').format(dt)} (오늘)';
    }
    return DateFormat('yyyy.MM.dd').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('알림을 불러오지 못했습니다.\n$_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }

    final grouped = <String, List<CrisisItem>>{};
    for (final item in _active) {
      final key = _dateGroup(item.createdAt);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '실시간 위험 알림',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A4D2E),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('해제된 알림'),
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 280,
                          child: _resolvedArchive.isEmpty
                              ? const Center(child: Text('해제된 알림이 없습니다.'))
                              : ListView.builder(
                                  itemCount: _resolvedArchive.length,
                                  itemBuilder: (_, i) {
                                    final c = _resolvedArchive[i];
                                    return ListTile(
                                      title: Text(c.title),
                                      subtitle: Text(c.description),
                                    );
                                  },
                                ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('닫기'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('해제 내역'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _active.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            '현재 활성 위험 알림이 없습니다.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        for (final entry in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F6F52),
                              ),
                            ),
                          ),
                          for (final item in entry.value)
                            Card(
                              color: const Color(0xFFFFF5F5),
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.red,
                                  child: Icon(Icons.warning, color: Colors.white),
                                ),
                                title: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                subtitle: Text(item.description),
                                trailing: IconButton(
                                  icon: const Icon(Icons.check_circle_outline),
                                  tooltip: '조치 완료',
                                  onPressed: () => _resolve(item),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
