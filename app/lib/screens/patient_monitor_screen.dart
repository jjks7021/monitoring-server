import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:monitoring_app/config/api_config.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/risk_stream_service.dart';
import '../services/session_store.dart';

class PatientMonitorScreen extends StatefulWidget {
  const PatientMonitorScreen({super.key});
  @override
  State<PatientMonitorScreen> createState() => _PatientMonitorScreenState();
}

class _PatientMonitorScreenState extends State<PatientMonitorScreen> {
  CameraController? _camera;
  PoseDetector? _detector;
  Timer? _timer;
  StreamSubscription<Map<String, dynamic>>? _photoSub;
  bool _busy = false;
  String _locationTag = 'ROOM';
  DateTime? _toiletStart;
  double _probability = 0;
  String _summary = '연결 대기 중';
  String _coords = '-';
  String _coordSource = '';
  String? _error;
  int _sendTick = 0;
  double _aiAlertThresholdPercent = 60;

  // ML Kit 포즈는 모바일 환경만 지원됨
  static bool get _supportsMlKitPose =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    PatientDebugStore.triggerTestCrisis = _triggerTestCrisis;
    PatientDebugStore.setLocationTag = (tag) {
      setState(() {
        _locationTag = tag;
        _toiletStart = _locationTag == 'TOILET' ? DateTime.now() : null;
      });
      _syncStore();
    };
    if (_supportsMlKitPose) {
      _detector = PoseDetector(options: PoseDetectorOptions());
    }
    _init();
    _loadAlertConfig();
    _initPhotoListener();
    // 첫 전송은 즉시, 이후 10초마다
    Future.microtask(_captureAndSend);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _captureAndSend());
  }

  void _syncStore() {
    PatientDebugStore.coords.value = _coords;
    PatientDebugStore.coordSource.value = _coordSource;
    PatientDebugStore.probability.value = _probability;
    PatientDebugStore.summary.value = _summary;
    PatientDebugStore.error.value = _error;
    PatientDebugStore.busy.value = _busy;
    PatientDebugStore.locationTag.value = _locationTag;
    PatientDebugStore.aiAlertThresholdPercent.value = _aiAlertThresholdPercent;
  }

  // 포즈 미검출 시 임시 좌표 사용
  ({double x, double y, double z}) _simulatedCoordinates() {
    _sendTick++;
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0 + _sendTick * 0.7;
    return (
      x: 150 + 40 * math.sin(t * 1.1),
      y: 250 + 35 * math.cos(t * 0.9),
      z: 8 + 6 * math.sin(t * 1.3),
    );
  }

  // 전면 카메라 우선 사용
  CameraDescription _pickCamera(List<CameraDescription> cameras) {
    for (final c in cameras) {
      if (c.lensDirection == CameraLensDirection.front) return c;
    }
    for (final c in cameras) {
      final name = c.name.toLowerCase();
      if (!name.contains('virtual') && !name.contains('fake')) return c;
    }
    return cameras.first;
  }

  Future<void> _loadAlertConfig() async {
    try {
      final cfg = await ApiService.instance.getAlertConfig();
      final pct = (cfg['aiCrisisThresholdPercent'] as num?)?.toDouble();
      if (pct != null && mounted) {
        setState(() => _aiAlertThresholdPercent = pct);
        _syncStore();
      }
    } catch (_) {}
  }

  Future<void> _initPhotoListener() async {
    final loginCode = await SessionStore.loginCode();
    if (loginCode == null) return;
    RiskStreamService.instance.connect(loginCode);
    _photoSub = RiskStreamService.instance.photoRequests.listen((_) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('긴급 상황: 보호자 사진 요청을 수신했습니다.')),
      );
      await _respondToGuardianPhotoRequest();
    });
  }

  Future<void> _deleteCaptureFile(String? path) async {
    if (path == null || path.isEmpty || kIsWeb) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('임시 촬영 파일 삭제 실패: $e');
    }
  }

  Future<void> _init() async {
    // permission_handler는 macOS 데스크톱 미지원 → Info.plist + 시스템 설정 사용
    if (_supportsMlKitPose) {
      try {
        final status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            setState(() {
              _error = '카메라 권한 필요';
              _summary = '설정에서 카메라 권한을 허용해 주세요';
            });
            _syncStore();
          }
          return;
        }
      } catch (e) {
        debugPrint('Permission check skipped or failed: $e');
      }
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _error = '사용 가능한 카메라가 없습니다';
            _summary = '좌표 시뮬레이션으로 전송합니다';
          });
          _syncStore();
        }
        return;
      }

      final selected = _pickCamera(cameras);
      _camera = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            _isMacOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.jpeg,
      );
      await _camera!.initialize();
      if (mounted) {
        setState(() {
          _error = null;
          _summary = _supportsMlKitPose
              ? '카메라 연결됨'
              : _isMacOS
                  ? '카메라 연결됨 (macOS: 포즈 분석 없음, 좌표는 시뮬레이션)'
                  : '카메라 연결됨';
        });
        _syncStore();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = kIsWeb
              ? '브라우저에서 카메라를 허용해 주세요'
              : _isMacOS
                  ? '카메라 초기화 실패: $e\n시스템 설정 → 개인정보 보호 → 카메라에서 monitoring_app 허용'
                  : '카메라 초기화 실패: $e';
          _summary = '카메라 없이 좌표 시뮬레이션으로 전송합니다';
        });
        _syncStore();
      }
    }
  }

  int get _durationMin => _locationTag != 'TOILET' || _toiletStart == null
      ? 0 : DateTime.now().difference(_toiletStart!).inMinutes;

  Future<void> _captureAndSend() async {
    if (_busy) return;
    final loginCode = await SessionStore.loginCode();
    final hardwareId = await SessionStore.getOrCreateHardwareId();
    if (loginCode == null) {
      if (mounted) {
        setState(() {
          _summary = '로그인 필요';
          _error = '설정 → 로그아웃 후, 피보호자 → 모니터링 시작을 눌러주세요';
        });
        _syncStore();
      }
      return;
    }
    _busy = true;
    _syncStore();
    try {
      double x = 0, y = 0, z = 0;
      var source = kIsWeb ? '시뮬레이션 (웹)' : '시뮬레이션';
      final canUsePoseDetection = _supportsMlKitPose &&
          _detector != null &&
          _camera != null &&
          _camera!.value.isInitialized;

      String? capturePath;
      if (canUsePoseDetection) {
        try {
          final file = await _camera!
              .takePicture()
              .timeout(const Duration(seconds: 8));
          capturePath = file.path;
          final poses = await _detector!
              .processImage(InputImage.fromFilePath(file.path))
              .timeout(const Duration(seconds: 8));
          if (poses.isNotEmpty) {
            final lh = poses.first.landmarks[PoseLandmarkType.leftHip];
            final rh = poses.first.landmarks[PoseLandmarkType.rightHip];
            if (lh != null && rh != null) {
              x = (lh.x + rh.x) / 2;
              y = (lh.y + rh.y) / 2;
              z = (lh.z + rh.z) / 2;
              source = '포즈 분석 (ML Kit)';
            }
          }
        } on TimeoutException {
          // fall through to simulation
        } finally {
          await _deleteCaptureFile(capturePath);
        }
      }

      if (source != '포즈 분석 (ML Kit)') {
        final sim = _simulatedCoordinates();
        x = sim.x;
        y = sim.y;
        z = sim.z;
      }

      final result = await ApiService.instance.sendCoordinates(
        loginCode: loginCode,
        hardwareId: hardwareId,
        x: x,
        y: y,
        z: z,
        locationTag: _locationTag,
        currentDuration: _durationMin,
      );
      if (mounted) {
        final pct = result.probability * 100;
        final crossed = pct >= _aiAlertThresholdPercent;
        setState(() {
          _coords =
              'x:${x.toStringAsFixed(3)} y:${y.toStringAsFixed(3)} z:${z.toStringAsFixed(3)}';
          _coordSource = source;
          _probability = result.probability;
          _summary = result.summary;
          _error = null;
        });
        _syncStore();
        if (crossed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '위험도 ${pct.toStringAsFixed(0)}% 이상 → 보호자 자동 알림 전송 조건 충족',
              ),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = ApiService.formatError(e);
        setState(() {
          _error = msg;
          _summary = '서버 연결 실패';
        });
        _syncStore();
      }
    } finally {
      _busy = false;
      _syncStore();
    }
  }

  // 긴급 사진 전송 후 파일 삭제
  Future<void> _respondToGuardianPhotoRequest() async {
    if (_busy) return;
    final loginCode = await SessionStore.loginCode();
    final hardwareId = await SessionStore.getOrCreateHardwareId();
    if (loginCode == null) return;
    if (_camera == null || !_camera!.value.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카메라가 준비되지 않아 사진을 전송할 수 없습니다.')),
        );
      }
      return;
    }

    _busy = true;
    _syncStore();
    String? capturePath;
    try {
      final file = await _camera!.takePicture().timeout(const Duration(seconds: 8));
      capturePath = file.path;

      await ApiService.instance.uploadEmergencyPhoto(
        loginCode: loginCode,
        hardwareId: hardwareId,
        filePath: file.path,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('긴급 사진을 보호자에게 전달했습니다. (원본은 기기에서 삭제됨)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('긴급 사진 전송 실패: ${ApiService.formatError(e)}')),
        );
      }
    } finally {
      await _deleteCaptureFile(capturePath);
      _busy = false;
      _syncStore();
    }
    await _captureAndSend();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _photoSub?.cancel();
    RiskStreamService.instance.disconnect();
    _camera?.dispose();
    _detector?.close();
    _detector = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const subGreen = Color(0xFF4F6F52);
    return Column(children: [
      Expanded(
        child: _camera != null && _camera!.value.isInitialized
            ? CameraPreview(_camera!)
            : Container(
                color: Colors.black87,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.videocam_off_rounded,
                          size: 64,
                          color: Color(0xFFE8F3D6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error ?? '카메라 준비 중...',
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        if (kIsWeb) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Chrome이 카메라 사용을 물으면\n「허용」을 선택하세요',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ] else if (_isMacOS) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'macOS: 시스템 설정 → 개인정보 보호 → 카메라에서\n'
                            'monitoring_app 허용 후 「다시 연결」',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _init,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            '카메라 다시 연결',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    ]);
  }

  Future<void> _triggerTestCrisis() async {
    final loginCode = await SessionStore.loginCode();
    if (loginCode == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('연결 코드가 없습니다. 모니터링 시작을 먼저 해 주세요.')),
      );
      return;
    }
    setState(() => _busy = true);
    _syncStore();
    try {
      await ApiService.instance.triggerTestCrisis(loginCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('수동 테스트 알림만 전송했습니다. 실제 AI 자동 알림과는 별개입니다.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '전송 실패: ${ApiService.formatError(e)}\n'
            '서버: ${ApiConfig.baseUrl}',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _syncStore();
      }
    }
  }
}

