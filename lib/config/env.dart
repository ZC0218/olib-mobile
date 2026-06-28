/// 环境配置 — 后端 API 基地址
///
/// 开发时使用本地端口，发布时使用生产 URL。
/// 通过 --dart-define=BACKEND_URL=xxx 可覆盖默认值。
class Env {
  Env._();

  /// 后端 API 基地址（AI 智阅锦囊等）
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://olibai.11xy.cn',
  );

  /// 微信认证服务地址
  static const String authUrl = String.fromEnvironment(
    'AUTH_URL',
    defaultValue: 'https://wxauth.11xy.cn',
  );

  /// 生产环境后端 URL（供参考 / CI 使用）
  static const String prodBackendUrl = 'https://bookbook.space';

  /// 当前是否为生产模式
  static bool get isProduction => backendUrl == prodBackendUrl;
}

