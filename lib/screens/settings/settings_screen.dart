import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/ad_provider.dart';
import '../../services/ad_service.dart';
import '../../services/update_service.dart';
import '../../widgets/gradient_app_bar.dart';
import '../../widgets/banner_ad.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/domain_selector.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/file_utils.dart';
import '../../utils/locale_utils.dart' as locale_utils;
import '../../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: GradientAppBar(
          title: AppLocalizations.of(context).get('settings')),
      body: BottomBannerAd(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Profile Section
            if (user != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user.name[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleLarge,
                      ),
                      Text(
                        user.email,
                        style: Theme
                            .of(context)
                            .textTheme
                            .bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${user.downloadsLeft} ${AppLocalizations
                              .of(context)
                              .get('downloads_left_today')}',
                          style: Theme
                              .of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Library Section
            Text(
              AppLocalizations.of(context).get('library'),
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                        AppLocalizations.of(context).get('download_history')),
                    subtitle: Text(AppLocalizations.of(context).get(
                        'books_downloaded_any_device')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).pushNamed(AppRoutes.history);
                    },
                  ),
                ],
              ),
            ),

            // Download Directory Section (All platforms except iOS)
            if (!Platform.isIOS) ...[
              const SizedBox(height: 24),
              Text(
                locale_utils.isZhLocale(context) ? '下载' : 'Downloads',
                style: Theme
                    .of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(locale_utils.isZhLocale(context)
                      ? '下载目录'
                      : 'Download Directory'),
                  subtitle: Consumer(
                    builder: (context, ref, _) {
                      if (Platform.isAndroid) {
                        // Android 10+ uses MediaStore, show simplified text
                        return Text(
                          locale_utils.isZhLocale(context)
                              ? '系统下载文件夹 (MediaStore)'
                              : 'System Downloads (MediaStore)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      final path = ref.watch(downloadPathProvider);
                      final displayPath = (path != null && path.isNotEmpty)
                          ? path
                          : (locale_utils.isZhLocale(context)
                          ? '默认（应用文档目录）'
                          : 'Default (App Documents)');
                      return Text(
                        displayPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showDownloadPathDialog(context, ref),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Network Section
            Text(
              AppLocalizations.of(context).get('network'),
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 8),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.dns_rounded),
                    const SizedBox(width: 16),
                    Expanded(child: Text(
                        AppLocalizations.of(context).get('network_line'))),
                    const DomainSelector(compact: false),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Update Section
            Text(
              locale_utils.isZhLocale(context) ? '更新' : 'Update',
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                leading: const Icon(Icons.system_update),
                title: Text(locale_utils.isZhLocale(context)
                    ? '检查更新'
                    : 'Check for Updates'),
                subtitle: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version ?? '...';
                    return Text(
                      locale_utils.isZhLocale(context)
                          ? '当前版本: v$version'
                          : 'Current version: v$version',
                    );
                  },
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => UpdateService.showManualCheckDialog(context),
              ),
            ),

            const SizedBox(height: 24),

            // Ad-Free Section (only on mobile)
            if (AdService.isMobilePlatform) ...[
              _buildAdFreeSection(context, ref),
              const SizedBox(height: 24),
            ],

            // Theme Section
            Text(
              AppLocalizations.of(context).get('appearance'),
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  RadioListTile<AppThemeMode>(
                    title: Text(AppLocalizations.of(context).get('system')),
                    value: AppThemeMode.system,
                    groupValue: themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(themeModeProvider.notifier).setThemeMode(
                            value);
                      }
                    },
                  ),
                  RadioListTile<AppThemeMode>(
                    title: Text(AppLocalizations.of(context).get('light')),
                    value: AppThemeMode.light,
                    groupValue: themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(themeModeProvider.notifier).setThemeMode(
                            value);
                      }
                    },
                  ),
                  RadioListTile<AppThemeMode>(
                    title: Text(AppLocalizations.of(context).get('dark')),
                    value: AppThemeMode.dark,
                    groupValue: themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(themeModeProvider.notifier).setThemeMode(
                            value);
                      }
                    },
                  ),
                ],
              ),
            ),


            const SizedBox(height: 24),

            // Language Section
            Text(
              AppLocalizations.of(context).get('language_setting'),
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 8),

            Card(
              child: ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(
                    AppLocalizations.of(context).get('language_setting')),
                subtitle: Text(
                    _getLanguageDisplayName(ref.watch(localeProvider))),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguageDialog(context, ref),
              ),
            ),

            const SizedBox(height: 24),

            // App Info
            Text(
              AppLocalizations.of(context).get('about'),
              style: Theme
                  .of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(AppLocalizations.of(context).get('version')),
                    trailing: const Text('1.0.4'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.share_rounded),
                    title: Text(locale_utils.isZhLocale(context)
                        ? '分享应用'
                        : 'Share App'),
                    subtitle: Text(locale_utils.isZhLocale(context)
                        ? '推荐给朋友'
                        : 'Recommend to friends'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _shareApp(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.book_outlined),
                    title: Text(
                        AppLocalizations.of(context).get('about_zlibrary')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAboutApp(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: Text(locale_utils.isZhLocale(context)
                        ? 'GitHub 开源'
                        : 'GitHub Open Source'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () =>
                        _launchUrl('https://github.com/shiyi-0x7f/olib-mobile'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.login,
                          (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text(AppLocalizations.of(context).get('logout')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    inherit: false,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdFreeSection(BuildContext context, WidgetRef ref) {
    final adFreeState = ref.watch(adFreeProvider);
    final isZh = locale_utils.isZhLocale(context);
    final locale = Localizations
        .localeOf(context)
        .languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isZh ? '广告' : 'Ads',
          style: Theme
              .of(context)
              .textTheme
              .titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              // Ad-free status
              ListTile(
                leading: Icon(
                  adFreeState.isAdFree ? Icons.verified : Icons.ads_click,
                  color: adFreeState.isAdFree ? Colors.green : AppColors
                      .textSecondary,
                ),
                title: Text(isZh ? '免广告状态' : 'Ad-Free Status'),
                subtitle: Text(
                  adFreeState.isAdFree
                      ? (isZh
                      ? '剩余: ${adFreeState.getRemainingString(locale)}'
                      : 'Remaining: ${adFreeState.getRemainingString(locale)}')
                      : (isZh
                      ? '观看广告可免除广告'
                      : 'Watch ads to remove ads'),
                ),
                trailing: adFreeState.isAdFree
                    ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isZh ? '已激活' : 'Active',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                    : null,
              ),
              const Divider(height: 1),
              // Watch ad button
              ListTile(
                leading: const Icon(
                    Icons.play_circle_outline, color: AppColors.primary),
                title: Text(isZh ? '观看广告' : 'Watch Ad'),
                subtitle: Text(
                  AdService.getNextRewardDescription(locale),
                  style: TextStyle(
                    color: adFreeState.todayWatchCount >= 3
                        ? AppColors.textSecondary
                        : AppColors.primary,
                  ),
                ),
                trailing: adFreeState.todayWatchCount >= 3
                    ? Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.chevron_right),
                onTap: adFreeState.todayWatchCount >= 3
                    ? null
                    : () => _showRewardedAd(context, ref, isZh),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRewardedAd(BuildContext context, WidgetRef ref, bool isZh) {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Text(isZh ? '加载广告中...' : 'Loading ad...'),
              ],
            ),
          ),
    );

    AdService.showRewardedAd(
      onComplete: () async {
        Navigator.of(context).pop(); // Close loading

        final granted = await ref
            .read(adFreeProvider.notifier)
            .grantAdFreeTime();

        if (context.mounted) {
          final hours = granted.inHours;
          final minutes = granted.inMinutes % 60;
          String timeStr;
          if (isZh) {
            timeStr = hours > 0 ? '$hours小时' : '$minutes分钟';
          } else {
            timeStr = hours > 0 ? '$hours hours' : '$minutes minutes';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isZh
                    ? '🎉 获得 $timeStr 免广告时间！'
                    : '🎉 You got $timeStr ad-free!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onSkipped: () {
        Navigator.of(context).pop(); // Close loading

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isZh ? '广告未完成观看' : 'Ad was not completed',
              ),
            ),
          );
        }
      },
    );
  }

  String _getLanguageDisplayName(Locale? locale) {
    if (locale == null) return 'System';
    final key = locale_utils.getLocaleKey(locale);
    if (key == null) return '';
    return allLanguages[key]?['native'] ?? key;
  }

  void _showDownloadPathDialog(BuildContext context, WidgetRef ref) {
    final isZh = locale_utils.isZhLocale(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // On Android 10+, MediaStore handles downloads automatically
                  if (Platform.isAndroid) ...[
                    ListTile(
                      leading: const Icon(
                          Icons.download, color: AppColors.primary),
                      title: Text(
                          isZh ? '系统下载文件夹' : 'System Downloads Folder'),
                      subtitle: Text(
                        isZh
                            ? '使用 MediaStore API 保存到公共下载目录'
                            : 'Uses MediaStore API to save to public Downloads',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isZh ? '推荐' : 'Recommended',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700],
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isZh
                                    ? '下载的书籍将保存到系统"下载"文件夹，可在文件管理器中找到。'
                                    : 'Downloaded books will be saved to the system Downloads folder, accessible via file manager.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final success = await openDownloadFolder();
                                if (!success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(isZh
                                        ? '无法打开文件夹'
                                        : 'Could not open folder')),
                                  );
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              icon: const Icon(Icons.folder_open),
                              label: Text(isZh
                                  ? '打开下载文件夹'
                                  : 'Open Download Folder'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    ...[
                      // On desktop platforms, use file picker
                      ListTile(
                        leading: const Icon(
                            Icons.folder_open, color: AppColors.primary),
                        title: Text(isZh ? '选择文件夹' : 'Select Folder'),
                        subtitle: Text(isZh
                            ? '选择自定义下载目录'
                            : 'Choose a custom download directory'),
                        onTap: () async {
                          Navigator.pop(context);
                          final result = await FilePicker.platform
                              .getDirectoryPath();
                          if (result != null) {
                            ref
                                .read(downloadPathProvider.notifier)
                                .setDownloadPath(result);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isZh
                                      ? '下载目录已更新'
                                      : 'Download directory updated'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                            Icons.restore, color: AppColors.textSecondary),
                        title: Text(isZh ? '恢复默认' : 'Reset to Default'),
                        subtitle: Text(isZh
                            ? '使用应用默认文档目录'
                            : 'Use app default documents directory'),
                        onTap: () {
                          Navigator.pop(context);
                          ref
                              .read(downloadPathProvider.notifier)
                              .clearDownloadPath();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isZh
                                  ? '已恢复默认目录'
                                  : 'Reset to default directory'),
                            ),
                          );
                        },
                      ),
                    ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(isZh ? '关闭' : 'Close'),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp(BuildContext context) {
    final isZh = locale_utils.isZhLocale(context);
    final text = isZh
        ? '推荐一款开源电子书阅读器 Olib，由AI构建的第三方客户端！\n下载地址: https://bookbook.space\nGitHub: https://github.com/shiyi-0x7f/olib-mobile'
        : 'Check out Olib - an open-source ebook reader built with AI!\nDownload: https://bookbook.space\nGitHub: https://github.com/shiyi-0x7f/olib-mobile';
    Share.share(text);
  }

  void _showAboutApp(BuildContext context) {
    final isZh = locale_utils.isZhLocale(context);

    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                      Icons.auto_stories, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Text(
                  'Olib',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isZh
                        ? '🤖 AI构建的开源第三方客户端'
                        : '🤖 AI-Built Open Source Third-Party Client',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isZh
                        ? 'Olib 是一个由AI辅助构建的开源项目。\n\n📱 本项目仅提供前端界面\n📚 所有书籍数据来源于外部图书馆服务\n🔓 100% 开源，代码公开透明\n\n⚠️ 声明：\n• Olib 是第三方客户端，非官方客户端\n• 与任何官方服务无关联\n• 使用本应用即表示您理解并接受以上内容'
                        : 'Olib is an open-source project built with AI assistance.\n\n📱 This project only provides frontend interface\n📚 All book data comes from external library services\n🔓 100% open source, transparent code\n\n⚠️ Disclaimer:\n• Olib is a third-party client, not an official client\n• Not affiliated with any official service\n• By using this app you understand and accept the above',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isZh
                                ? '"知识无边界"'
                                : '"Knowledge has no boundaries"',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isZh ? '关闭' : 'Close'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _launchUrl('https://github.com/shiyi-0x7f/olib-mobile');
                },
                icon: const Icon(Icons.code, size: 16),
                label: Text(isZh ? '查看源码' : 'View Source'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.read(localeProvider);
    final currentKey = currentLocale != null
        ? getLocaleKey(currentLocale)
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) =>
                Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        AppLocalizations.of(context).get('language_setting'),
                        style: Theme
                            .of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          // System option
                          _buildLanguageOption(
                            context: context,
                            ref: ref,
                            key: null,
                            flag: '🌐',
                            native: 'System',
                            english: AppLocalizations.of(context).get(
                                'follow_device'),
                            isSelected: currentKey == null,
                          ),
                          const Divider(height: 1),
                          // All languages
                          ...allLanguages.entries.map((entry) =>
                              _buildLanguageOption(
                                context: context,
                                ref: ref,
                                key: entry.key,
                                flag: entry.value['flag']!,
                                native: entry.value['native']!,
                                english: entry.value['english']!,
                                isSelected: currentKey == entry.key,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildLanguageOption({
    required BuildContext context,
    required WidgetRef ref,
    required String? key,
    required String flag,
    required String native,
    required String english,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 28)),
      title: Text(native, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(english, style: TextStyle(color: Colors.grey[600])),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      onTap: () {
        if (key == null) {
          ref.read(localeProvider.notifier).setLocale(null);
        } else {
          ref.read(localeProvider.notifier).setLocale(
              locale_utils.parseLocaleKey(key));
        }
        Navigator.pop(context);
      },
    );
  }

  /// All supported languages with metadata
  static const allLanguages = {
    'en': {'flag': '🇺🇸', 'native': 'English', 'english': 'English'},
    'zh': {'flag': '🇨🇳', 'native': '简体中文', 'english': 'Simplified Chinese'},
    'zh_TW': {
      'flag': '🇹🇼',
      'native': '繁體中文',
      'english': 'Traditional Chinese'
    },
    'fr': {'flag': '🇫🇷', 'native': 'Français', 'english': 'French'},
    'es': {'flag': '🇪🇸', 'native': 'Español', 'english': 'Spanish'},
    'de': {'flag': '🇩🇪', 'native': 'Deutsch', 'english': 'German'},
    'pt': {'flag': '🇧🇷', 'native': 'Português', 'english': 'Portuguese'},
    'ru': {'flag': '🇷🇺', 'native': 'Русский', 'english': 'Russian'},
    'ja': {'flag': '🇯🇵', 'native': '日本語', 'english': 'Japanese'},
    'ko': {'flag': '🇰🇷', 'native': '한국어', 'english': 'Korean'},
    'ar': {'flag': '🇸🇦', 'native': 'العربية', 'english': 'Arabic'},
    'it': {'flag': '🇮🇹', 'native': 'Italiano', 'english': 'Italian'},
    'tr': {'flag': '🇹🇷', 'native': 'Türkçe', 'english': 'Turkish'},
    'vi': {'flag': '🇻🇳', 'native': 'Tiếng Việt', 'english': 'Vietnamese'},
    'th': {'flag': '🇹🇭', 'native': 'ไทย', 'english': 'Thai'},
    'id': {'flag': '🇮🇩', 'native': 'Bahasa Indonesia', 'english': 'Indonesian'},
  };
}