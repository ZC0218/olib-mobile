import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/prescription.dart';
import '../../providers/prescriber_provider.dart';
import '../../providers/backend_auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import 'widgets/prescriber_input_section.dart';
import 'widgets/prescriber_result_section.dart';

class PrescriberScreen extends ConsumerStatefulWidget {
  const PrescriberScreen({super.key});

  @override
  ConsumerState<PrescriberScreen> createState() => _PrescriberScreenState();
}

class _PrescriberScreenState extends ConsumerState<PrescriberScreen>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  late AnimationController _animController;
  late AnimationController _loadingController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    // 每次进入页面时重置状态，避免残留的 done 状态导致白屏
    Future.microtask(() {
      ref.read(prescriberProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _animController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  /// 检查授权状态，未授权则跳转扫码页
  Future<bool> _ensureAuthorized() async {
    final authState = ref.read(backendAuthProvider);
    if (authState.isAuthorized) return true;

    final result = await Navigator.pushNamed(context, AppRoutes.qrAuth);
    return result == true;
  }

  void _diagnoseWithTheme(String themeId) async {
    if (!await _ensureAuthorized()) return;
    final locale = Localizations.localeOf(context).languageCode;
    ref.read(prescriberProvider.notifier).diagnose(
      input: themeId,
      inputType: 'theme',
      language: locale == 'zh' ? 'zh' : 'en',
    );
    _animController.forward(from: 0);
  }

  void _diagnoseWithInput() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (!await _ensureAuthorized()) return;
    final locale = Localizations.localeOf(context).languageCode;
    ref.read(prescriberProvider.notifier).diagnose(
      input: text,
      inputType: 'free',
      language: locale == 'zh' ? 'zh' : 'en',
    );
    _animController.forward(from: 0);
    FocusScope.of(context).unfocus();
  }

  /// 重试上一次失败：自由输入有内容则用自由输入，否则不动
  void _retryLastInput() {
    if (_inputController.text.trim().isNotEmpty) {
      _diagnoseWithInput();
    }
  }

  void _reset() {
    ref.read(prescriberProvider.notifier).reset();
    _inputController.clear();
    _animController.reset();
  }

  void _onGetBook(ReadingTip tip) {
    if (tip.matchedBook != null) {
      Navigator.of(context).pushNamed(
        AppRoutes.bookDetail,
        arguments: tip.matchedBook,
      );
    } else {
      Navigator.of(context).pushNamed(AppRoutes.search);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prescriberProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  isZh ? '✨ AI 智阅锦囊' : '✨ AI Reading Bag',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                centerTitle: true,
                actions: [
                  if (state.status == PrescriberStatus.done)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.primary),
                      onPressed: _reset,
                      tooltip: isZh ? '重新开始' : 'Start Over',
                    ),
                ],
              ),

              // Content
              if (state.status == PrescriberStatus.idle ||
                  state.status == PrescriberStatus.error)
                PrescriberInputSection(
                  inputController: _inputController,
                  onDiagnoseWithInput: _diagnoseWithInput,
                  onDiagnoseWithTheme: _diagnoseWithTheme,
                  onRetry: _retryLastInput,
                  isZh: isZh,
                ),

              if (state.status == PrescriberStatus.loading)
                _buildLoadingSection(isZh),

              if (state.status == PrescriberStatus.done &&
                  state.result != null)
                PrescriberResultSection(
                  bag: state.result!,
                  isZh: isZh,
                  fadeAnimation: _fadeAnim,
                  onReset: _reset,
                  onGetBook: _onGetBook,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 加载阶段 ====================
  Widget _buildLoadingSection(bool isZh) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 动画图标 — 持续旋转
            RotationTransition(
              turns: _loadingController,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isZh ? '正在为你挑选好书...' : 'AI is picking books for you...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isZh ? '请稍候片刻' : 'Please wait a moment',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
