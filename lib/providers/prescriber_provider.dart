import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prescription.dart';
import '../models/book.dart';
import '../services/ai_service.dart';
import '../services/zlibrary_api.dart';
import 'zlibrary_provider.dart';
import 'backend_auth_provider.dart';

/// AI 服务 Provider — 读取后端 JWT 注入
final aiServiceProvider = Provider<AiService>((ref) {
  final authState = ref.watch(backendAuthProvider);
  return RemoteAiService(token: authState.jwt ?? '');
});

/// 诊断状态
enum PrescriberStatus { idle, loading, done, error }

/// 诊断器状态
class PrescriberState {
  final PrescriberStatus status;
  final ReadingBag? result;
  final String? errorMessage;
  final String? preferredFormat; // 用户首选格式：pdf / epub / mobi / null(不限)

  const PrescriberState({
    this.status = PrescriberStatus.idle,
    this.result,
    this.errorMessage,
    this.preferredFormat,
  });

  PrescriberState copyWith({
    PrescriberStatus? status,
    ReadingBag? result,
    String? errorMessage,
    String? preferredFormat,
  }) {
    return PrescriberState(
      status: status ?? this.status,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      preferredFormat: preferredFormat ?? this.preferredFormat,
    );
  }
}

/// 诊断器 StateNotifier
class PrescriberNotifier extends StateNotifier<PrescriberState> {
  final AiService _aiService;
  final ZLibraryApi _api;

  PrescriberNotifier(this._aiService, this._api)
      : super(const PrescriberState());

  /// 设置首选格式
  void setFormat(String? format) {
    state = state.copyWith(preferredFormat: format);
  }

  /// 执行诊断
  Future<void> diagnose({
    required String input,
    String inputType = 'auto',
    String language = 'zh',
  }) async {
    state = PrescriberState(
      status: PrescriberStatus.loading,
      preferredFormat: state.preferredFormat,
    );

    try {
      final bag = await _aiService.diagnose(
        input: input,
        inputType: inputType,
        language: language,
      );
      state = PrescriberState(
        status: PrescriberStatus.done,
        result: bag,
        preferredFormat: state.preferredFormat,
      );

      // 异步匹配 ZLibrary 书籍
      _matchBooks(bag);
    } catch (e) {
      state = PrescriberState(
        status: PrescriberStatus.error,
        errorMessage: e.toString(),
        preferredFormat: state.preferredFormat,
      );
    }
  }

  /// 异步匹配每本书的 ZLibrary 资源
  Future<void> _matchBooks(ReadingBag bag) async {
    for (int i = 0; i < bag.tips.length; i++) {
      final tip = bag.tips[i];

      // 标记正在搜索 — 使用最新 state
      final currentTips = List<ReadingTip>.from(
        state.result?.tips ?? bag.tips,
      );
      currentTips[i] = tip.copyWith(isSearching: true);
      state = state.copyWith(
        result: (state.result ?? bag).copyWith(tips: currentTips),
      );

      try {
        final fmt = state.preferredFormat;
        final response = await _api.search(
          message: '${tip.bookName} ${tip.author}',
          extensions: fmt != null ? [fmt] : null,
          limit: 5,
        );

        Book? matchedBook;
        final success = response['success'];
        if ((success == true || success == 1) &&
            response.containsKey('books')) {
          final booksData = response['books'] as List<dynamic>;
          if (booksData.isNotEmpty) {
            matchedBook = Book.fromJson(booksData.first);
          }
        }

        // 更新匹配结果 — 使用最新 state
        final finalTips = List<ReadingTip>.from(
          state.result?.tips ?? bag.tips,
        );
        finalTips[i] = tip.copyWith(
          matchedBook: matchedBook,
          isSearching: false,
        );
        state = state.copyWith(
          result: (state.result ?? bag).copyWith(tips: finalTips),
        );
      } catch (_) {
        // 搜索失败，标记为未搜索
        final finalTips = List<ReadingTip>.from(
          state.result?.tips ?? bag.tips,
        );
        finalTips[i] = tip.copyWith(isSearching: false);
        state = state.copyWith(
          result: (state.result ?? bag).copyWith(tips: finalTips),
        );
      }
    }
  }

  /// 重置状态（保留格式设置）
  void reset() {
    state = PrescriberState(preferredFormat: state.preferredFormat);
  }
}

/// Provider
final prescriberProvider =
    StateNotifierProvider<PrescriberNotifier, PrescriberState>((ref) {
  final aiService = ref.read(aiServiceProvider);
  final api = ref.read(zlibraryApiProvider);
  return PrescriberNotifier(aiService, api);
});
