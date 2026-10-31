import 'package:flutter/material.dart';
import '../models/memory_item.dart';

class TagVisuals {
  static String formatLabel(String tag) {
    final clean = tag.trim().toLowerCase();
    switch (clean) {
      case 'link':
        return 'Link';
      case 'nota':
      case 'text':
        return 'Nota';
      case 'immagine':
      case 'image':
        return 'Immagine';
      case 'audio':
        return 'Audio';
      case 'file':
        return 'File';
      default:
        if (clean.isEmpty) return '';
        return clean[0].toUpperCase() + clean.substring(1);
    }
  }

  static IconData iconForTag(String tag) {
    switch (tag.trim().toLowerCase()) {
      case 'link':
        return Icons.link_rounded;
      case 'nota':
      case 'text':
        return Icons.notes_rounded;
      case 'immagine':
      case 'image':
        return Icons.image_outlined;
      case 'audio':
        return Icons.mic_rounded;
      case 'file':
        return Icons.insert_drive_file_outlined;
      default:
        return Icons.label_outline_rounded;
    }
  }

  static Color colorForTag(String tag) {
    switch (tag.trim().toLowerCase()) {
      case 'link':
        return Colors.blueAccent;
      case 'nota':
      case 'text':
        return Colors.amber.shade700;
      case 'immagine':
      case 'image':
        return Colors.purpleAccent;
      case 'audio':
        return Colors.deepOrangeAccent;
      case 'file':
        return Colors.teal;
      default:
        return Colors.indigoAccent;
    }
  }

  static String defaultTagForItem(MemoryItem item) {
    final mime = (item.mimeType ?? '').toLowerCase();
    if (mime.startsWith('audio/')) return 'audio';
    switch (item.type) {
      case MemoryItemType.link:
        return 'link';
      case MemoryItemType.text:
        return 'nota';
      case MemoryItemType.image:
        return 'immagine';
      case MemoryItemType.file:
        return 'file';
    }
  }

  static List<String> effectiveTagsForItem(MemoryItem item) {
    if (item.tags.isNotEmpty) return item.tags;
    return [defaultTagForItem(item)];
  }

  static bool itemHasTag(MemoryItem item, String tag) {
    final target = tag.trim().toLowerCase();
    final effective =
        effectiveTagsForItem(item).map((e) => e.trim().toLowerCase());
    if (effective.contains(target)) return true;
    if (defaultTagForItem(item) == target) return true;
    return false;
  }
}
