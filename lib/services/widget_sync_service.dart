import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/memory_item.dart';

class WidgetSyncService {
  static const MethodChannel _channel =
      MethodChannel('com.example.keep_in_mind/widget');

  /// Seleziona gli ultimi 1-5 contenuti da mostrare nel Widget in base a [config].
  static List<MemoryItem> selectWidgetItems(
    List<MemoryItem> allItems,
    WidgetConfig config,
  ) {
    final limit = config.maxItems.clamp(1, 5);
    Iterable<MemoryItem> filtered = allItems;

    if (config.filterType != null) {
      filtered = filtered.where((item) => item.type == config.filterType);
    }

    final list = filtered.toList();
    list.sort((a, b) {
      if (config.prioritizePinned && a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return list.take(limit).toList();
  }

  /// Sincronizza i dati con il Widget nativo Android (AppWidgetProvider)
  /// e iOS (App Group UserDefaults per WidgetKit).
  static Future<void> syncWidget({
    required List<MemoryItem> allItems,
    required WidgetConfig config,
  }) async {
    if (kIsWeb) return;

    final widgetItems = selectWidgetItems(allItems, config);
    final payload = {
      'maxItems': config.maxItems.clamp(1, 5),
      'prioritizePinned': config.prioritizePinned,
      'filterType': config.filterType?.name,
      'showTags': config.showTags,
      'totalCount': allItems.length,
      'updatedAt': DateTime.now().toIso8601String(),
      'items': widgetItems
          .map(
            (e) => {
              'id': e.id,
              'type': e.type.name,
              'typeLabel': e.type.label,
              'title': e.title,
              'subtitle': e.domain ??
                  e.fileName ??
                  (e.content.length > 70
                      ? '${e.content.substring(0, 70)}…'
                      : e.content),
              'isPinned': e.isPinned,
              'tags': e.tags.take(2).join(' · '),
              'createdAt': e.createdAt.toIso8601String(),
            },
          )
          .toList(),
    };

    try {
      await _channel.invokeMethod('updateWidget', {
        'payloadJson': jsonEncode(payload),
      });
    } catch (_) {
      // Ignorato su piattaforme desktop o durante i test unitari
    }
  }
}
