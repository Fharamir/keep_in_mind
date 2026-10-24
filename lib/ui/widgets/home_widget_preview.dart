import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/memory_item.dart';

class HomeWidgetPreview extends StatelessWidget {
  final List<MemoryItem> items;
  final WidgetConfig config;
  final int totalCount;
  final ValueChanged<MemoryItem>? onItemTap;
  final VoidCallback? onQuickAddTap;
  final VoidCallback? onConfigureTap;

  const HomeWidgetPreview({
    super.key,
    required this.items,
    required this.config,
    required this.totalCount,
    this.onItemTap,
    this.onQuickAddTap,
    this.onConfigureTap,
  });

  IconData _iconForType(MemoryItemType type) {
    switch (type) {
      case MemoryItemType.link:
        return Icons.link_rounded;
      case MemoryItemType.text:
        return Icons.notes_rounded;
      case MemoryItemType.image:
        return Icons.image_outlined;
      case MemoryItemType.file:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _colorForType(MemoryItemType type) {
    switch (type) {
      case MemoryItemType.link:
        return Colors.blueAccent;
      case MemoryItemType.text:
        return Colors.amber.shade700;
      case MemoryItemType.image:
        return Colors.purpleAccent;
      case MemoryItemType.file:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd/MM HH:mm');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.surfaceContainerHighest, scheme.surfaceContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context, scheme),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Nessun elemento nel widget.\nCondividi un link, testo o file con Keep in Mind!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            )
          else
            ...items.asMap().entries.map(
                  (entry) => _buildRow(
                    context,
                    scheme,
                    entry.value,
                    entry.key == items.length - 1,
                    dateFmt,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.psychology_alt_rounded,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Keep in Mind',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ultimi ${items.length}/${config.maxItems}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                'Memoria locale · $totalCount salvati',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        if (onConfigureTap != null)
          IconButton(
            onPressed: onConfigureTap,
            icon: const Icon(Icons.tune_rounded, size: 18),
            tooltip: 'Configura Widget (1-5)',
            visualDensity: VisualDensity.compact,
          ),
        if (onQuickAddTap != null)
          FilledButton.tonalIcon(
            onPressed: onQuickAddTap,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Salva', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    ColorScheme scheme,
    MemoryItem item,
    bool isLast,
    DateFormat dateFmt,
  ) {
    final accent = _colorForType(item.type);
    final subtitle = item.domain ??
        item.fileName ??
        (item.content.replaceAll('\n', ' ').trim());

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onItemTap != null ? () => onItemTap!(item) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconForType(item.type), size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.isPinned)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 12,
                              color: scheme.primary,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (config.showTags && item.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.tags.take(3).map((t) => '#$t').join(' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateFmt.format(item.createdAt),
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
