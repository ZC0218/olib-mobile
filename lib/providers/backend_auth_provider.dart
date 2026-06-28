import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/backend_api.dart';
import '../services/hive_service.dart';

// ---------- Hive Keys ----------
const _kJwt = 'backend_jwt';
const _kRole = 'backend_role';
const _kUserId = 'backend_user_id';
const _kDeviceId = 'backend_device_id';
/// 最近一次授权成功的时间戳（ms since epoch）。
/// 用于 QR 授权页：24h 内进入时先尝试静默恢复，不直接弹二维码。
const _kLastAuthorizedAt = 'backend_last_authorized_at';

/// 静默恢复窗口：上次授权后这段时间内进入 QR 授权页，先尝试 register+/status
/// 自动续会话，失败才回退到二维码扫码。
const recoveryWindow = Duration(hours: 24);

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

  /// 初始化：从 Hive 恢复已有 JWT，然后主动向后端确认状态
  Future<void> _init() async {
    final box = HiveService.authBox;
    final jwt = box.get(_kJwt) as String?;
    final role = box.get(_kRole) as String?;
    final userId = box.get(_kUserId) as int?;

    if (jwt == null) {
      state = const BackendAuthState(status: BackendAuthStatus.unauthorized);
      return;
    }

    // 有本地 JWT → 先设置为缓存的状态
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

    // 后台异步向服务器确认最新状态（不阻塞 UI）
    _refreshStatusFromServer(jwt);
  }

  /// 向后端确认 JWT 是否仍然有效。
  /// 服务器 JWT_SECRET 轮换 / token 过期 → 401，这里要清掉本地 JWT 并
  /// 重新 register 拿 anon token，否则后续所有调用都会撞 401。
  Future<void> _refreshStatusFromServer(String jwt) async {
    try {
      final response = await _api.checkStatus(jwt);

      if (response.status == 'authorized') {
        final newToken = response.token ?? jwt;
        final userId = response.userId;
        await _saveAuth(newToken, 'authorized', userId ?? state.userId);
        if (mounted) {
          state = BackendAuthState(
            status: BackendAuthStatus.authorized,
            jwt: newToken,
            role: 'authorized',
            userId: userId ?? state.userId,
          );
        }
      } else {
        if (mounted) {
          state = BackendAuthState(
            status: BackendAuthStatus.unauthorized,
            jwt: jwt,
            role: response.status,
            userId: state.userId,
          );
        }
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        // JWT 已废（secret 轮换 / 过期 / audience 错），清掉重新拿。
        debugPrint(
          '[BackendAuth] cached JWT rejected by server '
          '(HTTP $code: ${e.response?.data}), re-registering...',
        );
        await register();
      } else {
        // 网络 / 5xx / 离线 — 保留本地缓存，等下次重试
        debugPrint('[BackendAuth] checkStatus failed (kept cache): $e');
      }
    } catch (e) {
      debugPrint('[BackendAuth] checkStatus unexpected error: $e');
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
      deviceId = android.id;
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      deviceId = ios.identifierForVendor ?? 'ios_unknown';
    } else {
      deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }
    await box.put(_kDeviceId, deviceId);
    return deviceId;
  }

  /// 设备注册 → 拿到 anon 握手 JWT。
  /// 注意：anon token 不代表已授权，仅用于调 /auth/qrcode 和轮询 /auth/status；
  /// 用户扫码后 /status 会签发正式 olib token 替换它。
  Future<void> register() async {
    try {
      final deviceId = await _getDeviceId();
      debugPrint('[BackendAuth] /auth/register device_id=$deviceId');
      final response = await _api.register(deviceId: deviceId);
      debugPrint(
        '[BackendAuth] register OK, anon token expires_in=${response.expiresIn}s',
      );

      final box = HiveService.authBox;
      await box.put(_kJwt, response.token);
      await box.delete(_kRole);
      await box.delete(_kUserId);

      state = BackendAuthState(
        status: BackendAuthStatus.unauthorized,
        jwt: response.token,
      );
    } on DioException catch (e) {
      debugPrint(
        '[BackendAuth] register FAILED: HTTP ${e.response?.statusCode} ${e.response?.data} '
        '(${e.message})',
      );
      state = BackendAuthState(
        status: BackendAuthStatus.unauthorized,
        error: '设备注册失败: ${e.response?.data ?? e.message ?? e}',
      );
    } catch (e) {
      debugPrint('[BackendAuth] register FAILED (unexpected): $e');
      state = BackendAuthState(
        status: BackendAuthStatus.unauthorized,
        error: '设备注册失败: $e',
      );
    }
  }

  /// 获取二维码 URL。anon JWT 过期（401）时自动 re-register 一次再重试。
  Future<void> fetchQrCode() async {
    if (state.jwt == null) await register();
    if (state.jwt == null) return;

    try {
      debugPrint('[BackendAuth] /auth/qrcode jwt=${state.jwt!.substring(0, 20)}...');
      final response = await _api.getQrCode(state.jwt!);
      debugPrint('[BackendAuth] qrcode OK: ${response.qrUrl}');
      state = state.copyWith(
        qrUrl: response.qrUrl,
        qrExpireSeconds: response.expireSeconds,
        error: null,
      );
    } on DioException catch (e) {
      debugPrint(
        '[BackendAuth] qrcode FAILED: HTTP ${e.response?.statusCode} ${e.response?.data}',
      );
      // anon token 30 分钟过期 / JWT_SECRET 轮换 / audience 错 → 重新 register 一次再调。
      if (e.response?.statusCode == 401) {
        debugPrint('[BackendAuth] qrcode 401, re-registering and retrying...');
        await register();
        if (state.jwt == null) return;
        try {
          final response = await _api.getQrCode(state.jwt!);
          debugPrint('[BackendAuth] qrcode retry OK: ${response.qrUrl}');
          state = state.copyWith(
            qrUrl: response.qrUrl,
            qrExpireSeconds: response.expireSeconds,
            error: null,
          );
          return;
        } on DioException catch (e2) {
          debugPrint(
            '[BackendAuth] qrcode retry FAILED: HTTP ${e2.response?.statusCode} ${e2.response?.data}',
          );
          state = state.copyWith(
            error: '获取二维码失败: ${e2.response?.data ?? e2.message ?? e2}',
          );
          return;
        } catch (e2) {
          state = state.copyWith(error: '获取二维码失败: $e2');
          return;
        }
      }
      state = state.copyWith(
        error: '获取二维码失败: ${e.response?.data ?? e.message ?? e}',
      );
    } catch (e) {
      debugPrint('[BackendAuth] qrcode unexpected error: $e');
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

    // 5 分钟超时自动停止
    Future.delayed(const Duration(minutes: 5), () {
      if (mounted && state.isPolling && !state.isAuthorized) {
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
      final response = await _api.checkStatus(state.jwt!);

      if (response.status == 'authorized') {
        final newToken = response.token ?? state.jwt!;
        final userId = response.userId;

        debugPrint('[BackendAuth] poll → authorized, user_id=$userId');
        await _saveAuth(newToken, 'authorized', userId ?? state.userId ?? 0);
        if (mounted) {
          state = BackendAuthState(
            status: BackendAuthStatus.authorized,
            jwt: newToken,
            role: 'authorized',
            userId: userId ?? state.userId,
          );
        }
        stopPolling();
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        // 轮询期间 anon token 突然失效（极少见，可能 secret 又换了）→ 停止轮询。
        debugPrint('[BackendAuth] poll rejected (HTTP $code), stopping');
        stopPolling();
        if (mounted) {
          state = state.copyWith(error: '会话已过期，请重新扫码');
        }
      } else {
        debugPrint('[BackendAuth] poll network err (kept polling): $e');
      }
    } catch (e) {
      debugPrint('[BackendAuth] poll unexpected: $e');
    }
  }

  /// 持久化认证信息。role == 'authorized' 时顺便打 timestamp，
  /// 给静默恢复窗口判定用。
  Future<void> _saveAuth(String jwt, String role, int? userId) async {
    final box = HiveService.authBox;
    await box.put(_kJwt, jwt);
    await box.put(_kRole, role);
    if (userId != null) await box.put(_kUserId, userId);
    if (role == 'authorized' || role == 'admin') {
      await box.put(_kLastAuthorizedAt, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// 返回上次授权成功的时间；从未授权或 Hive 没记录返回 null。
  DateTime? lastAuthorizedAt() {
    final ms = HiveService.authBox.get(_kLastAuthorizedAt) as int?;
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// 是否在静默恢复窗口内（即"24h 内授权过"）。
  bool get isWithinRecoveryWindow {
    final last = lastAuthorizedAt();
    if (last == null) return false;
    return DateTime.now().difference(last) < recoveryWindow;
  }

  /// 尝试静默恢复授权：重新 register 拿 anon token，再调 /status。
  /// 后端如果还记得这个 device → 直接返回 authorized + 正式 olib token，跳过二维码；
  /// 否则返回 false，调用方应回退到正常 QR 流程。
  Future<bool> tryRecoverAuth() async {
    try {
      debugPrint('[BackendAuth] tryRecoverAuth: re-register first');
      await register();
      if (state.jwt == null) {
        debugPrint('[BackendAuth] tryRecoverAuth: no anon jwt after register');
        return false;
      }

      final response = await _api.checkStatus(state.jwt!);
      if (response.status != 'authorized') {
        debugPrint(
          '[BackendAuth] tryRecoverAuth: status=${response.status}, 设备未绑定 → 走 QR',
        );
        return false;
      }

      final newToken = response.token ?? state.jwt!;
      final userId = response.userId;
      debugPrint('[BackendAuth] tryRecoverAuth: ✓ recovered, user_id=$userId');
      await _saveAuth(newToken, 'authorized', userId);
      if (mounted) {
        state = BackendAuthState(
          status: BackendAuthStatus.authorized,
          jwt: newToken,
          role: 'authorized',
          userId: userId,
        );
      }
      return true;
    } catch (e) {
      debugPrint('[BackendAuth] tryRecoverAuth failed: $e');
      return false;
    }
  }

  /// 登出 — 清除所有认证数据
  Future<void> logout() async {
    stopPolling();
    final box = HiveService.authBox;
    await box.delete(_kJwt);
    await box.delete(_kRole);
    await box.delete(_kUserId);
    await box.delete(_kLastAuthorizedAt);
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
