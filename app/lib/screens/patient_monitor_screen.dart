import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _detector = PoseDetector(options: PoseDetectorOptions());
    }
    _init();
    _initPhotoListener();
    // 첫 전송은 즉시, 이후 10초마다
    Future.microtask(_captureAndSend);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _captureAndSend());
  }

  /// 웹·포즈 미검출 시: 시간에 따라 변하는 좌표 (10초 주기와 겹쳐도 매번 달라짐)
  ({double x, double y, double z}) _simulatedCoordinates() {
    _sendTick++;
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0 + _sendTick * 0.7;
    return (
      x: 150 + 40 * math.sin(t * 1.1),
      y: 250 + 35 * math.cos(t * 0.9),
      z: 8 + 6 * math.sin(t * 1.3),
    );
  }

  /// 피보호자 앱: 전면(셀카) 우선. 에뮬레이터는 전면을 PC 웹캠으로 설정해야 함.
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
    if (!kIsWeb) {
      try {
        final status = await Permission.camera.request();
        if (status.isDenied || status.isPermanentlyDenied) {
          if (mounted) {
            setState(() {
              _error = '카메라 권한 필요';
              _summary = '설정에서 카메라 권한을 허용해 주세요';
            });
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
        }
        return;
      }

      final selected = _pickCamera(cameras);
      _camera = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _camera!.initialize();
      if (mounted) {
        setState(() {
          _error = null;
          _summary = kIsWeb
              ? '카메라 연결됨 (웹: 포즈 좌표는 시뮬레이션)'
              : '카메라 연결됨';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = kIsWeb
              ? '브라우저에서 카메라를 허용해 주세요 (주소창 자물쇠/카메라 아이콘)'
              : '카메라 초기화 실패: $e';
          _summary = '카메라 없이 좌표 시뮬레이션으로 전송합니다';
        });
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
      }
      return;
    }
    _busy = true;
    try {
      double x = 0, y = 0, z = 0;
      var source = kIsWeb ? '시뮬레이션 (웹)' : '시뮬레이션';
      final canUsePoseDetection = !kIsWeb &&
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

      // 포즈 실패·웹·카메라 없음 → 매 전송마다 다른 좌표
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
        setState(() {
          _coords =
              'x:${x.toStringAsFixed(3)} y:${y.toStringAsFixed(3)} z:${z.toStringAsFixed(3)}';
          _coordSource = source;
          _probability = result.probability;
          _summary = result.summary;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = ApiService.formatError(e);
        setState(() {
          _error = msg;
          _summary = '서버 연결 실패';
        });
      }
    } finally {
      _busy = false;
    }
  }

  /// 긴급 시 보호자 열람용 1회 사진 업로드 후 로컬 파일 즉시 삭제
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
      Container(
        color: const Color(0xFFE8F3D6),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ROOM', label: Text('거실')),
                ButtonSegment(value: 'TOILET', label: Text('화장실')),
              ],
              selected: {_locationTag},
              onSelectionChanged: (s) => setState(() {
                _locationTag = s.first;
                _toiletStart =
                    _locationTag == 'TOILET' ? DateTime.now() : null;
              }),
            ),
            Text('서버: ${ApiConfig.baseUrl}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (_coordSource.isNotEmpty)
              Text('좌표 출처: $_coordSource', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text('좌표: $_coords'),
            Text(
              '고독사 확률: ${(_probability * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: subGreen, fontWeight: FontWeight.bold),
            ),
            Text('분석: $_summary'),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    ]);
  }
}
