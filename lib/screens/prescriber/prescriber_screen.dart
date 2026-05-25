import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/prescription.dart';
import '../../providers/prescriber_provider.dart';
import '../../providers/backend_auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../services/backend_books_api.dart';
import '../../utils/quota_phrases.dart';
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
    // 保留上次的结果：用户切走再回来仍能看到最近一次寻书的内容。
    // 若处于 done 状态，把出场动画也补播一遍，避免淡入态停在中间。
    Future.microtask(() {
      if (!mounted) return;
      final status = ref.read(prescriberProvider).status;
      if (status == PrescriberStatus.done) {
        _animController.value = 1.0;
      }
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

  /// 寻书结果点击处理：
  /// - AI 推荐 + 已匹配 → 走 backend 直接拿下载 URL（消耗当日免费下载次数）
  /// - 非 AI 来源 / 已匹配 → 进 book detail，由用户自己 z-library 账号下载
  /// - 未匹配 → 跳搜索
  Future<void> _onGetBook(ReadingTip tip) async {
    if (tip.matchedBook == null) {
      Navigator.of(context).pushNamed(AppRoutes.search);
      return;
    }
    if (tip.fromAi) {
      await _downloadAiBook(tip);
      return;
    }
    Navigator.of(context).pushNamed(
      AppRoutes.bookDetail,
      arguments: tip.matchedBook,
    );
  }

  /// AI 推荐书走 backend 下载 — 配额耗尽时显示文学化文案而非"配额已用完"。
  Future<void> _downloadAiBook(ReadingTip tip) async {
    final book = tip.matchedBook;
    if (book == null) return;
    final token = ref.read(backendAuthProvider).jwt;
    if (token == null) {
      // 入口已 gated，正常路径走不到这里
      return;
    }

    final api = BackendBooksApi();
    try {
      final url = await api.getAiBookDownloadUrl(
        olibToken: token,
        bookId: book.id.toString(),
        hashId: book.hash ?? '',
      );
      if (!mounted) return;
      // v1：交给 OS / 浏览器处理下载。后续可换成 DownloadNotifier 走 app 内下载管理。
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on FreeDownloadQuotaExceeded {
      if (!mounted) return;
      _showPhraseSnackBar(QuotaPhrases.randomFrom(QuotaPhrases.downloadQuota));
    } catch (e) {
      if (!mounted) return;
      final isZh = Localizations.localeOf(context).languageCode == 'zh';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isZh ? '下载失败：$e' : 'Download failed: $e')),
      );
    }
  }

  void _showPhraseSnackBar(String phrase) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(phrase),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prescriberProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary
                  .withValues(alpha: isDark ? 0.12 : 0.08),
              theme.scaffoldBackgroundColor,
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
                  isZh ? '✨ 寻书' : '✨ Find Books',
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
                      icon: Icon(Icons.refresh_rounded,
                          color: theme.colorScheme.primary),
                      onPressed: _reset,
                      tooltip: isZh ? '再寻一次' : 'Try again',
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
                _LoadingSection(
                  isZh: isZh,
                  rotationController: _loadingController,
                ),

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

}

// ════════════════════════════════════════════════════════════
//  Loading section — rotating reassurance copy
// ════════════════════════════════════════════════════════════

/// 加载态：图标持续旋转 + 文案每 2.5s 轮播，缓解 AI 生成 5-15 秒的焦虑。
class _LoadingSection extends StatefulWidget {
  final bool isZh;
  final AnimationController rotationController;

  const _LoadingSection({
    required this.isZh,
    required this.rotationController,
  });

  @override
  State<_LoadingSection> createState() => _LoadingSectionState();
}

class _LoadingSectionState extends State<_LoadingSection> {
  static const List<String> _messagesZh = [
    '正在翻阅书海...',
    '匹配你的心境...',
    '整理推荐理由...',
    '快好了，再等等...',
  ];

  static const List<String> _messagesEn = [
    'Browsing the bookshelves...',
    'Matching your mood...',
    'Drafting reasons...',
    'Almost there...',
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % _messages.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<String> get _messages => widget.isZh ? _messagesZh : _messagesEn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 旋转图标
            RotationTransition(
              turns: widget.rotationController,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 36,
                  color: cs.primary,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // 主文案
            Text(
              widget.isZh ? '正在为你寻书' : 'Finding books for you',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),

            // 轮播副文案 — AnimatedSwitcher 淡入淡出
            SizedBox(
              height: 22,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  _messages[_index],
                  key: ValueKey(_index),
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 进度条
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
