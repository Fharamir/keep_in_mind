import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../models/memory_item.dart';
import '../../services/storage_service.dart';
import '../../utils/local_file_helper.dart';
import '../../utils/tag_helper.dart';

class ItemDetailScreen extends StatefulWidget {
  final MemoryItem item;
  final StorageService storage;
  final bool openedFromWidget;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.storage,
    this.openedFromWidget = false,
  });

  /// Deletes [item], prompting for confirmation if enabled in [storage].
  static Future<bool> confirmAndDelete(
    BuildContext context,
    StorageService storage,
    MemoryItem item,
  ) async {
    final strings = storage.l10n;
    if (storage.confirmBeforeDelete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(strings.deleteConfirmTitle),
          content: Text(
            strings.deleteConfirmMessage(item.title),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
              ),
              child: Text(strings.actionDelete),
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
  static const MethodChannel _mediaChannel =
      MethodChannel('com.example.keep_in_mind/media');

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

  bool _isAudioPlaying = false;
  int _audioPositionMs = 0;
  int _audioDurationMs = 0;
  Timer? _audioStatusTimer;
  AppLocalizations get strings => widget.storage.l10n;


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
    _audioStatusTimer?.cancel();
    _mediaChannel.invokeMethod('audioStop').ignore();
    _titleController.dispose();
    _contentController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  Future<void> _handleBackNavigation() async {
    _audioStatusTimer?.cancel();
    await _mediaChannel.invokeMethod('audioStop').catchError((_) => null);
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (widget.openedFromWidget) {
      await _mediaChannel
          .invokeMethod('closeToHomeScreen')
          .catchError((_) => SystemNavigator.pop());
    }
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
      final strings = widget.storage.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.changesSaved)),
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
      await _handleBackNavigation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = widget.storage.l10n;
    final dateStr =
        DateFormat('dd/MM/yyyy · HH:mm:ss').format(_current.createdAt);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _handleBackNavigation,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: strings.actionBack,
        ),
        title: Text(strings.typeLabel(_current.type.name)),
        actions: [
          IconButton(
            onPressed: _togglePin,
            icon: Icon(
              _current.isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              color: _current.isPinned ? scheme.primary : null,
            ),
            tooltip: _current.isPinned ? strings.tooltipUnpin : strings.tooltipPin,
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
            tooltip: _isEditing ? strings.actionSaveDone : strings.actionEdit,
          ),
          IconButton(
            onPressed: _deleteItem,
            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
            tooltip: strings.actionDelete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Source and creation date
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 15, color: scheme.primary),
              const SizedBox(width: 6),
              Text(
                '${strings.infoSavedOn} (${_current.source}) · $dateStr',
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

  bool _isAudioFile() {
    final mime = (_current.mimeType ?? '').toLowerCase();
    final name = (_current.fileName ?? _current.filePath ?? '').toLowerCase();
    return mime.startsWith('audio/') ||
        name.endsWith('.m4a') ||
        name.endsWith('.mp3') ||
        name.endsWith('.wav') ||
        name.endsWith('.aac') ||
        name.endsWith('.ogg');
  }

  bool _isVideoFile() {
    final mime = (_current.mimeType ?? '').toLowerCase();
    final name = (_current.fileName ?? _current.filePath ?? '').toLowerCase();
    return mime.startsWith('video/') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.webm') ||
        name.endsWith('.mkv');
  }

  Future<void> _toggleAudioPlayPause() async {
    final path = _current.filePath;
    if (path == null || path.isEmpty) return;

    if (_isAudioPlaying) {
      await _mediaChannel.invokeMethod('audioPause');
      _audioStatusTimer?.cancel();
      if (mounted) {
        setState(() => _isAudioPlaying = false);
      }
    } else {
      try {
        final res = await _mediaChannel.invokeMapMethod<String, dynamic>(
          'audioPlay',
          {'filePath': path},
        );
        if (mounted && res != null) {
          setState(() {
            _isAudioPlaying = res['isPlaying'] as bool? ?? true;
            _audioPositionMs = (res['positionMs'] as num?)?.toInt() ?? 0;
            _audioDurationMs = (res['durationMs'] as num?)?.toInt() ?? 0;
          });
          _startAudioStatusPolling();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.audioPlaybackError(e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _stopAudio() async {
    _audioStatusTimer?.cancel();
    await _mediaChannel.invokeMethod('audioStop').catchError((_) => null);
    if (mounted) {
      setState(() {
        _isAudioPlaying = false;
        _audioPositionMs = 0;
      });
    }
  }

  void _startAudioStatusPolling() {
    _audioStatusTimer?.cancel();
    _audioStatusTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) async {
        try {
          final res = await _mediaChannel
              .invokeMapMethod<String, dynamic>('audioGetStatus');
          if (!mounted || res == null) return;
          final playing = res['isPlaying'] as bool? ?? false;
          final pos = (res['positionMs'] as num?)?.toInt() ?? 0;
          final dur = (res['durationMs'] as num?)?.toInt() ?? 0;
          setState(() {
            _isAudioPlaying = playing;
            _audioPositionMs = pos;
            if (dur > 0) _audioDurationMs = dur;
          });
          if (!playing) {
            _audioStatusTimer?.cancel();
          }
        } catch (_) {}
      },
    );
  }

  String _formatDurationMs(int ms) {
    final totalSec = (ms / 1000).floor().clamp(0, 86400);
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
      if (_isAudioFile() &&
          _current.filePath != null &&
          _current.filePath!.isNotEmpty) {
        return _buildAudioPlayerCard(scheme);
      }

      if (_isVideoFile() &&
          _current.filePath != null &&
          _current.filePath!.isNotEmpty) {
        return _buildVideoPlayerCard(scheme);
      }

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
                        _current.fileName ?? strings.fileAttachmentLabel,
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
                '${strings.infoPath}: ${_current.filePath}',
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

  Widget _buildAudioPlayerCard(ColorScheme scheme) {
    final maxMs = _audioDurationMs > 0 ? _audioDurationMs : 1;
    final currentMs = _audioPositionMs.clamp(0, maxMs);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.deepOrangeAccent.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: FilledButton(
                  onPressed: _toggleAudioPlayPause,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepOrangeAccent,
                    padding: EdgeInsets.zero,
                    shape: const CircleBorder(),
                  ),
                  child: Icon(
                    _isAudioPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _current.fileName ?? strings.audioRecordingLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDurationMs(currentMs)} / ${_formatDurationMs(_audioDurationMs)}'
                      '${_current.formattedFileSize.isNotEmpty ? " · ${_current.formattedFileSize}" : ""}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isAudioPlaying || _audioPositionMs > 0)
                IconButton(
                  onPressed: _stopAudio,
                  icon: const Icon(Icons.stop_rounded),
                  tooltip: strings.btnStopAudio,
                ),
            ],
          ),
          Slider(
            value: currentMs.toDouble(),
            min: 0,
            max: maxMs.toDouble(),
            activeColor: Colors.deepOrangeAccent,
            onChanged: _audioDurationMs > 0
                ? (val) {
                    final target = val.round();
                    setState(() => _audioPositionMs = target);
                    _mediaChannel.invokeMethod(
                      'audioSeek',
                      {'positionMs': target},
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayerCard(ColorScheme scheme) {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAndroid)
            SizedBox(
              height: 240,
              width: double.infinity,
              child: AndroidView(
                viewType: 'keep_in_mind_video_view',
                creationParams: {'filePath': _current.filePath},
                creationParamsCodec: const StandardMessageCodec(),
              ),
            )
          else
            Container(
              height: 180,
              width: double.infinity,
              color: Colors.black87,
              alignment: Alignment.center,
              child: const Icon(
                Icons.videocam_rounded,
                color: Colors.white70,
                size: 48,
              ),
            ),
          Container(
            width: double.infinity,
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.play_circle_outline_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.videoPlayerTapHint(
                      _current.fileName ?? strings.videoAttachmentLabel,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                          _current.domain ?? strings.btnOpenBrowser,
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
        if (TagVisuals.effectiveTagsForItem(_current).isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TagVisuals.effectiveTagsForItem(_current).map((t) {
              final tagColor = TagVisuals.colorForTag(t);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(TagVisuals.iconForTag(t), size: 15, color: tagColor),
                    const SizedBox(width: 5),
                    Text(
                      strings.tagLabel(t),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tagColor,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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
                    SnackBar(content: Text(strings.copiedToClipboard)),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(strings.actionCopy),
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
                label: Text(strings.actionReshare),
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

    final strings = widget.storage.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: strings.inputTitleLabel,
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
            labelText: strings.inputContentLabel,
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
              '${strings.detailSectionTags}:',
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
          runSpacing: 6,
          children: [
            ...{...availableTags, ..._selectedTags}.map((tag) {
              final isSelected = _selectedTags.contains(tag);
              final color = TagVisuals.colorForTag(tag);
              return FilterChip(
                selected: isSelected,
                avatar: Icon(
                  TagVisuals.iconForTag(tag),
                  size: 16,
                  color: color,
                ),
                label: Text(
                  strings.tagLabel(tag),
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? color : null,
                  ),
                ),
                selectedColor: color.withValues(alpha: 0.18),
                checkmarkColor: color,
                side: BorderSide(
                  color: isSelected
                      ? color
                      : scheme.outlineVariant.withValues(alpha: 0.7),
                ),
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
                    hintText: strings.createNewTagHint,
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
                label: Text(strings.btnAddTag),
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
            label: Text(strings.actionSaveDone),
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
              Expanded(
                child: Text(
                  strings.attachmentRemovedNotice,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: _handleUndoRemoveAttachmentInEdit,
                child: Text(strings.actionCancel),
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
                    widget.storage.l10n.actionRemove,
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
