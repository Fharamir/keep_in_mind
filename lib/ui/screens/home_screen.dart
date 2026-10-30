import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/memory_item.dart';
import '../../services/share_intent_service.dart';
import '../../services/storage_service.dart';
import '../../utils/tag_helper.dart';
import '../widgets/add_memory_sheet.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<SharedIncomingPayload>? _shareSub;
  int _selectedNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareSub = widget.shareService.incomingStream.listen(_onIncomingPayload);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.storage.reloadFromDisk();
    }
  }

  Future<void> _onIncomingPayload(SharedIncomingPayload payload) async {
    // Quick-add action from widget
    if (payload.quickAddRequested) {
      if (mounted) _openAddSheet();
      return;
    }

    // Open specific item from widget
    if (payload.openItemId != null && payload.openItemId!.isNotEmpty) {
      await widget.storage.reloadFromDisk();
      final target = widget.storage.getById(payload.openItemId!);
      if (target != null && mounted) {
        _openDetail(target, openedFromWidget: true);
      }
      return;
    }

    // Save incoming shared content
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
          content: Text('Salvato: "${created.title}"'),
        ),
      );
    }
  }

  void _openDetail(MemoryItem item, {bool openedFromWidget = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(
          item: item,
          storage: widget.storage,
          openedFromWidget: openedFromWidget,
        ),
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
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo.png',
                    width: 28,
                    height: 28,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.psychology_alt_rounded,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
          ),
          body: IndexedStack(
            index: _selectedNavIndex,
            children: [
              _buildMemoriesView(scheme),
              WidgetConfigView(
                storage: widget.storage,
                onQuickAddTap: () => _openAddSheet(),
                onViewAllTap: () => setState(() => _selectedNavIndex = 0),
              ),
              AppAndExportView(
                storage: widget.storage,
                shareService: widget.shareService,
              ),
            ],
          ),
          floatingActionButton: _selectedNavIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: () => _openAddSheet(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Aggiungi'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedNavIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedNavIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'Contenuti',
              ),
              NavigationDestination(
                icon: Icon(Icons.widgets_outlined),
                selectedIcon: Icon(Icons.widgets_rounded),
                label: 'Widget',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'App & Esporta',
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildMemoriesView(ColorScheme scheme) {
    final items = widget.storage.filteredItems;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _buildSearchAndFilters(scheme),
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
                  onDelete: () => ItemDetailScreen.confirmAndDelete(
                    context,
                    widget.storage,
                    item,
                  ),
                  onTagTap: (tag) => widget.storage.setTagFilter(tag),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchAndFilters(ColorScheme scheme) {
    final selectedType = widget.storage.selectedTypeFilter;
    final selectedTag = widget.storage.selectedTagFilter;
    final onlyPinned = widget.storage.onlyPinnedFilter;
    final tags = widget.storage.availableTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          elevation: 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          color: scheme.surfaceContainerHigh,
          child: TextField(
            controller: _searchController,
            onChanged: widget.storage.setSearchQuery,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Cerca nei contenuti salvati (titolo, link, #tag)...',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 24,
                color: scheme.primary,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        widget.storage.setSearchQuery('');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.25),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: scheme.primary,
                  width: 1.8,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tutti'),
                selected: selectedType == null &&
                    !onlyPinned &&
                    selectedTag == null,
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
              ...tags.map((tag) {
                final isSelected = selectedTag == tag;
                final color = TagVisuals.colorForTag(tag);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      TagVisuals.iconForTag(tag),
                      size: 16,
                      color: color,
                    ),
                    label: Text(
                      TagVisuals.formatLabel(tag),
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? color : null,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: color.withValues(alpha: 0.18),
                    checkmarkColor: color,
                    side: BorderSide(
                      color: isSelected
                          ? color
                          : scheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                    onSelected: (v) {
                      widget.storage.setTypeFilter(null);
                      widget.storage.setTagFilter(v ? tag : null);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
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