class PatientDebugStore {
  static final ValueNotifier<String> coords = ValueNotifier('-');
  static final ValueNotifier<String> coordSource = ValueNotifier('');
  static final ValueNotifier<double> probability = ValueNotifier(0);
  static final ValueNotifier<String> summary = ValueNotifier('연결 대기 중');
  static final ValueNotifier<String?> error = ValueNotifier(null);
  static final ValueNotifier<bool> busy = ValueNotifier(false);
  static final ValueNotifier<String> locationTag = ValueNotifier('ROOM');
  static final ValueNotifier<double> aiAlertThresholdPercent = ValueNotifier(60);

  static VoidCallback? triggerTestCrisis;
  static void Function(String)? setLocationTag;
}

class PatientDebugDialog extends StatelessWidget {
  const PatientDebugDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        PatientDebugStore.coords,
        PatientDebugStore.coordSource,
        PatientDebugStore.probability,
        PatientDebugStore.summary,
        PatientDebugStore.error,
        PatientDebugStore.busy,
        PatientDebugStore.locationTag,
        PatientDebugStore.aiAlertThresholdPercent,
      ]),
      builder: (context, _) {
        const subGreen = Color(0xFF4F6F52);
        return AlertDialog(
          backgroundColor: const Color(0xFFE8F3D6),
          title: const Text('디버그 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'ROOM', label: Text('거실')),
                    ButtonSegment(value: 'TOILET', label: Text('화장실')),
                  ],
                  selected: {PatientDebugStore.locationTag.value},
                  onSelectionChanged: (s) {
                    PatientDebugStore.setLocationTag?.call(s.first);
                  },
                ),
                const SizedBox(height: 8),
                Text('서버: ${ApiConfig.baseUrl}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (PatientDebugStore.coordSource.value.isNotEmpty)
                  Text('좌표 출처: ${PatientDebugStore.coordSource.value}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text('좌표: ${PatientDebugStore.coords.value}', style: const TextStyle(fontSize: 13)),
                Text(
                  'AI 위험도 예측: ${(PatientDebugStore.probability.value * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(color: subGreen, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text('분석: ${PatientDebugStore.summary.value}', style: const TextStyle(fontSize: 13)),
                if (PatientDebugStore.error.value != null)
                  Text(
                    PatientDebugStore.error.value!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                if (PatientDebugStore.busy.value)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                const SizedBox(height: 6),
                Text(
                  '위험도가 ${PatientDebugStore.aiAlertThresholdPercent.value.toStringAsFixed(0)}% 이상이면 '
                  '좌표 전송 시 보호자 알림이 자동으로 갑니다.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: PatientDebugStore.busy.value ? null : PatientDebugStore.triggerTestCrisis,
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                  label: const Text(
                    '알림 경로만 수동 테스트 (AI 위험도 무관)',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기', style: TextStyle(color: subGreen, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }
}
