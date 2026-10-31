import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/memory_item.dart';
import '../utils/tag_helper.dart';

class WidgetSyncService {
  static const MethodChannel _channel =
      MethodChannel('dev.fharamir.keepinmind/widget');

  /// Selects up to 5 items for the widget based on [config].
  static List<MemoryItem> selectWidgetItems(
    List<MemoryItem> allItems,
    WidgetConfig config,
  ) {
    final limit = config.maxItems.clamp(1, 5);
    Iterable<MemoryItem> filtered = allItems;

    if (config.filterTag != null && config.filterTag!.isNotEmpty) {
      filtered = filtered.where(
        (item) => TagVisuals.itemHasTag(item, config.filterTag!),
      );
    } else if (config.filterType != null) {
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

  /// Syncs widget payload with native home screen widgets.
  static Future<void> syncWidget({
    required List<MemoryItem> allItems,
    required WidgetConfig config,
    AppLocalizations? l10n,
  }) async {
    if (kIsWeb) return;

    final widgetItems = selectWidgetItems(allItems, config);
    final countLabel = l10n != null
        ? l10n.widgetLatestCount(widgetItems.length, config.maxItems)
        : 'Ultimi ${widgetItems.length}/${config.maxItems}';
    final subtitleLabel = l10n != null
        ? l10n.widgetLocalMemorySubtitle(allItems.length)
        : 'Memoria locale · ${allItems.length} salvati';
    final addBtnLabel = l10n?.widgetQuickAdd ?? '+ Salva';
    final viewAllBtnLabel = l10n?.widgetViewAll ?? 'Visualizza tutto →';
    final emptyLabel = l10n?.widgetEmptyMessage ??
        'Nessun elemento nel widget.\nCondividi un link, testo o file con Keep in Mind!';

    final payload = {
      'maxItems': config.maxItems.clamp(1, 5),
      'prioritizePinned': config.prioritizePinned,
      'filterType': config.filterType?.name,
      'showTags': config.showTags,
      'totalCount': allItems.length,
      'updatedAt': DateTime.now().toIso8601String(),
      'countLabel': countLabel,
      'subtitleLabel': subtitleLabel,
      'addBtnLabel': addBtnLabel,
      'viewAllBtnLabel': viewAllBtnLabel,
      'emptyLabel': emptyLabel,
      'items': widgetItems
          .map(
            (e) => {
              'id': e.id,
              'type': e.type.name,
              'typeLabel': l10n?.typeLabel(e.type.name) ?? e.type.label,
              'title': e.title,
              'subtitle': e.domain ??
                  e.fileName ??
                  (e.content.length > 70
                      ? '${e.content.substring(0, 70)}…'
                      : e.content),
              'filePath': e.filePath,
              'mimeType': e.mimeType,
              'isPinned': e.isPinned,
              'tags': TagVisuals.effectiveTagsForItem(e)
                  .take(3)
                  .map((t) => l10n?.tagLabel(t) ?? TagVisuals.formatLabel(t))
                  .join(' · '),
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
      // Ignored on unsupported platforms or during tests
    }
  }
}

