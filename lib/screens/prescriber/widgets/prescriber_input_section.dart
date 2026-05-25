import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/prescription.dart';
import '../../../providers/prescriber_provider.dart';
import '../../../theme/app_colors.dart';
import 'theme_card.dart';

class PrescriberInputSection extends ConsumerWidget {
  final TextEditingController inputController;
  final VoidCallback onDiagnoseWithInput;
  final void Function(String themeId) onDiagnoseWithTheme;
  final VoidCallback onRetry;
  final bool isZh;

  const PrescriberInputSection({
    super.key,
    required this.inputController,
    required this.onDiagnoseWithInput,
    required this.onDiagnoseWithTheme,
    required this.onRetry,
    required this.isZh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // 错误提示横条
            _buildErrorBanner(context, ref),
            // 顶部引导文案
            Text(
              isZh ? '选一个最近的状态' : 'Pick your current mood',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isZh
                  ? '我们会为你推荐最合适的书'
                  : "We'll recommend the perfect books for you",
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // 格式筛选
            _buildFormatPicker(context, ref),
            const SizedBox(height: 16),

            // 预设主题卡片
            ..._buildThemeCards(),

            const SizedBox(height: 28),

            // 分隔线
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    isZh ? '或者用自己的话描述' : 'Or describe in your own words',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),
            const SizedBox(height: 20),

            // 自由输入框
            TextField(
              controller: inputController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: isZh
                    ? '描述一下你最近的状态或困惑...'
                    : 'Describe how you feel lately...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // 生成锦囊按钮
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onDiagnoseWithInput,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      isZh ? '生成锦囊' : 'Generate Reading Bag',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, WidgetRef ref) {
    final state = ref.watch(prescriberProvider);
    if (state.status != PrescriberStatus.error || state.errorMessage == null) {
      return const SizedBox.shrink();
    }
    final canRetry = inputController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3F0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFCDC2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFE65A3D), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isZh ? '生成失败' : 'Failed to generate',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE65A3D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (canRetry)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFE65A3D),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(isZh ? '重试' : 'Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatPicker(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentFormat = ref.watch(prescriberProvider).preferredFormat;
    final formats = <String?>[null, 'pdf', 'epub', 'mobi'];
    final labels = <String?>[isZh ? '不限' : 'Any', 'PDF', 'EPUB', 'MOBI'];

    return Row(
      children: [
        Icon(Icons.filter_list_rounded, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          isZh ? '格式' : 'Format',
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 10),
        ...List.generate(formats.length, (i) {
          final fmt = formats[i];
          final selected = currentFormat == fmt;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                labels[i]!,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              selected: selected,
              selectedColor: cs.primary,
              backgroundColor: cs.surfaceContainerHighest,
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onSelected: (_) {
                ref.read(prescriberProvider.notifier).setFormat(fmt);
              },
            ),
          );
        }),
      ],
    );
  }

  List<Widget> _buildThemeCards() {
    final themes = prescriberThemes;
    final List<Widget> rows = [];

    for (int i = 0; i < themes.length; i += 2) {
      final row = Row(
        children: [
          Expanded(
            child: ThemeCard(
              theme: themes[i],
              isZh: isZh,
              onTap: () => onDiagnoseWithTheme(themes[i].id),
            ),
          ),
          const SizedBox(width: 12),
          if (i + 1 < themes.length)
            Expanded(
              child: ThemeCard(
                theme: themes[i + 1],
                isZh: isZh,
                onTap: () => onDiagnoseWithTheme(themes[i + 1].id),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      );
      rows.add(row);
      if (i + 2 < themes.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return rows;
  }
}
