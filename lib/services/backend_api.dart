import 'package:dio/dio.dart';
import '../config/env.dart';

/// 后端 API 客户端 — 封装 /auth/* 接口
class BackendApi {
  late final Dio _dio;

  BackendApi({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? Env.authUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  /// 设备注册 — POST /auth/register
  /// 返回 {token, user_id, role}
  Future<Map<String, dynamic>> register({
    required String deviceId,
    String platform = 'android',
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'device_id': deviceId,
      'platform': platform,
    });
    return _parseResponse(response);
  }

  /// 获取授权二维码 — GET /auth/qrcode
  /// 返回 {qr_url, expire_seconds}
  Future<Map<String, dynamic>> getQrCode(String token) async {
    final response = await _dio.get(
      '/auth/qrcode',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _parseResponse(response);
  }

  /// 轮询授权状态 — GET /auth/status
  /// 返回 {status, token?, user_id?}
  Future<Map<String, dynamic>> checkStatus(String token) async {
    final response = await _dio.get(
      '/auth/status',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _parseResponse(response);
  }

  /// 解析通用响应 {success, data, error}
  Map<String, dynamic> _parseResponse(Response response) {
    final body = response.data as Map<String, dynamic>;
    if (body['success'] == true && body['data'] != null) {
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception(body['error'] ?? '请求失败');
  }
}
