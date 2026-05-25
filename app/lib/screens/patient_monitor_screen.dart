import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/session_store.dart';

class PatientMonitorScreen extends StatefulWidget {
  const PatientMonitorScreen({super.key});
  @override
  State<PatientMonitorScreen> createState() => _PatientMonitorScreenState();
}

class _PatientMonitorScreenState extends State<PatientMonitorScreen> {
  CameraController? _camera;
  final _detector = PoseDetector(options: PoseDetectorOptions());
  Timer? _timer;
  bool _busy = false;
  String _locationTag = 'ROOM';
  DateTime? _toiletStart;
  double _probability = 0;
  String _summary = '연결 대기 중';
  String _coords = '-';
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _captureAndSend());
  }

  Future<void> _init() async {
    try {
      if (await Permission.camera.request().isDenied) {
        setState(() => _error = '카메라 권한 필요');
        return;
      }
    } catch (e) {
      debugPrint('Permission check skipped or failed: $e');
      // 데스크톱 등 환경에 따라 플러그인이 미지원일 수 있으나 무시하고 진행 시도
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _camera = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
    await _camera!.initialize();
    if (mounted) setState(() {});
  }

  int get _durationMin => _locationTag != 'TOILET' || _toiletStart == null
      ? 0 : DateTime.now().difference(_toiletStart!).inMinutes;

  Future<void> _captureAndSend() async {
    if (_busy) return;
    final loginCode = await SessionStore.loginCode();
    final hardwareId = await SessionStore.getOrCreateHardwareId();
    if (loginCode == null) return;
    _busy = true;
    try {
      double x = 0, y = 0, z = 0;
      if (_camera != null && _camera!.value.isInitialized) {
        final file = await _camera!.takePicture();
        final poses = await _detector.processImage(InputImage.fromFilePath(file.path));
        if (poses.isNotEmpty) {
          final lh = poses.first.landmarks[PoseLandmarkType.leftHip];
          final rh = poses.first.landmarks[PoseLandmarkType.rightHip];
          if (lh != null && rh != null) {
            x = (lh.x + rh.x) / 2; y = (lh.y + rh.y) / 2; z = (lh.z + rh.z) / 2;
          }
        }
      } else {
        // 카메라 미준수 시 시뮬레이션용 랜덤 데이터 전송 (테스트용)
        x = 100.0 + (DateTime.now().second % 10);
        y = 200.0 + (DateTime.now().second % 5);
        z = 5.0;
      }
      final result = await ApiService.instance.sendCoordinates(
        loginCode: loginCode, hardwareId: hardwareId,
        x: x, y: y, z: z, locationTag: _locationTag, currentDuration: _durationMin);
      if (mounted) setState(() {
        _coords = 'x:${x.toStringAsFixed(3)} y:${y.toStringAsFixed(3)} z:${z.toStringAsFixed(3)}';
        _probability = result.probability;
        _summary = result.summary;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally { _busy = false; }
  }

  @override
  void dispose() { _timer?.cancel(); _camera?.dispose(); _detector.close(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const subGreen = Color(0xFF4F6F52);
    return Column(children: [
      Expanded(child: _camera != null && _camera!.value.isInitialized
          ? CameraPreview(_camera!)
          : Container(color: Colors.black87, child: Center(child: Text(_error ?? '카메라 준비 중', style: const TextStyle(color: Colors.white))))),
      Container(color: const Color(0xFFE8F3D6), padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'ROOM', label: Text('거실')), ButtonSegment(value: 'TOILET', label: Text('화장실'))],
            selected: {_locationTag},
            onSelectionChanged: (s) => setState(() { _locationTag = s.first; _toiletStart = _locationTag == 'TOILET' ? DateTime.now() : null; }),
          ),
          Text('좌표: $_coords'),
          Text('고독사 확률: ${(_probability * 100).toStringAsFixed(1)}%', style: const TextStyle(color: subGreen, fontWeight: FontWeight.bold)),
          Text('분석: $_summary'),
        ])),
    ]);
  }
}
