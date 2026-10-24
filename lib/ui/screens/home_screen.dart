import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/memory_item.dart';
import '../../services/share_intent_service.dart';
import '../../services/storage_service.dart';
import '../widgets/add_memory_sheet.dart';
import '../widgets/home_widget_preview.dart';
import '../widgets/memory_item_card.dart';
import 'item_detail_screen.dart';
import 'widget_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  final ShareIntentService shareService;

  const HomeScreen({
    super.key,
    required this.storage,
    required this.shareService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<SharedIncomingPayload>? _shareSub;
  bool _showWidgetBanner = true;

  @override
  void initState() {
    super.initState();
    _shareSub = widget.shareService.incomingStream.listen(_onIncomingPayload);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onIncomingPayload(SharedIncomingPayload payload) async {
    // 1. Se proviene da un tap sul pulsante "+" del Widget Home Screen
    if (payload.quickAddRequested) {
      if (mounted) _openAddSheet();
      return;
    }

    // 2. Se proviene da un tap su uno degli ultimi 1-5 elementi del Widget Home Screen
    if (payload.openItemId != null && payload.openItemId!.isNotEmpty) {
      final target = widget.storage.getById(payload.openItemId!);
      if (target != null && mounted) {
        _openDetail(target);
      }
      return;
    }

    // 3. Se proviene da "Share to Self" (Condividi dal Sistema Operativo)
    if (payload.hasSharedContent) {
      final saved = await widget.storage.addSharedOrManualItem(
        rawText: payload.text,
        rawSubject: payload.subject,
        filePath: payload.filePath,
        fileName: payload.fileName,
        mimeType: payload.mimeType,
        fileSizeBytes: payload.fileSizeBytes,
        source: payload.source,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Salvato in Keep in Mind (${saved.type.label}): "${saved.title}"',
            ),
            action: SnackBarAction(
              label: 'Apri',
              onPressed: () => _openDetail(saved),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openAddSheet({String? initialText}) async {
    final created = await showModalBottomSheet<MemoryItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddMemorySheet(
        storage: widget.storage,
        initialText: initialText,
      ),
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Salvato in locale: "${created.title}"'),
        ),
      );
    }
  }

  void _openDetail(MemoryItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          item: item,
          storage: widget.storage,
        ),
      ),
    );
  }

  void _openWidgetSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WidgetSettingsScreen(storage: widget.storage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainScaffold(context);
  }

  Widget _buildMainScaffold(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.storage,
      builder: (context, _) {
        final items = widget.storage.filteredItems;
        final widgetItems = widget.storage.widgetItems;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.psychology_alt_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Keep in Mind',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Locale',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: () {
                  setState(() => _showWidgetBanner = !_showWidgetBanner);
                },
                icon: Icon(
                  _showWidgetBanner
                      ? Icons.widgets_rounded
                      : Icons.widgets_outlined,
                ),
                tooltip: 'Mostra/Nascondi Widget (1-5)',
              ),
              IconButton(
                onPressed: _openWidgetSettings,
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Impostazioni Widget (1-5) & Backup Locale',
              ),
              PopupMenuButton<String>(
                tooltip: 'Simula Share to Self',
                icon: const Icon(Icons.ios_share_rounded),
                onSelected: _handleSimulateMenu,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'sim_link',
                    child: ListTile(
                      leading: Icon(Icons.link_rounded),
                      title: Text('Simula Share Link dal Browser'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sim_note',
                    child: ListTile(
                      leading: Icon(Icons.notes_rounded),
                      title: Text('Simula Share Testo/Appunto'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showWidgetBanner) ...[
                        HomeWidgetPreview(
                          items: widgetItems,
                          config: widget.storage.widgetConfig,
                          totalCount: widget.storage.allItems.length,
                          onItemTap: _openDetail,
                          onQuickAddTap: () => _openAddSheet(),
                          onConfigureTap: _openWidgetSettings,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildSearchAndFilters(scheme),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(scheme),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return MemoryItemCard(
                        item: item,
                        onTap: () => _openDetail(item),
                        onTogglePin: () => widget.storage.togglePin(item.id),
                        onDelete: () => widget.storage.deleteItem(item.id),
                        onTagTap: (tag) => widget.storage.setTagFilter(tag),
                      );
                    },
                  ),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddSheet(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Keep in Mind'),
          ),
        );
      },
    );
  }

  void _handleSimulateMenu(String value) {
    if (value == 'sim_link') {
      widget.shareService.simulateIncomingShare(
        const SharedIncomingPayload(
          subject: 'Articolo approfondimento Flutter Local-First',
          text:
              'Articolo approfondimento Flutter Local-First https://docs.flutter.dev/platform-integration/android/install-app',
          source: 'Share to Self (Simulato)',
        ),
      );
    } else if (value == 'sim_note') {
      widget.shareService.simulateIncomingShare(
        const SharedIncomingPayload(
          subject: 'Idea progetto Keep in Mind',
          text:
              'Ricordarsi di testare il widget sulla schermata Home con gli ultimi 1-5 contenuti salvati.',
          source: 'Share to Self (Simulato)',
        ),
      );
    }
  }

  Widget _buildSearchAndFilters(ColorScheme scheme) {
    final selectedType = widget.storage.selectedTypeFilter;
    final selectedTag = widget.storage.selectedTagFilter;
    final onlyPinned = widget.storage.onlyPinnedFilter;
    final tags = widget.storage.availableTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          onChanged: widget.storage.setSearchQuery,
          decoration: InputDecoration(
            hintText: 'Cerca nella tua memoria locale (titolo, link, #tag)...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      widget.storage.setSearchQuery('');
                    },
                    icon: const Icon(Icons.clear_rounded),
                  )
                : null,
            filled: true,
            fillColor: scheme.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tutti'),
                selected: selectedType == null && !onlyPinned && selectedTag == null,
                onSelected: (_) => widget.storage.resetFilters(),
              ),
              const SizedBox(width: 8),
              FilterChip(
                avatar: const Icon(Icons.push_pin_rounded, size: 15),
                label: const Text('Fissati'),
                selected: onlyPinned,
                onSelected: (v) => widget.storage.setOnlyPinnedFilter(v),
              ),
              const SizedBox(width: 8),
              ...MemoryItemType.values.map((t) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(t.label),
                    selected: selectedType == t,
                    onSelected: (v) =>
                        widget.storage.setTypeFilter(v ? t : null),
                  ),
                );
              }),
            ],
          ),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: tags.map((tag) {
                final isSelected = selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    backgroundColor:
                        isSelected ? scheme.primaryContainer : null,
                    label: Text(
                      '#$tag',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    onPressed: () {
                      widget.storage
                          .setTagFilter(isSelected ? null : tag);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 56,
              color: scheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Nessun contenuto trovato',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Condividi qualsiasi link, testo, immagine o file dal tuo sistema operativo scegliendo "Keep in Mind", oppure premi il pulsante + qui sotto.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
