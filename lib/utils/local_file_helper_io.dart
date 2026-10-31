import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class LocalFileHelper {
  /// Copies a file or byte array into the persistent attachments directory.
  static Future<String?> persistFileLocally({
    String? sourcePath,
    Uint8List? bytes,
    required String fileName,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final attachmentsDir =
          Directory('${docsDir.path}${Platform.pathSeparator}keep_in_mind_attachments');
      if (!await attachmentsDir.exists()) {
        await attachmentsDir.create(recursive: true);
      }

      final sanitized = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath =
          '${attachmentsDir.path}${Platform.pathSeparator}${timestamp}_$sanitized';

      if (sourcePath != null && sourcePath.isNotEmpty) {
        final srcFile = File(sourcePath);
        if (await srcFile.exists()) {
          // Skip copy if already safely inside an attachments directory
          if (await isSafeAttachmentPath(sourcePath)) {
            return sourcePath;
          }
          final copied = await srcFile.copy(destPath);
          return copied.path;
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final destFile = File(destPath);
        await destFile.writeAsBytes(bytes, flush: true);
        return destFile.path;
      }
    } catch (_) {
      return sourcePath;
    }
    return sourcePath;
  }

  /// Returns local file size in bytes, or null if unavailable.
  static Future<int?> getFileSize(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return null;
  }

  /// Verifies that [path] resides strictly inside an allowed app attachments directory
  /// and does not contain path traversal (e.g. '..').
  static Future<bool> isSafeAttachmentPath(String? path) async {
    if (path == null || path.trim().isEmpty) return false;
    final trimmed = path.trim();
    if (trimmed.contains('..')) return false;
    try {
      final file = File(trimmed);
      if (!await file.exists()) return false;
      final fileCanonical = file.resolveSymbolicLinksSync().toLowerCase();

      final docsDir = await getApplicationDocumentsDirectory();
      final docsAttach = Directory(
        '${docsDir.path}${Platform.pathSeparator}keep_in_mind_attachments',
      );
      if (await docsAttach.exists()) {
        final docsCanonical = '${docsAttach.resolveSymbolicLinksSync().toLowerCase()}${Platform.pathSeparator}';
        if (fileCanonical.startsWith(docsCanonical)) return true;
      }

      // Check application support directory (filesDir on Android)
      final supportDir = await getApplicationSupportDirectory();
      final supportAttach = Directory(
        '${supportDir.path}${Platform.pathSeparator}keep_in_mind_attachments',
      );
      if (await supportAttach.exists()) {
        final supportCanonical = '${supportAttach.resolveSymbolicLinksSync().toLowerCase()}${Platform.pathSeparator}';
        if (fileCanonical.startsWith(supportCanonical)) return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a local attachment file only if it is safely located within the app attachments directory.
  static Future<void> deleteLocalFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final isSafe = await isSafeAttachmentPath(path);
      if (!isSafe) return;
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Reads up to [maxChars] from a local text file for preview.
  static Future<String?> readTextFilePreview(String? path, {int maxChars = 2000}) async {
    if (path == null || path.isEmpty) return null;
    try {
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.length <= maxChars) return content;
        return '${content.substring(0, maxChars)}\n…';
      }
    } catch (_) {}
    return null;
  }

  /// Builds an image widget from a local file path or base64 data.
  static Widget buildLocalImage({
    String? filePath,
    String? base64Data,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    if (base64Data != null && base64Data.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => _brokenImagePlaceholder(width, height),
        );
      } catch (_) {}
    }

    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => _brokenImagePlaceholder(width, height),
        );
      }
    }

    return _brokenImagePlaceholder(width, height);
  }

  static Widget _brokenImagePlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }
}
