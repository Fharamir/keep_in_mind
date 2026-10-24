import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class LocalFileHelper {
  static Future<String?> persistFileLocally({
    String? sourcePath,
    Uint8List? bytes,
    required String fileName,
  }) async {
    return sourcePath ?? fileName;
  }

  static Future<int?> getFileSize(String? path) async {
    return null;
  }

  static Future<void> deleteLocalFile(String? path) async {}

  static Future<String?> readTextFilePreview(String? path, {int maxChars = 2000}) async {
    return null;
  }

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

    return _brokenImagePlaceholder(width, height);
  }

  static Widget _brokenImagePlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );
  }
}
