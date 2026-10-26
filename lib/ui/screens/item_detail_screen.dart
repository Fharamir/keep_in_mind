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

  /// Esegue la cancellazione di un contenuto chiedendo conferma all'utente
  /// se l'impostazione [storage.confirmBeforeDelete] è attiva.
  static Future<bool> confirmAndDelete(
    BuildContext context,
    StorageService storage,
    MemoryItem item,
  ) async {
    if (storage.confirmBeforeDelete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Eliminare questo contenuto?'),
          content: Text(
            'Vuoi eliminare definitivamente "${item.title}" dalla memoria locale?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: const Text('Elimina'),
            ),
          ],
        ),
      );
      if (confirmed != true) return false;
    }

    await storage.deleteItem(item.id);
    return true;
  }

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late MemoryItem _current;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final TextEditingController _newTagController = TextEditingController();
  late Set<String> _selectedTags;
  bool _removeAttachment = false;
  String? _removedAttachmentTitleBackup;
  String? _removedAttachmentTagBackup;
  String? _textFilePreview;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _current = widget.item;
    _titleController = TextEditingController(text: _current.title);
    _contentController = TextEditingController(text: _current.content);
    _selectedTags = Set<String>.from(_current.tags);
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
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _saveEdits() async {
    final tags = _selectedTags.toList();
    final newContent = _contentController.text.trim();
    final extractedUrl = MemoryItem.extractFirstUrl(newContent) ?? _current.url;
    final extractedDomain = extractedUrl != null
        ? MemoryItem.extractDomain(extractedUrl)
        : _current.domain;

    MemoryItemType resolvedType = _current.type;
    if (_removeAttachment) {
      resolvedType =
          extractedUrl != null ? MemoryItemType.link : MemoryItemType.text;
    }

    final updated = _current.copyWith(
      type: resolvedType,
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : _current.title,
      content: newContent,
      url: extractedUrl,
      domain: extractedDomain,
      clearAttachment: _removeAttachment,
      tags: tags,
    );

    await widget.storage.updateItem(updated);
    if (mounted) {
      setState(() {
        _current = updated;
        _removeAttachment = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modifiche salvate')),
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
    final deleted = await ItemDetailScreen.confirmAndDelete(
      context,
      widget.storage,
      _current,
    );
    if (deleted && mounted) {
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
    final scheme = Theme.of(context).colorScheme;
    final availableTags = widget.storage.availableTags;

    void addNewTag() {
      final raw = _newTagController.text.trim().toLowerCase();
      final sanitized = raw
          .replaceAll(RegExp(r'[^a-z0-9\-_]'), '')
          .replaceAll(RegExp(r'[\s]+'), '');

      if (sanitized.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Il tag può contenere solo lettere, numeri, "-" e "_"'),
          ),
        );
        return;
      }

      if (sanitized.length > 20) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Il tag non può superare i 20 caratteri'),
          ),
        );
        return;
      }

      setState(() {
        _selectedTags.add(sanitized);
        _newTagController.clear();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Titolo',
            prefixIcon: const Icon(Icons.title_rounded, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _contentController,
          maxLines: 6,
          minLines: 3,
          decoration: InputDecoration(
            labelText: 'Contenuto / Link / Appunto',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        _buildEditAttachmentBox(scheme),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.tag_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              'Tag Disponibili:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ...availableTags.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              return FilterChip(
                selected: isSelected,
                label: Text('#$tag'),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTags.add(tag);
                    } else {
                      _selectedTags.remove(tag);
                    }
                  });
                },
              );
            }),
            ..._selectedTags
                .where((tag) => !availableTags.contains(tag))
                .map((tag) {
              return FilterChip(
                selected: true,
                label: Text('#$tag'),
                onSelected: (_) {
                  setState(() {
                    _selectedTags.remove(tag);
                  });
                },
              );
            }),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _newTagController,
                  maxLength: 20,
                  onSubmitted: (_) => addNewTag(),
                  decoration: InputDecoration(
                    hintText: 'Crea nuovo tag...',
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: addNewTag,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Aggiungi'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _saveEdits,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salva Modifiche'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handleRemoveAttachmentInEdit() {
    final mime = (_current.mimeType ?? '').toLowerCase();
    final mediaTag = _current.type == MemoryItemType.image ||
            mime.startsWith('image/')
        ? 'immagine'
        : (mime.startsWith('audio/') ? 'audio' : 'file');

    final currentTitle = _titleController.text.trim();
    final isDefaultAttachmentTitle = currentTitle == _current.fileName ||
        currentTitle == 'Foto scattata' ||
        currentTitle == 'Allegato' ||
        currentTitle.startsWith('Nota vocale (');

    setState(() {
      _removeAttachment = true;
      if (_selectedTags.contains(mediaTag)) {
        _removedAttachmentTagBackup = mediaTag;
        _selectedTags.remove(mediaTag);
      }
      if (isDefaultAttachmentTitle) {
        _removedAttachmentTitleBackup = currentTitle;
        final textContent = _contentController.text.trim();
        _titleController.text = textContent.isNotEmpty
            ? textContent.split('\n').first
            : 'Nota veloce';
      }
    });
  }

  void _handleUndoRemoveAttachmentInEdit() {
    setState(() {
      _removeAttachment = false;
      if (_removedAttachmentTagBackup != null) {
        _selectedTags.add(_removedAttachmentTagBackup!);
        _removedAttachmentTagBackup = null;
      }
      if (_removedAttachmentTitleBackup != null) {
        _titleController.text = _removedAttachmentTitleBackup!;
        _removedAttachmentTitleBackup = null;
      }
    });
  }

  Widget _buildEditAttachmentBox(ColorScheme scheme) {
    final hasFileOrBase64 =
        (_current.filePath != null && _current.filePath!.isNotEmpty) ||
            (_current.base64Data != null && _current.base64Data!.isNotEmpty);

    if (!hasFileOrBase64) return const SizedBox.shrink();

    if (_removeAttachment) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: scheme.error),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Allegato rimosso (verrà eliminato al salvataggio)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _handleUndoRemoveAttachmentInEdit,
                child: const Text('Annulla'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_current.type == MemoryItemType.image) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 160),
                  child: SizedBox(
                    width: double.infinity,
                    child: LocalFileHelper.buildLocalImage(
                      filePath: _current.filePath,
                      base64Data: _current.base64Data,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Icon(
                  _current.type == MemoryItemType.image
                      ? Icons.image_rounded
                      : (_current.mimeType ?? '').startsWith('audio/')
                          ? Icons.mic_rounded
                          : Icons.insert_drive_file_rounded,
                  color: scheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _current.fileName ?? 'File allegato',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (_current.formattedFileSize.isNotEmpty ||
                          _current.mimeType != null)
                        Text(
                          [
                            if (_current.mimeType != null) _current.mimeType!,
                            if (_current.formattedFileSize.isNotEmpty)
                              _current.formattedFileSize,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _handleRemoveAttachmentInEdit,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: scheme.error,
                  ),
                  label: Text(
                    'Rimuovi',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
