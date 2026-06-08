import 'dart:async';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:monitoring_app/services/api_service.dart';
import 'package:monitoring_app/services/session_store.dart';
import 'package:monitoring_app/config/api_config.dart';
import 'package:monitoring_app/screens/guardian_home_screen.dart';
import 'package:monitoring_app/screens/guardian_notification_screen.dart';
import 'package:monitoring_app/screens/patient_monitor_screen.dart';
import 'package:monitoring_app/services/risk_stream_service.dart';

void main() {
  runApp(const GodoksaApp());
}

class AppSettings {
  static int fontLevel = 3; // 1~8단계

  // 글짜 크기 비율 계산
  static double get fontScale => 0.8 + (fontLevel - 1) * 0.1;
}

class GodoksaApp extends StatefulWidget {
  const GodoksaApp({super.key});

  @override
  State<GodoksaApp> createState() => _GodoksaAppState();

  static _GodoksaAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_GodoksaAppState>();
}

class _GodoksaAppState extends State<GodoksaApp> {
  void updateFontScale() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const Color mainDarkGreen = Color.fromARGB(255, 30, 82, 49);
    const Color subGreen = Color(0xFF4F6F52);

    return MaterialApp(
      title: '하루신호',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: subGreen,
          surface: const Color(0xFFF7F9F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F7),
        fontFamily: 'KCC-Hanbit', // 앱 전체 기본 폰트
        appBarTheme: const AppBarTheme(
          backgroundColor: mainDarkGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'YPairingFont',
            fontSize: 22,
            color: Colors.white,
          ),
        ),
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(AppSettings.fontScale)),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}

Route _createRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;
      var iTween = Tween(
        begin: begin,
        end: end,
      ).chain(CurveTween(curve: curve));
      return SlideTransition(position: animation.drive(iTween), child: child);
    },
    transitionDuration: const Duration(milliseconds: 600),
  );
}

