import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/backend_auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_localizations.dart';

/// 微信扫码授权页面
class QrAuthScreen extends ConsumerStatefulWidget {
  const QrAuthScreen({super.key});

  @override
  ConsumerState<QrAuthScreen> createState() => _QrAuthScreenState();
}

class _QrAuthScreenState extends ConsumerState<QrAuthScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    setState(() => _isLoading = true);
    final notifier = ref.read(backendAuthProvider.notifier);

    // 如果还没注册设备，先注册
    final state = ref.read(backendAuthProvider);
    if (state.jwt == null) {
      await notifier.register();
    }

    // 如果已授权，直接返回
    final updatedState = ref.read(backendAuthProvider);
    if (updatedState.isAuthorized) {
      if (mounted) Navigator.pop(context, true);
      return;
    }

    // 获取二维码
    await notifier.fetchQrCode();

    // 开始轮询
    notifier.startPolling();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refreshQrCode() async {
    setState(() => _isLoading = true);
    final notifier = ref.read(backendAuthProvider.notifier);
    notifier.stopPolling();
    await notifier.fetchQrCode();
    notifier.startPolling();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    ref.read(backendAuthProvider.notifier).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';
    final authState = ref.watch(backendAuthProvider);

    // 授权成功 → 自动关闭页面
    if (authState.isAuthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.08),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    Expanded(
                      child: Text(
                        isZh ? '扫码授权' : 'Scan to Authorize',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // 平衡的占位
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 图标
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFF07C160).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 36,
                            color: Color(0xFF07C160), // 微信绿
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 标题
                        Text(
                          isZh
                              ? '使用微信扫描下方二维码'
                              : 'Scan the QR code with WeChat',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isZh
                              ? '关注公众号即可解锁 AI 智阅锦囊功能'
                              : 'Follow our account to unlock AI features',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),

                        // 二维码区域
                        _buildQrSection(authState, isZh),

                        const SizedBox(height: 24),

                        // 状态提示
                        _buildStatusHint(authState, isZh),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrSection(BackendAuthState authState, bool isZh) {
    if (_isLoading) {
      return _buildQrContainer(
        child: const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }

    if (authState.error != null && authState.qrUrl == null) {
      return _buildQrContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(
              authState.error!,
              style: TextStyle(color: Colors.red[400], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _refreshQrCode,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isZh ? '重试' : 'Retry'),
            ),
          ],
        ),
      );
    }

    if (authState.qrUrl != null && authState.qrUrl!.isNotEmpty) {
      return Column(
        children: [
          _buildQrContainer(
            child: Image.network(
              authState.qrUrl!,
              width: 220,
              height: 220,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, loading) {
                if (loading == null) return child;
                return const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3),
                );
              },
              errorBuilder: (_, __, ___) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_rounded,
                      size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    isZh ? '图片加载失败' : 'Image loading failed',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _refreshQrCode,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              isZh ? '刷新二维码' : 'Refresh QR Code',
              style: const TextStyle(fontSize: 13),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    // 兜底
    return _buildQrContainer(
      child: Text(
        isZh ? '正在加载...' : 'Loading...',
        style: TextStyle(color: Colors.grey[500]),
      ),
    );
  }

  Widget _buildQrContainer({required Widget child}) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(child: child),
    );
  }

  Widget _buildStatusHint(BackendAuthState authState, bool isZh) {
    if (authState.isAuthorized) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF07C160), size: 20),
          const SizedBox(width: 8),
          Text(
            isZh ? '授权成功！' : 'Authorized!',
            style: const TextStyle(
              color: Color(0xFF07C160),
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      );
    }

    if (authState.isPolling) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            isZh ? '等待扫码中...' : 'Waiting for scan...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
