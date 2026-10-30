import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/memory_item.dart';
import '../utils/local_file_helper.dart';
import '../utils/tag_helper.dart';
import 'widget_sync_service.dart';

class StorageService extends ChangeNotifier {
  static const String _itemsStorageKey = 'kim_memory_items_v1';
  static const String _widgetConfigKey = 'kim_widget_config_v1';
  static const String _seededKey = 'kim_initial_seed_v1';
  static const String _confirmDeleteKey = 'kim_confirm_delete_v1';
  static const String _customTagsKey = 'kim_custom_tags_v1';

  final Uuid _uuid = const Uuid();
  SharedPreferences? _prefs;

  List<MemoryItem> _items = [];
  final Set<String> _customTags = {};
  WidgetConfig _widgetConfig = const WidgetConfig(
    maxItems: 3,
    prioritizePinned: true,
    showTags: true,
  );

  String _searchQuery = '';
  MemoryItemType? _selectedTypeFilter;
  String? _selectedTagFilter;
  bool _onlyPinnedFilter = false;
  bool _confirmBeforeDelete = true;
  bool _isLoaded = false;

  List<MemoryItem> get allItems => List.unmodifiable(_items);
  WidgetConfig get widgetConfig => _widgetConfig;
  String get searchQuery => _searchQuery;
  MemoryItemType? get selectedTypeFilter => _selectedTypeFilter;
  String? get selectedTagFilter => _selectedTagFilter;
  bool get onlyPinnedFilter => _onlyPinnedFilter;
  bool get confirmBeforeDelete => _confirmBeforeDelete;
  bool get isLoaded => _isLoaded;

  /// Items selected for the home screen widget.
  List<MemoryItem> get widgetItems =>
      WidgetSyncService.selectWidgetItems(_items, _widgetConfig);

  static const List<String> defaultTags = [
    'immagine',
    'nota',
    'link',
    'audio',
    'file',
  ];
  static const Set<String> _deprecatedSeedTags = {'privacy', 'locale', 'guida'};

  /// All unique tags in the local library, including defaults.
  List<String> get availableTags {
    final tagSet = <String>{...defaultTags, ..._customTags};
    for (final item in _items) {
      for (final tag in item.tags) {
        if (!_deprecatedSeedTags.contains(tag)) {
          tagSet.add(tag);
        }
      }
    }
    return tagSet.toList();
  }

