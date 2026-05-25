import 'package:dio/dio.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  Future<Map<String, dynamic>> login(String loginCode) async {
    final res = await _dio.post('/api/users/login', data: {'loginCode': loginCode});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> registerDevice(String hardwareId, String loginCode) async {
    await _dio.post('/api/devices/register', data: {
      'hardwareId': hardwareId,
      'loginCode': loginCode,
    });
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

  Future<List<Map<String, dynamic>>> getActiveCrises() async {
    final res = await _dio.get('/api/crisis/active');
    final list = res.data as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

class CoordinateResult {
  final double probability;
  final String summary;
  final List<String> crises;
  CoordinateResult({required this.probability, required this.summary, required this.crises});
}
