import 'package:flutter/material.dart';
import '../../../models/prescription.dart';
import '../../../theme/app_colors.dart';

class PrescriberResultSection extends StatelessWidget {
  final ReadingBag bag;
  final bool isZh;
  final Animation<double> fadeAnimation;
  final VoidCallback onReset;
  final void Function(ReadingTip tip) onGetBook;

  const PrescriberResultSection({
    super.key,
    required this.bag,
    required this.isZh,
    required this.fadeAnimation,
    required this.onReset,
    required this.onGetBook,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // 诊断单卡片
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 顶部装饰条
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_stories,
                              color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isZh ? '📜 你的专属阅读锦囊' : '📜 Your Reading Bag',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 诊断语
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                bag.diagnosis,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 书目列表
                    ...bag.tips.asMap().entries.map((entry) {
                      final index = entry.key;
                      final tip = entry.value;
                      return _buildBookTip(context, tip, index + 1);
                    }),

                    const SizedBox(height: 20),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 重新开始按钮
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isZh ? '重新开始' : 'Start Over'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookTip(BuildContext context, ReadingTip tip, int index) {
    final cs = Theme.of(context).colorScheme;
    final dosages = ['第一味', '第二味', '第三味'];
    final dosagesEn = ['First', 'Second', 'Third'];
    final doseLabel = isZh
        ? (index <= 3 ? dosages[index - 1] : '第$index味')
        : (index <= 3 ? dosagesEn[index - 1] : '#$index');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: GestureDetector(
        onTap: tip.isSearching ? null : () => onGetBook(tip),
        child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：剂次 + 类别
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    doseLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tip.category,
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 书名 + 作者
            Text(
              '📖 ${tip.bookName}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tip.author,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),

            // 推荐理由
            Text(
              tip.reason,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),

            // 去找书 按钮
            SizedBox(
              width: double.infinity,
              height: 40,
              child: tip.isSearching
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => onGetBook(tip),
                      icon: Icon(
                        tip.matchedBook != null
                            ? Icons.download_rounded
                            : Icons.search_rounded,
                        size: 18,
                      ),
                      label: Text(
                        tip.matchedBook != null
                            ? (isZh ? '查看并下载' : 'View & Download')
                            : (isZh ? '去找书' : 'Find Book'),
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: tip.matchedBook != null
                            ? AppColors.primary
                            : cs.onSurfaceVariant,
                        side: BorderSide(
                          color: tip.matchedBook != null
                              ? AppColors.primary
                              : cs.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
}
