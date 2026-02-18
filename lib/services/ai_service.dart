import 'package:dio/dio.dart';
import '../models/prescription.dart';
import '../config/env.dart';

/// AI 服务抽象接口
abstract class AiService {
  /// 生成阅读锦囊
  ///
  /// [input] - 预设主题 ID 或自由描述文本
  /// [inputType] - "theme" / "free" / "auto"（默认 "auto"）
  /// [language] - "zh" / "en"（默认 "zh"）
  Future<ReadingBag> diagnose({
    required String input,
    String inputType = 'auto',
    String language = 'zh',
  });
}

/// 远程 AI 服务 — 调用后端 POST /api/prescribe
class RemoteAiService implements AiService {
  late final Dio _dio;

  RemoteAiService({String? baseUrl, required String token}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? Env.backendUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30), // AI 生成较慢
      headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ));
  }

  @override
  Future<ReadingBag> diagnose({
    required String input,
    String inputType = 'auto',
    String language = 'zh',
  }) async {
    try {
      final response = await _dio.post(
        '/api/prescribe',
        data: {
          'input': input,
          'input_type': inputType,
          'language': language,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final success = body['success'];

      if (success == true) {
        final data = body['data'] as Map<String, dynamic>;
        return ReadingBag.fromJson(data);
      } else {
        final error = body['error'] as String? ?? '未知错误';
        throw Exception(error);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        if (data is Map<String, dynamic>) {
          final error = data['error'] ?? data['detail'] ?? '请求失败';
          throw Exception('$error (${e.response?.statusCode})');
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('连接超时，请检查网络后重试');
      }
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('无法连接服务器，请检查网络');
      }
      throw Exception('网络请求失败: ${e.message}');
    }
  }
}