  /// Filtered and sorted items for the main feed.
  List<MemoryItem> get filteredItems {
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _items.where((item) {
      if (_onlyPinnedFilter && !item.isPinned) return false;
      if (_selectedTypeFilter != null && item.type != _selectedTypeFilter) {
        return false;
      }
      if (_selectedTagFilter != null &&
          !TagVisuals.itemHasTag(item, _selectedTagFilter!)) {
        return false;
      }
      if (q.isNotEmpty) {
        final cleanQ = q.startsWith('#') ? q.substring(1) : q;
        final inTitle = item.title.toLowerCase().contains(cleanQ);
        final inContent = item.content.toLowerCase().contains(cleanQ);
        final inDomain = (item.domain ?? '').toLowerCase().contains(cleanQ);
        final inFile = (item.fileName ?? '').toLowerCase().contains(cleanQ);
        final inTags = TagVisuals.effectiveTagsForItem(item)
            .any((t) => t.toLowerCase().contains(cleanQ));
        return inTitle || inContent || inDomain || inFile || inTags;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  Future<void> init({bool seedIfFirstRun = true}) async {
    _prefs = await SharedPreferences.getInstance();
    _loadFromPrefs(seedIfFirstRun: seedIfFirstRun);
    _isLoaded = true;
    notifyListeners();
    unawaited(
      WidgetSyncService.syncWidget(
        allItems: _items,
        config: _widgetConfig,
      ),
    );
  }

  /// Reloads items from disk to sync background changes.
  Future<void> reloadFromDisk() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.reload();
    _loadFromPrefs(seedIfFirstRun: false);
    notifyListeners();
    unawaited(
      WidgetSyncService.syncWidget(
        allItems: _items,
        config: _widgetConfig,
      ),
    );
  }

  void _loadFromPrefs({required bool seedIfFirstRun}) {
    final prefs = _prefs;
    if (prefs == null) return;

    _confirmBeforeDelete = prefs.getBool(_confirmDeleteKey) ?? true;

    final rawCustomTags = prefs.getStringList(_customTagsKey);
    if (rawCustomTags != null) {
      _customTags.clear();
      for (final t in rawCustomTags) {
        final clean = t.trim().toLowerCase();
        if (clean.isNotEmpty && !_deprecatedSeedTags.contains(clean)) {
          _customTags.add(clean);
        }
      }
    }

    final rawConfig = prefs.getString(_widgetConfigKey);
    if (rawConfig != null && rawConfig.isNotEmpty) {
      try {
        _widgetConfig = WidgetConfig.fromJson(
          jsonDecode(rawConfig) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    final rawItems = prefs.getString(_itemsStorageKey);
    if (rawItems != null && rawItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems) as List<dynamic>;
        bool hadDeprecatedTags = false;
        _items = decoded.map((e) {
          final item = MemoryItem.fromJson(e as Map<String, dynamic>);
          if (item.tags.any(_deprecatedSeedTags.contains)) {
            hadDeprecatedTags = true;
            return item.copyWith(
              tags: item.tags
                  .where((t) => !_deprecatedSeedTags.contains(t))
                  .toList(),
            );
          }
          return item;
        }).toList();
        if (hadDeprecatedTags) {
          _saveItemsToPrefs();
        }
      } catch (_) {
        _items = [];
      }
    } else if (seedIfFirstRun && !(prefs.getBool(_seededKey) ?? false)) {
      _items = _createWelcomeItems();
      prefs.setBool(_seededKey, true);
      _saveItemsToPrefs();
    }
  }

  Future<void> _saveItemsToPrefs() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_itemsStorageKey, encoded);
    await prefs.setStringList(_customTagsKey, _customTags.toList());
    unawaited(
      WidgetSyncService.syncWidget(
        allItems: _items,
        config: _widgetConfig,
      ),
    );
  }

  Future<MemoryItem> addSharedOrManualItem({
    String? rawText,
    String? rawSubject,
    String? filePath,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    Uint8List? fileBytes,
    String? base64Data,
    List<String>? customTags,
    bool isPinned = false,
    String source = 'Share to Self',
  }) async {
    String? persistedPath = filePath;
    int? resolvedSize = fileSizeBytes;
    String? resolvedBase64 = base64Data;

    final effectiveName = fileName ??
        (filePath != null ? filePath.split(RegExp(r'[/\\]')).last : 'allegato');

    if ((filePath != null && filePath.isNotEmpty) ||
        (fileBytes != null && fileBytes.isNotEmpty)) {
      persistedPath = await LocalFileHelper.persistFileLocally(
        sourcePath: filePath,
        bytes: fileBytes,
        fileName: effectiveName,
      );
      resolvedSize ??=
          fileBytes?.length ?? await LocalFileHelper.getFileSize(persistedPath);

      if (resolvedBase64 == null &&
          fileBytes != null &&
          fileBytes.length <= 1500 * 1024) {
        resolvedBase64 = base64Encode(fileBytes);
      }
    }

    final item = MemoryItem.fromSharedPayload(
      id: _uuid.v4(),
      rawText: rawText,
      rawSubject: rawSubject,
      filePath: persistedPath,
      fileName: fileName,
      mimeType: mimeType,
      fileSizeBytes: resolvedSize,
      base64Data: resolvedBase64,
      customTags: customTags,
      isPinned: isPinned,
      source: source,
    );

    _items.insert(0, item);
    notifyListeners();
    await _saveItemsToPrefs();
    return item;
  }

  Future<void> updateItem(MemoryItem updated) async {
    final index = _items.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;
    final previous = _items[index];
    if (previous.filePath != null &&
        previous.filePath!.isNotEmpty &&
        updated.filePath == null) {
      await LocalFileHelper.deleteLocalFile(previous.filePath);
    }
    _items[index] = updated;
    notifyListeners();
    await _saveItemsToPrefs();
  }

  Future<void> setConfirmBeforeDelete(bool value) async {
    if (_confirmBeforeDelete == value) return;
    _confirmBeforeDelete = value;
    notifyListeners();
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setBool(_confirmDeleteKey, value);
    }
  }

  Future<void> togglePin(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final current = _items[index];
    _items[index] = current.copyWith(isPinned: !current.isPinned);
    notifyListeners();
    await _saveItemsToPrefs();
  }

  Future<void> deleteItem(String id) async {
    final index = _items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final removed = _items.removeAt(index);
    notifyListeners();
    if (removed.filePath != null) {
      await LocalFileHelper.deleteLocalFile(removed.filePath);
    }
    await _saveItemsToPrefs();
  }

  Future<void> clearAllItems() async {
    for (final item in _items) {
      if (item.filePath != null) {
        await LocalFileHelper.deleteLocalFile(item.filePath);
      }
    }
    _items.clear();
    notifyListeners();
    await _saveItemsToPrefs();
  }

  MemoryItem? getById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> updateWidgetConfig(WidgetConfig newConfig) async {
    _widgetConfig = newConfig;
    notifyListeners();
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.setString(_widgetConfigKey, newConfig.toJsonString());
    }
    unawaited(
      WidgetSyncService.syncWidget(
        allItems: _items,
        config: _widgetConfig,
      ),
    );
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setTypeFilter(MemoryItemType? type) {
    _selectedTypeFilter = type;
    notifyListeners();
  }

  void setTagFilter(String? tag) {
    _selectedTagFilter = tag;
    notifyListeners();
  }

  void setOnlyPinnedFilter(bool value) {
    _onlyPinnedFilter = value;
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedTypeFilter = null;
    _selectedTagFilter = null;
    _onlyPinnedFilter = false;
    notifyListeners();
  }

  String exportBackupJson() {
    final payload = {
      'app': 'Keep in Mind',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'widgetConfig': _widgetConfig.toJson(),
      'customTags': _customTags.toList(),
      'items': _items.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<Map<String, int>> importBackupJson(String jsonString) async {
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    final rawList = decoded['items'] as List<dynamic>? ?? const [];
    final rawCustomTags = decoded['customTags'] as List<dynamic>? ?? const [];

    int addedCount = 0;
    int mergedTagsCount = 0;
    int skippedDuplicates = 0;

    for (final t in rawCustomTags) {
      final clean = t.toString().trim().toLowerCase();
      if (clean.isNotEmpty &&
          !defaultTags.contains(clean) &&
          !_deprecatedSeedTags.contains(clean)) {
        if (_customTags.add(clean)) {
          mergedTagsCount++;
        }
      }
    }

    for (final raw in rawList) {
      if (raw is Map<String, dynamic>) {
        final importedItem = MemoryItem.fromJson(raw);
        if (importedItem.id.isEmpty && importedItem.title.isEmpty) continue;

        // Sanitize imported tags
        final cleanTags = importedItem.tags
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty && !_deprecatedSeedTags.contains(e))
            .toList();

        for (final tag in cleanTags) {
          if (!defaultTags.contains(tag) && _customTags.add(tag)) {
            mergedTagsCount++;
          }
        }

        final fixedItem = importedItem.id.isEmpty
            ? importedItem.copyWith(id: _uuid.v4(), tags: cleanTags)
            : importedItem.copyWith(tags: cleanTags);

        // Match duplicates by ID, URL, or title and content
        final existingIndex = _items.indexWhere((existing) {
          if (existing.id == fixedItem.id) return true;
          if (existing.type == fixedItem.type) {
            if (existing.url != null &&
                fixedItem.url != null &&
                existing.url!.trim().isNotEmpty &&
                existing.url!.trim() == fixedItem.url!.trim()) {
              return true;
            }
            if (existing.title.trim().toLowerCase() ==
                    fixedItem.title.trim().toLowerCase() &&
                existing.content.trim() == fixedItem.content.trim()) {
              return true;
            }
          }
          return false;
        });

        if (existingIndex != -1) {
          // Merge new tags into existing duplicate
          final current = _items[existingIndex];
          final mergedTags = {...current.tags, ...fixedItem.tags}.toList();
          if (mergedTags.length > current.tags.length) {
            _items[existingIndex] = current.copyWith(tags: mergedTags);
            mergedTagsCount++;
          }
          skippedDuplicates++;
        } else {
          _items.insert(0, fixedItem);
          addedCount++;
        }
      }
    }

    if (addedCount > 0 || mergedTagsCount > 0) {
      _items.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      notifyListeners();
      await _saveItemsToPrefs();
    }

    return {
      'addedCount': addedCount,
      'mergedTagsCount': mergedTagsCount,
      'skippedDuplicates': skippedDuplicates,
    };
  }

  List<MemoryItem> _createWelcomeItems() {
    final now = DateTime.now();
    return [
      MemoryItem(
        id: _uuid.v4(),
        type: MemoryItemType.link,
        title: 'Benvenuto in Keep in Mind — Guida Share to Self',
        content:
            'Usa il menu "Condividi" di qualsiasi app (Browser, YouTube, Foto, File Manager) e scegli "Keep in Mind" per salvare link, testi, immagini o file direttamente in locale.\nhttps://flutter.dev',
        url: 'https://flutter.dev',
        domain: 'flutter.dev',
        tags: const ['link'],
        isPinned: true,
        createdAt: now.subtract(const Duration(minutes: 5)),
        source: 'Sistema Locale',
      ),
      MemoryItem(
        id: _uuid.v4(),
        type: MemoryItemType.text,
        title: '100% Locale & Zero Cloud',
        content:
            'Tutti i tuoi link, appunti, immagini e documenti restano esclusivamente nella memoria privata del tuo dispositivo. Nessun account, nessun server esterno, massima privacy.',
        tags: const ['nota'],
        isPinned: false,
        createdAt: now.subtract(const Duration(minutes: 15)),
        source: 'Sistema Locale',
      ),
    ];
  }
}
