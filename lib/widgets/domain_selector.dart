import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import '../providers/domain_provider.dart';
import '../theme/app_colors.dart';

class DomainSelector extends ConsumerWidget {
  final bool compact;
  final Color? color;

  const DomainSelector({
    super.key, 
    this.compact = false,
    this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentDomain = ref.watch(domainProvider);

    if (compact) {
      return IconButton(
        icon: const Icon(Icons.dns_outlined),
        color: color ?? AppColors.textPrimary,
        tooltip: 'Switch Network ($currentDomain)',
        onPressed: () => _showDialog(context),
      );
    }

    return InkWell(
      onTap: () => _showDialog(context),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: (color ?? AppColors.primary).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dns_outlined,
              size: 18,
              color: color ?? AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              currentDomain,
              style: TextStyle(
                color: color ?? AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: color ?? AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const DomainSelectionDialog(),
    );
  }
}

class DomainSelectionDialog extends ConsumerStatefulWidget {
  const DomainSelectionDialog({super.key});

  @override
  ConsumerState<DomainSelectionDialog> createState() => _DomainSelectionDialogState();
}

/// Result of a single domain speed test.
class _DomainResult {
  final String domain;
  /// null = still checking, -1 = failed, >0 = latency in ms
  int? latencyMs;

  _DomainResult(this.domain);
}

class _DomainSelectionDialogState extends ConsumerState<DomainSelectionDialog> {
  List<_DomainResult> _results = [];
  String _filter = '';
  bool _testing = false;
  int _testedCount = 0;

  /// Max concurrent requests to avoid flooding the network.
  static const int _maxConcurrent = 8;

  @override
  void initState() {
    super.initState();
    _initResults();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSpeedTest();
    });
  }

  void _initResults() {
    final domains = ref.read(domainListProvider);
    _results = domains.map((d) => _DomainResult(d)).toList();
  }

