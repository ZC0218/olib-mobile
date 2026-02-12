import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

/// Check if platform supports opening folder in file manager
bool get canOpenFolder {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux || Platform.isAndroid;
}

/// Open the download folder in the system file manager
Future<bool> openDownloadFolder() async {
  try {
    if (Platform.isAndroid) {
      // On Android, try to open the Olib folder in Downloads using url_launcher
      final path = '/storage/emulated/0/Download/Olib';
      final dir = Directory(path);
      
      // If Olib folder exists, try to open it; otherwise open Downloads
      String targetPath = await dir.exists() ? path : '/storage/emulated/0/Download';
      
      // Use url_launcher with file:// URI
      final uri = Uri.parse('file://$targetPath');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      
      // Fallback: Use content:// URI for Downloads
      final contentUri = Uri.parse('content://com.android.externalstorage.documents/document/primary:Download');
      if (await canLaunchUrl(contentUri)) {
        return await launchUrl(contentUri);
      }
      
      return false;
    } else if (Platform.isWindows) {
      // Get the actual Downloads folder on Windows
      final downloadsDir = await getDownloadsDirectory();
      final path = downloadsDir?.path ?? r'C:\Users\Public\Downloads';
      await Process.run('explorer', [path]);
      return true;
    } else if (Platform.isMacOS) {
      final downloadsDir = await getDownloadsDirectory();
      final path = downloadsDir?.path ?? '~/Downloads';
      await Process.run('open', [path]);
      return true;
    } else if (Platform.isLinux) {
      final downloadsDir = await getDownloadsDirectory();
      final path = downloadsDir?.path ?? '~/Downloads';
      await Process.run('xdg-open', [path]);
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('Failed to open download folder: $e');
    return false;
  }
}

/// Open a file with the system default application
Future<bool> openFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }
    final result = await OpenFilex.open(filePath);
    return result.type == ResultType.done;
  } catch (e) {
    debugPrint('Failed to open file: $e');
    return false;
  }
}

/// Get file size as human-readable string
String formatFileSize(int bytes) {
  if (bytes > 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  } else if (bytes > 1024) {
    return '${(bytes / 1024).toStringAsFixed(2)} KB';
  } else {
    return '$bytes B';
  }
}

/// Build a safe filename for saving files
String buildSafeFileName(String name, {String? extension}) {
  String safeName = name.replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), '').trim();
  if (safeName.isEmpty) {
    safeName = 'file_${DateTime.now().millisecondsSinceEpoch}';
  }
  if (extension != null && extension.isNotEmpty) {
    return '$safeName.$extension';
  }
  return safeName;
}
