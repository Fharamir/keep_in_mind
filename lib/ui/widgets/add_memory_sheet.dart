import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/storage_service.dart';

class AddMemorySheet extends StatefulWidget {
  final StorageService storage;
  final String? initialText;
  final String? initialSubject;

  const AddMemorySheet({
    super.key,
    required this.storage,
    this.initialText,
    this.initialSubject,
  });

  @override
  State<AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<AddMemorySheet> {
  late final TextEditingController _contentController;
  late final TextEditingController _titleController;
  final TextEditingController _newTagController = TextEditingController();
  
  final Set<String> _selectedTags = {};

  PlatformFile? _selectedFile;
  String? _selectedMimeType;
  bool _isPinned = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialText ?? '');
    _titleController = TextEditingController(text: widget.initialSubject ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      setState(() {
        _contentController.text = text;
      });
    }
  }

  Future<void> _pickFile({required bool imageOnly}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: imageOnly ? FileType.image : FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final ext = (file.extension ?? '').toLowerCase();
        String mime = 'application/octet-stream';
        if (imageOnly ||
            ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
          mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        } else if (ext == 'pdf') {
          mime = 'application/pdf';
        } else if (['txt', 'md', 'json', 'csv'].contains(ext)) {
          mime = 'text/plain';
        }

        setState(() {
          _selectedFile = file;
          _selectedMimeType = mime;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text = file.name;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore selezione file: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    final rawText = _contentController.text.trim();
    final rawSubject = _titleController.text.trim();
    if (rawText.isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci un link, una nota o allega un file/immagine'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final tags = _selectedTags.toList();

    final saved = await widget.storage.addSharedOrManualItem(
      rawText: rawText,
      rawSubject: rawSubject.isNotEmpty ? rawSubject : null,
      filePath: _selectedFile?.path,
      fileName: _selectedFile?.name,
      mimeType: _selectedMimeType,
      fileSizeBytes: _selectedFile?.size,
      fileBytes: _selectedFile?.bytes,
      customTags: tags,
      isPinned: _isPinned,
      source: 'Manuale / Locale',
    );

    if (mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.add_task_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Keep in Mind (Salva in locale)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text('Incolla'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                labelText: 'Link URL o Nota di testo',
                hintText: 'https://... oppure scrivi un appunto veloce',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildAttachmentButtons(scheme),
            const SizedBox(height: 12),
            _buildMetadataFields(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentButtons(ColorScheme scheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickFile(imageOnly: true),
                icon: const Icon(Icons.image_outlined, size: 18),
                label: const Text('Allega Immagine'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickFile(imageOnly: false),
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Allega File'),
              ),
            ),
          ],
        ),
        if (_selectedFile != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  (_selectedMimeType ?? '').startsWith('image/')
                      ? Icons.image_rounded
                      : Icons.insert_drive_file_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFile!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedFile = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetadataFields(ColorScheme scheme) {
    final availableTags = widget.storage.availableTags;

    void addNewTag() {
      // Pulisce il testo: solo caratteri alfanumerici, trattini o underscore, senza spazi e simboli strani
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
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Titolo (opzionale — generato automaticamente)',
            prefixIcon: const Icon(Icons.title_rounded, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 14),
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
            const Spacer(),
            FilterChip(
              selected: _isPinned,
              onSelected: (v) => setState(() => _isPinned = v),
              avatar: Icon(
                _isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                size: 16,
              ),
              label: const Text('Fissa'),
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
            // Mostra anche i tag custom selezionati che non sono ancora negli availableTags
            ..._selectedTags.where((tag) => !availableTags.contains(tag)).map((tag) {
              return FilterChip(
                selected: true,
                label: Text('#$tag'),
                onSelected: (selected) {
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
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.download_done_rounded),
            label: Text(
              _isSaving
                  ? 'Salvataggio in locale...'
                  : 'Salva in Keep in Mind',
            ),
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
}
