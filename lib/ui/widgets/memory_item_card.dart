import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/memory_item.dart';
import '../../utils/local_file_helper.dart';
import '../../utils/tag_helper.dart';

class MemoryItemCard extends StatelessWidget {
  final MemoryItem item;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final ValueChanged<String>? onTagTap;

  const MemoryItemCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    this.onTagTap,
  });

  Color _typeColor(MemoryItemType type) {
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

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile aprire il link: $url')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = _typeColor(item.type);
    final dateStr = DateFormat('dd/MM/yyyy · HH:mm').format(item.createdAt);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: item.isPinned
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: item.isPinned ? 1.4 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopRow(scheme, accent, dateStr),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              _buildMediaPreview(context, scheme, accent),
              if (item.content.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  item.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 10),
              _buildBottomActions(context, scheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(ColorScheme scheme, Color accent, String dateStr) {
    final effectiveTags = TagVisuals.effectiveTagsForItem(item);

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: effectiveTags.map((tag) {
                final tagColor = TagVisuals.colorForTag(tag);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onTagTap != null ? () => onTagTap!(tag) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            TagVisuals.iconForTag(tag),
                            size: 14,
                            color: tagColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            TagVisuals.formatLabel(tag),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: tagColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          dateStr,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onTogglePin,
          icon: Icon(
            item.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            size: 18,
            color: item.isPinned ? scheme.primary : scheme.onSurfaceVariant,
          ),
          tooltip: item.isPinned ? 'Rimuovi fissato' : 'Fissa in alto',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildMediaPreview(
    BuildContext context,
    ColorScheme scheme,
    Color accent,
  ) {
    if (item.type == MemoryItemType.image &&
        ((item.filePath != null && item.filePath!.isNotEmpty) ||
            (item.base64Data != null && item.base64Data!.isNotEmpty))) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: LocalFileHelper.buildLocalImage(
              filePath: item.filePath,
              base64Data: item.base64Data,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    if (item.type == MemoryItemType.file) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.description_outlined, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName ?? 'Documento allegato',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      [
                        if (item.mimeType != null) item.mimeType!,
                        if (item.formattedFileSize.isNotEmpty)
                          item.formattedFileSize,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildBottomActions(BuildContext context, ColorScheme scheme) {
    return Row(
      children: [
        if (item.domain != null && item.domain!.isNotEmpty)
          Expanded(
            child: Text(
              item.domain!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          )
        else
          const Spacer(),
        if (item.url != null && item.url!.isNotEmpty)
          IconButton(
            onPressed: () => _openUrl(context, item.url!),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            tooltip: 'Apri link',
            visualDensity: VisualDensity.compact,
          ),
        IconButton(
          onPressed: () {
            final copyText = item.url ?? item.content;
            Clipboard.setData(ClipboardData(text: copyText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copiato negli appunti'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          tooltip: 'Copia contenuto',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: () {
            final textToShare = item.content.isNotEmpty
                ? '${item.title}\n${item.content}'
                : item.title;
            SharePlus.instance.share(ShareParams(text: textToShare));
          },
          icon: const Icon(Icons.share_outlined, size: 18),
          tooltip: 'Ricondividi',
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          onPressed: onDelete,
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: scheme.error,
          ),
          tooltip: 'Elimina dalla memoria',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
