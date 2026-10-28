import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/memory_item.dart';
import '../../utils/local_file_helper.dart';
import '../../utils/tag_helper.dart';

class HomeWidgetPreview extends StatelessWidget {
  final List<MemoryItem> items;
  final WidgetConfig config;
  final int totalCount;
  final ValueChanged<MemoryItem>? onItemTap;
  final VoidCallback? onQuickAddTap;
  final VoidCallback? onConfigureTap;
  final VoidCallback? onViewAllTap;

  const HomeWidgetPreview({
    super.key,
    required this.items,
    required this.config,
    required this.totalCount,
    this.onItemTap,
    this.onQuickAddTap,
    this.onConfigureTap,
    this.onViewAllTap,
  });

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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onViewAllTap,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text(
                'Visualizza tutto',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/logo.png',
            width: 32,
            height: 32,
            errorBuilder: (_, _, _) => Container(
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
    final effectiveTags = TagVisuals.effectiveTagsForItem(item);
    final primaryTag = effectiveTags.first;
    final accent = TagVisuals.colorForTag(primaryTag);
    final subtitle = item.domain ??
        item.fileName ??
        (item.content.replaceAll('\n', ' ').trim());
    final hasImageThumb = item.type == MemoryItemType.image &&
        ((item.filePath != null && item.filePath!.isNotEmpty) ||
            (item.base64Data != null && item.base64Data!.isNotEmpty));

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onItemTap != null ? () => onItemTap!(item) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              if (hasImageThumb)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: LocalFileHelper.buildLocalImage(
                      filePath: item.filePath,
                      base64Data: item.base64Data,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    TagVisuals.iconForTag(primaryTag),
                    size: 18,
                    color: accent,
                  ),
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty && subtitle != item.title)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (effectiveTags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          effectiveTags
                              .take(3)
                              .map(TagVisuals.formatLabel)
                              .join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: accent,
                            fontWeight: FontWeight.w700,
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
