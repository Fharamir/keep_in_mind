import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/memory_item.dart';
import '../../services/storage_service.dart';
import '../../utils/local_file_helper.dart';

class ItemDetailScreen extends StatefulWidget {
  final MemoryItem item;
  final StorageService storage;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.storage,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late MemoryItem _current;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _tagsController;
  String? _textFilePreview;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    _titleController = TextEditingController(text: _current.title);
    _contentController = TextEditingController(text: _current.content);
    _tagsController = TextEditingController(text: _current.tags.join(', '));
    _loadFilePreviewIfNeeded();
  }

  Future<void> _loadFilePreviewIfNeeded() async {
    if (_current.type == MemoryItemType.file &&
        (_current.mimeType ?? '').startsWith('text/')) {
      final preview =
          await LocalFileHelper.readTextFilePreview(_current.filePath);
      if (mounted && preview != null) {
        setState(() => _textFilePreview = preview);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final tags = _tagsController.text
        .split(RegExp(r'[,;\s]+'))
        .map((e) => e.replaceAll('#', '').trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final newContent = _contentController.text.trim();
    final extractedUrl = MemoryItem.extractFirstUrl(newContent) ?? _current.url;
    final extractedDomain = extractedUrl != null
        ? MemoryItem.extractDomain(extractedUrl)
        : _current.domain;

    final updated = _current.copyWith(
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : _current.title,
      content: newContent,
      url: extractedUrl,
      domain: extractedDomain,
      tags: tags,
    );

    await widget.storage.updateItem(updated);
    if (mounted) {
      setState(() {
        _current = updated;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modifiche salvate in locale')),
      );
    }
  }

  Future<void> _togglePin() async {
    await widget.storage.togglePin(_current.id);
    final refreshed = widget.storage.getById(_current.id);
    if (refreshed != null && mounted) {
      setState(() => _current = refreshed);
    }
  }

  Future<void> _deleteItem() async {
    await widget.storage.deleteItem(_current.id);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateStr =
        DateFormat('dd/MM/yyyy · HH:mm:ss').format(_current.createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Text(_current.type.label),
        actions: [
          IconButton(
            onPressed: _togglePin,
            icon: Icon(
              _current.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: _current.isPinned ? scheme.primary : null,
            ),
            tooltip: _current.isPinned ? 'Rimuovi fissato' : 'Fissa in alto',
          ),
          IconButton(
            onPressed: () {
              if (_isEditing) {
                _saveEdits();
              } else {
                setState(() => _isEditing = true);
              }
            },
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_outlined),
            tooltip: _isEditing ? 'Salva modifiche' : 'Modifica',
          ),
          IconButton(
            onPressed: _deleteItem,
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            tooltip: 'Elimina',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Sorgente e data
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                'Salvato in locale (${_current.source}) · $dateStr',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isEditing)
            _buildEditForm()
          else ...[
            Text(
              _current.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            _buildMediaSection(context, scheme),
            _buildContentAndActions(context, scheme),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context, ColorScheme scheme) {
    if (_current.type == MemoryItemType.image &&
        ((_current.filePath != null && _current.filePath!.isNotEmpty) ||
            (_current.base64Data != null && _current.base64Data!.isNotEmpty))) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: LocalFileHelper.buildLocalImage(
              filePath: _current.filePath,
              base64Data: _current.base64Data,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }

    if (_current.type == MemoryItemType.file) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.folder_zip_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _current.fileName ?? 'File allegato',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        [
                          if (_current.mimeType != null) _current.mimeType!,
                          if (_current.formattedFileSize.isNotEmpty)
                            _current.formattedFileSize,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_current.filePath != null && _current.filePath!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Percorso locale: ${_current.filePath}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
            if (_textFilePreview != null) ...[
              const Divider(height: 20),
              Text(
                _textFilePreview!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildContentAndActions(BuildContext context, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_current.url != null && _current.url!.isNotEmpty) ...[
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final uri = Uri.tryParse(_current.url!);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.open_in_browser_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _current.domain ?? 'Apri link nel browser',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          _current.url!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_outward_rounded, color: scheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_current.content.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: SelectableText(
              _current.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                  ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_current.tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _current.tags
                .map(
                  (t) => Chip(
                    label: Text('#$t'),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final textToCopy = _current.url ?? _current.content;
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copiato negli appunti')),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copia'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () {
                  final shareText = _current.content.isNotEmpty
                      ? '${_current.title}\n${_current.content}'
                      : _current.title;
                  SharePlus.instance.share(ShareParams(text: shareText));
                },
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Ricondividi'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Titolo',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _contentController,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Contenuto / Link / Appunto',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _tagsController,
          decoration: const InputDecoration(
            labelText: 'Tag (separati da virgola o spazio)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saveEdits,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salva modifiche in locale'),
          ),
        ),
      ],
    );
  }
}