// 스플래시 화면
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2000), () async {
      if (!mounted) return;
      if (await SessionStore.hasSession()) {
        final isGuardian = await SessionStore.isGuardian();
        Navigator.pushReplacement(
          context,
          _createRoute(
            isGuardian ? const GuardianMainHub() : const PatientMainHub(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          _createRoute(const RoleSelectionScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color requestedTextColor = Color.fromARGB(255, 30, 82, 49);
    return Scaffold(
      backgroundColor: const Color(0xFFE8F3D6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '소중한 사람과 마음을 연결하는',
              style: TextStyle(
                fontFamily: 'YPairingFont',
                fontSize: 18.0,
                color: requestedTextColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              '릾',
              style: TextStyle(
                fontFamily: 'YPairingFont',
                fontSize: 130.0,
                color: requestedTextColor,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              '하루 신호',
              style: TextStyle(
                fontFamily: 'YPairingFont',
                fontSize: 48.0,
                color: requestedTextColor,
                // fontWeight: FontWeight.bold, <- 충돌 방지를 위해 삭제
                height: 1.1,
              ),
            ),
            const Text(
              '서비스',
              style: TextStyle(
                fontFamily: 'YPairingFont',
                fontSize: 48.0,
                color: requestedTextColor,
                // fontWeight: FontWeight.bold, <- 충돌 방지를 위해 삭제
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 사용자 역할 선택 화면
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});
  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;
  final Color mainDarkGreen = const Color.fromARGB(255, 30, 82, 49);
  final Color subGreen = const Color(0xFF4F6F52);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('릾 하루신호')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '사용자 유형을 선택해주세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28.0,
                color: subGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 50),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedRole = 'patient'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: selectedRole == 'patient'
                            ? subGreen
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: subGreen, width: 2),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.accessibility_new,
                            size: 40,
                            color: selectedRole == 'patient'
                                ? Colors.white
                                : subGreen,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '피보호자용',
                            style: TextStyle(
                              fontFamily: 'Jalnan2',
                              fontSize: 22,
                              color: selectedRole == 'patient'
                                  ? Colors.white
                                  : subGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => selectedRole = 'guardian'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: selectedRole == 'guardian'
                            ? subGreen
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: subGreen, width: 2),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.supervisor_account,
                            size: 40,
                            color: selectedRole == 'guardian'
                                ? Colors.white
                                : subGreen,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '보호자용',
                            style: TextStyle(
                              fontFamily: 'Jalnan2',
                              fontSize: 22,
                              color: selectedRole == 'guardian'
                                  ? Colors.white
                                  : subGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            if (selectedRole != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainDarkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () {
                  if (selectedRole == 'patient') {
                    Navigator.push(
                      context,
                      _createRoute(const PatientConnectScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      _createRoute(const GuardianConnectScreen()),
                    );
                  }
                },
                child: const Text(
                  '시작하기',
                  style: TextStyle(
                    fontFamily: 'Jalnan2',
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 피보호자 연결 화면
class PatientConnectScreen extends StatefulWidget {
  const PatientConnectScreen({super.key});
  @override
  State<PatientConnectScreen> createState() => _PatientConnectScreenState();
}

class _PatientConnectScreenState extends State<PatientConnectScreen> {
  bool _loading = false;
  bool _loadingCode = true;
  String _code = '';
  String? _codeError;

  @override
  void initState() {
    super.initState();
    _issueConnectionCode();
  }

  Future<void> _issueConnectionCode() async {
    setState(() {
      _loadingCode = true;
      _codeError = null;
    });
    try {
      final hw = await SessionStore.getOrCreateHardwareId();
      final user = await ApiService.instance.connectPatient(hw);
      final code = user['loginCode']?.toString() ?? '';
      if (code.length != 6) {
        throw Exception('연결 코드를 받지 못했습니다.');
      }
      if (!mounted) return;
      setState(() => _code = code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _codeError = ApiService.formatError(e));
    } finally {
      if (mounted) setState(() => _loadingCode = false);
    }
  }

  Future<void> _startMonitoring() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결 코드를 먼저 발급받아 주세요.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final hw = await SessionStore.getOrCreateHardwareId();
      await SessionStore.saveSession(
        loginCode: _code,
        userName: '피보호자',
        role: 'PATIENT',
        isGuardian: false,
      );
      await ApiService.instance.registerDevice(hw, _code);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        _createRoute(const PatientMainHub()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서버 연결 실패: ${ApiService.formatError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color subGreen = Color(0xFF4F6F52);
    return Scaffold(
      appBar: AppBar(title: const Text('릾 하루신호')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open_rounded, size: 80, color: subGreen),
              const SizedBox(height: 20),
              const Text(
                '보호자에게 아래 코드를 알려주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  color: subGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3D6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text(
                      '내 연결 코드',
                      style: TextStyle(
                        fontSize: 18,
                        color: subGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loadingCode)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      )
                    else if (_codeError != null)
                      Column(
                        children: [
                          Text(
                            _codeError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _issueConnectionCode,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      )
                    else
                      Text(
                        ApiConfig.formatLoginCode(_code),
                        style: const TextStyle(
                          fontSize: 50,
                          color: subGreen,
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: (_loading || _loadingCode || _code.length != 6)
                          ? null
                          : _startMonitoring,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _loading ? '연결 중...' : '모니터링 시작',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: subGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 보호자 연결 화면
class GuardianConnectScreen extends StatefulWidget {
  const GuardianConnectScreen({super.key});
  @override
  State<GuardianConnectScreen> createState() => _GuardianConnectScreenState();
}

class _GuardianConnectScreenState extends State<GuardianConnectScreen> {
  final TextEditingController _codeController = TextEditingController();
  final Color mainDarkGreen = const Color.fromARGB(255, 30, 82, 49);
  final Color subGreen = const Color(0xFF4F6F52);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('릾 하루신호')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.vpn_key_rounded, size: 80, color: subGreen),
            const SizedBox(height: 20),
            Text(
              '피보호자 코드 입력',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                color: subGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: subGreen,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: subGreen, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: mainDarkGreen,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () async {
                final code = _codeController.text.trim();
                if (code.length != 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('6자리 코드를 입력하세요')),
                  );
                  return;
                }
                try {
                  final user = await ApiService.instance.connectGuardian(code);
                  final patientCode =
                      user['loginCode']?.toString() ?? code;
                  await SessionStore.saveSession(
                    loginCode: patientCode,
                    userName: user['name']?.toString() ?? '',
                    role: user['role']?.toString() ?? 'PATIENT',
                    isGuardian: true,
                  );
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    _createRoute(const GuardianMainHub()),
                    (route) => false,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '연결 실패: ${ApiService.formatError(e)}',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                '연결하기',
                style: TextStyle(
                  fontSize: 22,
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

class GuardianMainHub extends StatefulWidget {
  const GuardianMainHub({super.key});
  @override
  State<GuardianMainHub> createState() => _GuardianMainHubState();
}

class _GuardianMainHubState extends State<GuardianMainHub> {
  int _currentIndex = 0;
  final Map<DateTime, List<String>> _sharedMemoEvents = {};
  final Color subGreen = const Color(0xFF4F6F52);
  StreamSubscription<Map<String, dynamic>>? _crisisSub;
  StreamSubscription<Map<String, dynamic>>? _riskSub;

  @override
  void initState() {
    super.initState();
    _initGuardianRealtime();
  }

  Future<void> _initGuardianRealtime() async {
    final loginCode = await SessionStore.loginCode();
    if (loginCode == null || !mounted) return;
    RiskStreamService.instance.connect(loginCode);
    _crisisSub = RiskStreamService.instance.crisisAlerts.listen((data) {
      if (!mounted) return;
      final desc = data['description']?.toString() ?? '위험 상황이 감지되었습니다.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚨 $desc'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() => _currentIndex = 2);
    });

    _riskSub = RiskStreamService.instance.riskUpdates.listen((data) {
      if (!mounted) return;
      final prob = (data['solitaryDeathProbability'] as num?)?.toDouble() ?? 0.0;
      final summary = data['aiSummary']?.toString() ?? '';
      if (prob >= 0.6 && summary.isNotEmpty) {
        final now = DateTime.now();
        final keyDay = DateTime.utc(now.year, now.month, now.day);
        final hourStr = now.hour.toString().padLeft(2, '0');
        final minStr = now.minute.toString().padLeft(2, '0');
        final aiEventText = '[AI 위험] $hourStr:$minStr 위험도 ${(prob * 100).toStringAsFixed(1)}% - $summary';
        setState(() {
          _sharedMemoEvents.putIfAbsent(keyDay, () => []);
          if (!_sharedMemoEvents[keyDay]!.any((event) => event.contains('위험도 ${(prob * 100).toStringAsFixed(1)}%'))) {
            _sharedMemoEvents[keyDay]!.add(aiEventText);
            _sharedMemoEvents[keyDay]!.sort();
          }
        });
      }
    });

    try {
      final snapshot = await ApiService.instance.getLatestRisk(loginCode);
      if (snapshot != null && snapshot.probability >= 0.6) {
        final now = DateTime.now();
        final keyDay = DateTime.utc(now.year, now.month, now.day);
        final hourStr = now.hour.toString().padLeft(2, '0');
        final minStr = now.minute.toString().padLeft(2, '0');
        final aiEventText = '[AI 위험] $hourStr:$minStr 위험도 ${(snapshot.probability * 100).toStringAsFixed(1)}% - ${snapshot.summary}';
        setState(() {
          _sharedMemoEvents.putIfAbsent(keyDay, () => []);
          if (!_sharedMemoEvents[keyDay]!.any((event) => event.contains('위험도 ${(snapshot.probability * 100).toStringAsFixed(1)}%'))) {
            _sharedMemoEvents[keyDay]!.add(aiEventText);
            _sharedMemoEvents[keyDay]!.sort();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _crisisSub?.cancel();
    _riskSub?.cancel();
    RiskStreamService.instance.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const GuardianHomeScreen(),
      GuardianCalendarScreen(memoEvents: _sharedMemoEvents),
      const GuardianNotificationScreen(),
      const SettingsScreen(isGuardian: true),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('릾 하루신호')),
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: subGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: '홈'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: '캘린더',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_rounded),
            label: '알림',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class GuardianCalendarScreen extends StatefulWidget {
  final Map<DateTime, List<String>> memoEvents;
  const GuardianCalendarScreen({super.key, required this.memoEvents});
  @override
  State<GuardianCalendarScreen> createState() => _GuardianCalendarScreenState();
}

class _GuardianCalendarScreenState extends State<GuardianCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final TextEditingController _textController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 12, minute: 0);

  DateTime _normalizeDate(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  void _showMemoDialog(DateTime selectedDay) {
    final keyDay = _normalizeDate(selectedDay);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setPopupState) {
            final currentMemos = widget.memoEvents[keyDay] ?? [];
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.edit_calendar_rounded,
                    color: Color(0xFF4F6F52),
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${selectedDay.month}월 ${selectedDay.day}일 케어 스케줄',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A4D2E),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 360,
                child: Column(
                  children: [
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.access_time_filled_rounded,
                            size: 18,
                            color: Color(0xFF4F6F52),
                          ),
                          label: Text(
                            '${_selectedTime.period == DayPeriod.am ? "오전" : "오후"} ${_selectedTime.hourOfPeriod.toString().padLeft(2, "0")}:${_selectedTime.minute.toString().padLeft(2, "0")}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4F6F52),
                              fontSize: 14,
                            ),
                          ),
                          onPressed: () async {
                            final TimeOfDay? time = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (time != null)
                              setPopupState(() => _selectedTime = time);
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: '일정 입력...',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.bookmark_add_rounded,
                            color: Color(0xFF4F6F52),
                            size: 28,
                          ),
                          onPressed: () {
                            if (_textController.text.trim().isNotEmpty) {
                              final periodStr =
                                  _selectedTime.period == DayPeriod.am
                                  ? "오전"
                                  : "오후";
                              final hourStr = _selectedTime.hourOfPeriod
                                  .toString()
                                  .padLeft(2, '0');
                              final minStr = _selectedTime.minute
                                  .toString()
                                  .padLeft(2, '0');
                              final fullScheduleText =
                                  '$periodStr $hourStr:$minStr ${_textController.text.trim()}';
                              setState(() {
                                if (widget.memoEvents[keyDay] == null) {
                                  widget.memoEvents[keyDay] = [];
                                }
                                widget.memoEvents[keyDay]!.add(
                                  fullScheduleText,
                                );
                                widget.memoEvents[keyDay]!.sort();
                              });
                              setPopupState(() {});
                              _textController.clear();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: currentMemos.isEmpty
                          ? const Center(
                              child: Text(
                                '기록된 타임 스케줄이 없습니다.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: currentMemos.length,
                              itemBuilder: (context, index) {
                                final isAi = currentMemos[index].startsWith('[AI 위험]');
                                return Card(
                                  color: isAi ? const Color(0xFFFFF5F5) : const Color(0xFFF0F4F0),
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(
                                        isAi ? Icons.warning_rounded : Icons.circle,
                                        size: isAi ? 16 : 8,
                                        color: isAi ? Colors.red : const Color(0xFF4F6F52),
                                      ),
                                      title: Text(
                                        currentMemos[index],
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isAi ? Colors.red.shade900 : Colors.black87,
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            widget.memoEvents[keyDay]!.removeAt(
                                              index,
                                            );
                                          });
                                          setPopupState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    '닫기',
                    style: TextStyle(
                      color: Color(0xFF4F6F52),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCustomDayCell(
    DateTime day,
    Color textColor, {
    BoxDecoration? decoration,
    List<dynamic>? events,
  }) {
    final normalized = _normalizeDate(day);
    final dayEvents = events ?? widget.memoEvents[normalized] ?? [];
    final hasAiWarning = dayEvents.any((event) => event.toString().startsWith('[AI 위험]'));

    BoxDecoration? finalDecoration = decoration;
    Color finalTextColor = textColor;

    if (hasAiWarning) {
      if (decoration == null) {
        finalDecoration = BoxDecoration(
          color: const Color(0xFFFFF1F1),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red.shade300, width: 1.5),
        );
        finalTextColor = Colors.red.shade900;
      } else {
        final isSelected = decoration.color == const Color(0xFF4F6F52);
        final isToday = decoration.color == const Color(0xFF799F79);
        if (isSelected) {
          finalDecoration = const BoxDecoration(
            color: Color(0xFFD32F2F),
            shape: BoxShape.circle,
          );
        } else if (isToday) {
          finalDecoration = const BoxDecoration(
            color: Color(0xFFE57373),
            shape: BoxShape.circle,
          );
        }
      }
    }

    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: finalDecoration,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: finalTextColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 6,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: dayEvents
                  .take(4)
                  .map(
                    (event) {
                      final isAi = event.toString().startsWith('[AI 위험]');
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: SizedBox(
                          width: 5,
                          height: 5,
                          child: AspectRatio(
                            aspectRatio: 1.0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isAi ? Colors.red : const Color(0xFF4F6F52),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _showMemoDialog(selectedDay);
            },
            eventLoader: (day) => widget.memoEvents[_normalizeDate(day)] ?? [],
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) =>
                  _buildCustomDayCell(day, Colors.black87),
              outsideBuilder: (context, day, focusedDay) =>
                  const SizedBox.shrink(),
              todayBuilder: (context, day, focusedDay) => _buildCustomDayCell(
                day,
                Colors.white,
                decoration: const BoxDecoration(
                  color: Color(0xFF799F79),
                  shape: BoxShape.circle,
                ),
              ),
              selectedBuilder: (context, day, focusedDay) =>
                  _buildCustomDayCell(
                    day,
                    Colors.white,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F6F52),
                      shape: BoxShape.circle,
                    ),
                  ),
              markerBuilder: (context, date, events) => const SizedBox.shrink(),
            ),
            calendarStyle: const CalendarStyle(outsideDaysVisible: false),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            rowHeight: 68,
          ),
        ),
      ],
    );
  }
}

class PatientMainHub extends StatefulWidget {
  const PatientMainHub({super.key});
  @override
  State<PatientMainHub> createState() => _PatientMainHubState();
}

class _PatientMainHubState extends State<PatientMainHub> {
  int _currentIndex = 0;
  final Color subGreen = const Color(0xFF4F6F52);
  final List<Widget> _tabs = [
    const PatientMonitorScreen(),
    const SettingsScreen(isGuardian: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('릾 하루신호')),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: subGreen,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam_rounded),
            label: '카메라',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class PatientStatusScreen extends StatelessWidget {
  const PatientStatusScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_rounded, size: 80, color: Color(0xFFE8F3D6)),
            SizedBox(height: 20),
            Text(
              '실시간 카메라 동작 중',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '보호자 앱과 연결되어 카메라가 활성화되었습니다.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final bool isGuardian;
  const SettingsScreen({super.key, required this.isGuardian});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color mainDarkGreen = const Color.fromARGB(255, 30, 82, 49);
  final Color subGreen = const Color(0xFF4F6F52);

  void _showAddWardDialog() {
    final TextEditingController newWardCodeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            '피보호자 추가 등록',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '추가할 피보호자의 6자리 연결 코드를\n입력해주세요.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: newWardCodeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: subGreen,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  counterText: '',
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: subGreen, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: subGreen),
              onPressed: () async {
                final code = newWardCodeController.text.trim();
                if (code.length != 6) return;
                Navigator.pop(context);
                try {
                  final user = await ApiService.instance.login(code);
                  await SessionStore.saveSession(
                    loginCode: code,
                    userName: user['name']?.toString() ?? '',
                    role: user['role']?.toString() ?? 'PATIENT',
                    isGuardian: true,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${user['name']} 님 모니터링으로 전환했습니다.')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('등록 실패: $e')),
                  );
                }
              },
              child: const Text(
                '등록하기',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '앱 설정',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: subGreen,
            ),
          ),
          const SizedBox(height: 30),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields_rounded, color: subGreen),
                    const SizedBox(width: 10),
                    Text(
                      '전체 글자 크기 (${AppSettings.fontLevel}단계)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: AppSettings.fontLevel.toDouble(),
                  min: 1,
                  max: 8,
                  divisions: 7,
                  activeColor: subGreen,
                  thumbColor: subGreen,
                  inactiveColor: const Color(0xFFE8F3D6),
                  onChanged: (value) {
                    setState(() {
                      AppSettings.fontLevel = value.toInt();
                    });
                    GodoksaApp.of(context)?.updateFontScale();
                  },
                ),
                const Text(
                  '슬라이더를 움직여 앱 전체의 글자 크기를 조절하세요.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          if (widget.isGuardian) ...[
            Text(
              '관리 설정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: subGreen,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: Icon(Icons.person_add_alt_1_rounded, color: subGreen),
                title: const Text(
                  '새로운 피보호자 추가 등록',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('연결 코드를 입력하여 보호 대상을 추가합니다.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _showAddWardDialog,
              ),
            ),
          ] else ...[
            Text(
              '내 정보',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: subGreen,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: Icon(Icons.qr_code_2_rounded, color: subGreen),
                title: const Text(
                  '내 연결 코드 확인',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('보호자에게 알려줄 6자리 코드를 확인합니다.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  String? code;
                  try {
                    final hw = await SessionStore.getOrCreateHardwareId();
                    final user =
                        await ApiService.instance.connectPatient(hw);
                    code = user['loginCode']?.toString();
                  } catch (_) {
                    code = await SessionStore.loginCode();
                  }
                  if (!context.mounted) return;
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: Colors.white,
                      title: const Center(
                        child: Text(
                          '내 연결 코드',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      content: Text(
                        code != null && code.length == 6
                            ? ApiConfig.formatLoginCode(code)
                            : '-',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 5,
                          color: subGreen,
                        ),
                      ),
                      actions: [
                        Center(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: subGreen,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              '닫기',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text(
              '로그아웃',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
            onTap: () async {
              await SessionStore.clearSession();
              RiskStreamService.instance.disconnect();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                _createRoute(const RoleSelectionScreen()),
                (route) => false,
              );
            },
          ),
          if (!widget.isGuardian) ...[
            const SizedBox(height: 40),
            Center(
              child: TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const PatientDebugDialog(),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade300,
                  splashFactory: NoSplash.splashFactory,
                ),
                child: const Text('디버그 정보', style: TextStyle(fontSize: 10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
