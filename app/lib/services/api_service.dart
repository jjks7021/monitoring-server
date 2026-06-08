import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true', // ngrok 사용할 때 필요함
    },
  ));

  Future<Map<String, dynamic>> login(String loginCode) async {
    final res = await _dio.post('/api/users/login', data: {'loginCode': loginCode});
    return Map<String, dynamic>.from(res.data as Map);
  }

  // 피보호자: 연결 코드 발급
  Future<Map<String, dynamic>> connectPatient(String hardwareId) async {
    final res = await _dio.post(
      '/api/users/patient/connect',
      data: {'hardwareId': hardwareId},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  // 보호자: 코드로 연결
  Future<Map<String, dynamic>> connectGuardian(String loginCode) async {
    final res = await _dio.post(
      '/api/users/guardian/connect',
      data: {'loginCode': loginCode},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getAlertConfig() async {
    final res = await _dio.get('/api/patient/alert-config');
    return Map<String, dynamic>.from(res.data as Map);
  }

  // 테스트 알림 전송
  Future<void> triggerTestCrisis(String loginCode) async {
    await _dio.post(
      '/api/patient/trigger-test-crisis',
      data: {'loginCode': loginCode},
    );
  }

  Future<void> registerDevice(String hardwareId, String loginCode) async {
    await _dio.post('/api/devices/register', data: {
      'hardwareId': hardwareId,
      'loginCode': loginCode,
    });
  }

  static String formatError(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return '서버에 연결할 수 없습니다. 백엔드(bootRun) 실행 및 API 주소를 확인하세요.\n(${ApiConfig.baseUrl})';
      }
      final body = e.response?.data;
      if (body is Map && body['error'] != null) return body['error'].toString();
      if (body is String && body.isNotEmpty) return body;
      final status = e.response?.statusCode;
      if (status == 404) {
        return 'API를 찾을 수 없습니다(404).\n'
            '루트 프로젝트 MonitoringServerApplication을 Rebuild 후 재시작했는지 확인하세요.\n'
            '(${ApiConfig.baseUrl})';
      }
      if (status == 500) {
        return '서버 오류가 발생했습니다. 백엔드를 재시작한 뒤 다시 시도해 주세요.';
      }
      if (status == 400) {
        return (body is Map && body['error'] != null)
            ? body['error'].toString()
            : '요청이 잘못되었습니다(400). 모니터링 시작 후 다시 시도하세요.';
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  Future<CoordinateResult> sendCoordinates({
    required String loginCode,
    required String hardwareId,
    required double x,
    required double y,
    required double z,
    required String locationTag,
    required int currentDuration,
  }) async {
    try {
      return await _postCoordinates(
        loginCode: loginCode,
        hardwareId: hardwareId,
        x: x,
        y: y,
        z: z,
        locationTag: locationTag,
        currentDuration: currentDuration,
      );
    } on DioException catch (e) {
      final body = e.response?.data?.toString() ?? '';
      if (e.response?.statusCode == 400 && body.contains('등록되지 않은 기기')) {
        await registerDevice(hardwareId, loginCode);
        return _postCoordinates(
          loginCode: loginCode,
          hardwareId: hardwareId,
          x: x,
          y: y,
          z: z,
          locationTag: locationTag,
          currentDuration: currentDuration,
        );
      }
      rethrow;
    }
  }

  Future<CoordinateResult> _postCoordinates({
    required String loginCode,
    required String hardwareId,
    required double x,
    required double y,
    required double z,
    required String locationTag,
    required int currentDuration,
  }) async {
    final res = await _dio.post('/api/devices/coordinates', data: {
      'loginCode': loginCode,
      'hardwareId': hardwareId,
      'x': x,
      'y': y,
      'z': z,
      'locationTag': locationTag,
      'currentDuration': currentDuration,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    return CoordinateResult(
      probability: (data['solitaryDeathProbability'] as num?)?.toDouble() ?? 0,
      summary: data['aiSummary']?.toString() ?? '',
      crises: (data['activeCrises'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Future<List<CrisisItem>> getActiveCrises({String? loginCode}) async {
    final res = await _dio.get(
      '/api/crisis/active',
      queryParameters: loginCode != null ? {'loginCode': loginCode} : null,
    );
    final list = res.data as List;
    return list
        .map((e) => CrisisItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> resolveCrisis(int id) async {
    await _dio.post('/api/crisis/$id/resolve');
  }

  Future<RiskSnapshot?> getLatestRisk(String loginCode) async {
    try {
      final res = await _dio.get('/api/risk/latest/$loginCode');
      final data = Map<String, dynamic>.from(res.data as Map);
      return RiskSnapshot(
        probability: (data['probability'] as num?)?.toDouble() ?? 0,
        summary: data['aiSummary']?.toString() ?? '',
        ruleAlerts: data['ruleAlerts']?.toString(),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> requestPhoto(String loginCode) async {
    await _dio.post('/api/guardian/photo-request/$loginCode');
  }

  Future<void> uploadEmergencyPhoto({
    required String loginCode,
    required String hardwareId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'loginCode': loginCode,
      'hardwareId': hardwareId,
      'image': await MultipartFile.fromFile(
        filePath,
        filename: 'emergency.jpg',
      ),
    });
    await _dio.post(
      '/api/devices/emergency-photo',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // 긴급 사진 1회 열람
  Future<Uint8List?> fetchEmergencyPhoto(String loginCode) async {
    try {
      final res = await _dio.get<List<int>>(
        '/api/guardian/emergency-photo/$loginCode',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data;
      if (data == null || data.isEmpty) return null;
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 403) {
        return null;
      }
      rethrow;
    }
  }
}

class CoordinateResult {
  final double probability;
  final String summary;
  final List<String> crises;
  CoordinateResult({required this.probability, required this.summary, required this.crises});
}

class CrisisItem {
  final int id;
  final String loginCode;
  final String userName;
  final String crisisType;
  final String description;
  final DateTime? createdAt;

  CrisisItem({
    required this.id,
    required this.loginCode,
    required this.userName,
    required this.crisisType,
    required this.description,
    this.createdAt,
  });

  factory CrisisItem.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['createdAt'];
    if (raw != null) {
      created = DateTime.tryParse(raw.toString());
    }
    return CrisisItem(
      id: (json['id'] as num).toInt(),
      loginCode: json['loginCode']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      crisisType: json['crisisType']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAt: created,
    );
  }

  String get title {
    switch (crisisType) {
      case 'TOILET_OVERFLOW':
        return '화장실 체류 시간 이상';
      case 'LETHARGY':
        return '활동량 급감 감지';
      case 'TEST_MANUAL':
        return '테스트 위험 알림';
      case 'AI_HIGH_RISK':
        return 'AI 고독사 위험 경고';
      default:
        return '위험 상황 감지';
    }
  }
}

class RiskSnapshot {
  final double probability;
  final String summary;
  final String? ruleAlerts;
  RiskSnapshot({required this.probability, required this.summary, this.ruleAlerts});
}
