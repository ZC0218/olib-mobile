import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backend_api.dart';
import '../services/hive_service.dart';

// ---------- Hive Keys ----------
const _kJwt = 'backend_jwt';
const _kRole = 'backend_role';
const _kUserId = 'backend_user_id';
const _kDeviceId = 'backend_device_id';

// ---------- State ----------

enum BackendAuthStatus { unknown, unauthorized, authorized }

class BackendAuthState {
  final BackendAuthStatus status;
  final String? jwt;
  final String? role;
  final int? userId;
  final String? qrUrl;
  final int? qrExpireSeconds;
  final bool isPolling;
  final String? error;

  const BackendAuthState({
    this.status = BackendAuthStatus.unknown,
    this.jwt,
    this.role,
    this.userId,
    this.qrUrl,
    this.qrExpireSeconds,
    this.isPolling = false,
    this.error,
  });

  bool get isAuthorized => status == BackendAuthStatus.authorized;

  BackendAuthState copyWith({
    BackendAuthStatus? status,
    String? jwt,
    String? role,
    int? userId,
    String? qrUrl,
    int? qrExpireSeconds,
    bool? isPolling,
    String? error,
  }) {
    return BackendAuthState(
      status: status ?? this.status,
      jwt: jwt ?? this.jwt,
      role: role ?? this.role,
      userId: userId ?? this.userId,
      qrUrl: qrUrl ?? this.qrUrl,
      qrExpireSeconds: qrExpireSeconds ?? this.qrExpireSeconds,
      isPolling: isPolling ?? this.isPolling,
      error: error ?? this.error,
    );
  }
}

// ---------- Notifier ----------

class BackendAuthNotifier extends StateNotifier<BackendAuthState> {
  final BackendApi _api;
  Timer? _pollTimer;

  BackendAuthNotifier(this._api) : super(const BackendAuthState()) {
    _init();
  }

  /// 初始化：从 Hive 恢复已有 JWT
  Future<void> _init() async {
    final box = HiveService.authBox;
    final jwt = box.get(_kJwt) as String?;
    final role = box.get(_kRole) as String?;
    final userId = box.get(_kUserId) as int?;

    if (jwt != null && (role == 'authorized' || role == 'admin')) {
      state = BackendAuthState(
        status: BackendAuthStatus.authorized,
        jwt: jwt,
        role: role,
        userId: userId,
      );
    } else if (jwt != null) {
      state = BackendAuthState(
        status: BackendAuthStatus.unauthorized,
        jwt: jwt,
        role: role,
        userId: userId,
      );
    } else {
      state = const BackendAuthState(status: BackendAuthStatus.unauthorized);
    }
  }

  /// 获取或生成 device_id
  Future<String> _getDeviceId() async {
    final box = HiveService.authBox;
    var deviceId = box.get(_kDeviceId) as String?;
    if (deviceId != null) return deviceId;

    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      deviceId = android.id; // Android ID
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      deviceId = ios.identifierForVendor ?? 'ios_unknown';
    } else {
      deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }
    await box.put(_kDeviceId, deviceId);
    return deviceId;
  }

  /// 设备注册 → 拿到临时 JWT
  Future<void> register() async {
    try {
      final deviceId = await _getDeviceId();
      final data = await _api.register(deviceId: deviceId);

      final jwt = data['token'] as String;
      final role = data['role'] as String;
      final userId = data['user_id'] as int;

      await _saveAuth(jwt, role, userId);

      if (role == 'authorized' || role == 'admin') {
        state = BackendAuthState(
          status: BackendAuthStatus.authorized,
          jwt: jwt,
          role: role,
          userId: userId,
        );
      } else {
        state = BackendAuthState(
          status: BackendAuthStatus.unauthorized,
          jwt: jwt,
          role: role,
          userId: userId,
        );
      }
    } catch (e) {
      state = BackendAuthState(
        status: BackendAuthStatus.unauthorized,
        error: '设备注册失败: $e',
      );
    }
  }

  /// 获取二维码 URL
  Future<void> fetchQrCode() async {
    if (state.jwt == null) await register();
    if (state.jwt == null) return;

    try {
      final data = await _api.getQrCode(state.jwt!);
      final qrUrl = data['qr_url'] as String;
      final expire = data['expire_seconds'] as int;

      if (qrUrl.isEmpty) {
        // 已授权
        state = state.copyWith(
          status: BackendAuthStatus.authorized,
        );
        return;
      }

      state = state.copyWith(
        qrUrl: qrUrl,
        qrExpireSeconds: expire,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: '获取二维码失败: $e');
    }
  }

  /// 开始轮询授权状态
  void startPolling() {
    if (state.isPolling || state.jwt == null) return;
    state = state.copyWith(isPolling: true);

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _checkStatus();
    });

    // 5分钟超时自动停止
    Future.delayed(const Duration(minutes: 5), () {
      if (state.isPolling && !state.isAuthorized) {
        stopPolling();
        state = state.copyWith(error: '授权超时，请重新扫码');
      }
    });
  }

  /// 停止轮询
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (mounted) {
      state = state.copyWith(isPolling: false);
    }
  }

  /// 检查授权状态
  Future<void> _checkStatus() async {
    if (state.jwt == null) return;
    try {
      final data = await _api.checkStatus(state.jwt!);
      final status = data['status'] as String;

      if (status == 'authorized') {
        final newToken = data['token'] as String?;
        final userId = data['user_id'] as int?;

        if (newToken != null) {
          await _saveAuth(newToken, 'authorized', userId ?? state.userId ?? 0);
          state = BackendAuthState(
            status: BackendAuthStatus.authorized,
            jwt: newToken,
            role: 'authorized',
            userId: userId ?? state.userId,
          );
        }
        stopPolling();
      }
    } catch (_) {
      // 网络错误时继续轮询，不中断
    }
  }

  /// 持久化认证信息
  Future<void> _saveAuth(String jwt, String role, int? userId) async {
    final box = HiveService.authBox;
    await box.put(_kJwt, jwt);
    await box.put(_kRole, role);
    if (userId != null) await box.put(_kUserId, userId);
  }

  /// 登出
  Future<void> logout() async {
    stopPolling();
    final box = HiveService.authBox;
    await box.delete(_kJwt);
    await box.delete(_kRole);
    await box.delete(_kUserId);
    state = const BackendAuthState(status: BackendAuthStatus.unauthorized);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ---------- Providers ----------

final backendApiProvider = Provider<BackendApi>((ref) => BackendApi());

final backendAuthProvider =
    StateNotifierProvider<BackendAuthNotifier, BackendAuthState>((ref) {
  final api = ref.read(backendApiProvider);
  return BackendAuthNotifier(api);
});