  /// Concurrent speed test with semaphore pattern.
  Future<void> _runSpeedTest() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _testedCount = 0;
      for (final r in _results) {
        r.latencyMs = null;
      }
    });

    // Create a pool of futures with bounded concurrency.
    int running = 0;
    int index = 0;
    final completer = Completer<void>();

    void scheduleNext() {
      while (running < _maxConcurrent && index < _results.length) {
        final r = _results[index++];
        running++;
        _checkDomain(r).whenComplete(() {
          running--;
          _testedCount++;
          if (mounted) setState(() {});
          if (index < _results.length) {
            scheduleNext();
          } else if (running == 0) {
            completer.complete();
          }
        });
      }
    }

    scheduleNext();
    await completer.future;

    if (mounted) {
      // Sort: successful (ascending latency) first, then failed at bottom.
      _results.sort((a, b) {
        final la = a.latencyMs ?? 99999;
        final lb = b.latencyMs ?? 99999;
        final aOk = la > 0 && la < 99999;
        final bOk = lb > 0 && lb < 99999;
        if (aOk && !bOk) return -1;
        if (!aOk && bOk) return 1;
        return la.compareTo(lb);
      });
      setState(() => _testing = false);
    }
  }

  Future<void> _checkDomain(_DomainResult result) async {
    final sw = Stopwatch()..start();
    try {
      final uri = Uri.parse('https://${result.domain}/eapi/info/languages');
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);

      try {
        final request = await client.getUrl(uri);
        final response = await request.close().timeout(
          const Duration(seconds: 8),
        );
        // Read a small chunk to confirm it's a real response.
        final bodyBytes = await response
            .expand((chunk) => chunk)
            .toList()
            .timeout(const Duration(seconds: 5));
        final body = String.fromCharCodes(bodyBytes);
        sw.stop();

        final isSuccess = body.contains('"success":1') ||
            body.contains('"success": 1') ||
            (response.statusCode >= 200 && response.statusCode < 300);

        if (mounted) {
          setState(() {
            result.latencyMs = isSuccess ? sw.elapsedMilliseconds : -1;
          });
        }
      } catch (_) {
        sw.stop();
        if (mounted) setState(() => result.latencyMs = -1);
      } finally {
        client.close();
      }
    } catch (_) {
      sw.stop();
      if (mounted) setState(() => result.latencyMs = -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDomain = ref.watch(domainProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';
    final domains = ref.watch(domainListProvider);

    // Filter
    final filtered = _filter.isEmpty
        ? _results
        : _results.where((r) =>
            r.domain.toLowerCase().contains(_filter.toLowerCase())).toList();

    final onlineCount = _results.where((r) => r.latencyMs != null && r.latencyMs! > 0).length;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isZh ? '选择线路' : 'Select Network',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              // Progress / count badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _testing
                    ? Row(
                        key: const ValueKey('testing'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              value: _results.isEmpty
                                  ? null
                                  : _testedCount / _results.length,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_testedCount/${_results.length}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      )
                    : Text(
                        key: const ValueKey('done'),
                        '$onlineCount/${_results.length} ✓',
                        style: TextStyle(
                          fontSize: 12,
                          color: onlineCount > 0 ? Colors.green : Colors.grey,
                        ),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: TextField(
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: isZh ? '搜索...' : 'Search...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 18),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.55,
        child: ListView.builder(
          itemCount: filtered.length + 1, // +1 for custom domain entry
          itemBuilder: (context, index) {
            if (index < filtered.length) {
              return _buildDomainTile(filtered[index], currentDomain);
            }
            // Last item: custom domain
            return _buildCustomTile(currentDomain, domains, isZh);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _testing ? null : () {
            _initResults();
            _runSpeedTest();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.speed, size: 16, color: _testing ? Colors.grey : null),
              const SizedBox(width: 4),
              Text(isZh ? '重新测速' : 'Re-test'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(isZh ? '关闭' : 'Close'),
        ),
      ],
    );
  }

  Widget _buildDomainTile(_DomainResult result, String currentDomain) {
    final isSelected = result.domain == currentDomain;
    final latency = result.latencyMs;

    // Status indicator
    Widget trailing;
    if (latency == null) {
      // Still testing
      trailing = const SizedBox(
        width: 14, height: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
    } else if (latency < 0) {
      // Failed
      trailing = const Icon(Icons.close, size: 16, color: Colors.red);
    } else {
      // Show latency with color coding
      Color latColor;
      if (latency < 1000) {
        latColor = Colors.green;
      } else if (latency < 3000) {
        latColor = Colors.orange;
      } else {
        latColor = Colors.red;
      }
      trailing = Text(
        '${latency}ms',
        style: TextStyle(
          fontSize: 12,
          color: latColor,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: isSelected
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const Icon(Icons.circle_outlined, size: 20, color: Colors.grey),
      title: Text(
        result.domain,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      trailing: trailing,
      onTap: () {
        ref.read(domainProvider.notifier).setDomain(result.domain);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildCustomTile(String currentDomain, List<String> domains, bool isZh) {
    final isCustom = !domains.contains(currentDomain);

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: isCustom
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
      title: Text(
        isCustom ? currentDomain : (isZh ? '自定义域名...' : 'Custom domain...'),
        style: TextStyle(
          fontSize: 13,
          fontWeight: isCustom ? FontWeight.w700 : FontWeight.normal,
          color: isCustom ? AppColors.primary : Colors.grey,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: () => _showCustomDomainDialog(context, ref),
    );
  }

  void _showCustomDomainDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    final locale = Localizations.localeOf(context).languageCode;
    final isZh = locale == 'zh';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '自定义线路' : 'Custom Domain'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isZh ? '域名地址' : 'Domain URL',
            hintText: 'e.g., z-library.sk',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isZh ? '取消' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(domainProvider.notifier).setCustomDomain(controller.text);
                Navigator.pop(context);
              }
            },
            child: Text(isZh ? '保存' : 'Save'),
          ),
        ],
      ),
    );
  }
}
