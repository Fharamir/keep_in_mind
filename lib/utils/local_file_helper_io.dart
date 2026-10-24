import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class LocalFileHelper {
  /// Copia un file dalla cache temporanea del sistema operativo nella memoria
  /// privata permanente dell'app (`keep_in_mind_attachments`).
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
          // Se è già nella cartella attachments, non duplicarlo
          if (sourcePath.contains('keep_in_mind_attachments')) {
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

  /// Legge la dimensione in byte di un file locale se presente.
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

  /// Elimina un file allegato dalla memoria locale dell'app.
  static Future<void> deleteLocalFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Legge il contenuto testuale di un file locale (per anteprima di .txt, .md, .json, ecc.)
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

  /// Restituisce un Widget immagine a partire da percorso locale o base64.
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
