import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/memory_item.dart';
import '../../services/storage_service.dart';
import '../../utils/tag_helper.dart';
import '../widgets/home_widget_preview.dart';
import 'item_detail_screen.dart';

/// Home screen widget preview and configuration view.
class WidgetConfigView extends StatelessWidget {
  final StorageService storage;
  final VoidCallback? onQuickAddTap;
  final VoidCallback? onViewAllTap;

  const WidgetConfigView({
    super.key,
    required this.storage,
    this.onQuickAddTap,
    this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = storage.l10n;

    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final config = storage.widgetConfig;
        final widgetItems = storage.widgetItems;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              strings.widgetPreviewTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.widgetPreviewSubtitle(config.maxItems),
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            HomeWidgetPreview(
              items: widgetItems,
              config: config,
              totalCount: storage.allItems.length,
              onQuickAddTap: onQuickAddTap,
              onViewAllTap: onViewAllTap,
              onItemTap: (item) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItemDetailScreen(
                      item: item,
                      storage: storage,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            _buildConfigCard(context, scheme, config),
          ],
        );
      },
    );
  }

  Widget _buildConfigCard(
    BuildContext context,
    ColorScheme scheme,
    WidgetConfig config,
  ) {
    final strings = storage.l10n;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.widgets_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.widgetConfigCardTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(strings.widgetConfigItemsCount),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    '${config.maxItems}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Slider(
              value: config.maxItems.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '${config.maxItems}',
              onChanged: (val) {
                storage.updateWidgetConfig(
                  config.copyWith(maxItems: val.round()),
                );
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.widgetConfigPrioritizePinned),
              subtitle: Text(strings.widgetConfigPrioritizePinnedSubtitle),
              value: config.prioritizePinned,
              onChanged: (v) {
                storage.updateWidgetConfig(
                  config.copyWith(prioritizePinned: v),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              strings.widgetConfigFilterBy,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(strings.filterAll),
                  selected: config.filterTag == null &&
                      config.filterType == null,
                  onSelected: (_) {
                    storage.updateWidgetConfig(
                      config.copyWith(
                        clearFilterTag: true,
                        clearFilterType: true,
                      ),
                    );
                  },
                ),
                ...storage.availableTags.map((tag) {
                  final isSelected = config.filterTag == tag;
                  final color = TagVisuals.colorForTag(tag);
                  return ChoiceChip(
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
                    selected: isSelected,
                    selectedColor: color.withValues(alpha: 0.18),
                    checkmarkColor: color,
                    side: BorderSide(
                      color: isSelected
                          ? color
                          : scheme.outlineVariant.withValues(alpha: 0.7),
                    ),
                    onSelected: (_) {
                      storage.updateWidgetConfig(
                        config.copyWith(
                          filterTag: isSelected ? null : tag,
                          clearFilterTag: isSelected,
                          clearFilterType: true,
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// App settings, JSON backup/restore, and privacy view.
class AppAndExportView extends StatelessWidget {
  final StorageService storage;

  const AppAndExportView({
    super.key,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final totalItems = storage.allItems.length;
        final pinnedCount =
            storage.allItems.where((item) => item.isPinned).length;
        final tagsCount = storage.availableTags.length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _buildLanguageSelectorCard(context, scheme),
            const SizedBox(height: 20),
            _buildPrivacyAndBackupCard(context, scheme),
            const SizedBox(height: 20),
            _buildAppStatsAndConfigCard(
              context,
              scheme,
              totalItems: totalItems,
              pinnedCount: pinnedCount,
              tagsCount: tagsCount,
            ),
            const SizedBox(height: 20),
            _buildCreditsAndSupportCard(context, scheme),
            const SizedBox(height: 20),
            _buildDangerZoneCard(context, scheme),
          ],
        );
      },
    );
  }

  Widget _buildLanguageSelectorCard(BuildContext context, ColorScheme scheme) {
    final strings = storage.l10n;
    final currentOverride = storage.languageOverride;
    final effectiveLang = storage.effectiveLanguage;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.translate_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.languageSettingsTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (currentOverride == null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        strings.languageAutoSystem,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.languageSettingsSubtitle,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: currentOverride,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Row(
                    children: [
                      const Text('🌐', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${strings.languageAutoSystem} (${effectiveLang.label})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                ...AppLanguage.values.map(
                  (lang) => DropdownMenuItem<String?>(
                    value: lang.code,
                    child: Row(
                      children: [
                        Text(lang.flag, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${lang.label} (${lang.code.toUpperCase()})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: currentOverride == lang.code
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (newCode) async {
                await storage.setLanguageOverride(newCode);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyAndBackupCard(BuildContext context, ColorScheme scheme) {
    final strings = storage.l10n;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.ios_share_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.backupCardTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              strings.backupDescription,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    final json = storage.exportBackupJson();
                    SharePlus.instance.share(
                      ShareParams(
                        text: json,
                        subject: 'Keep in Mind Backup JSON',
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(strings.btnExportJson),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final json = storage.exportBackupJson();
                    Clipboard.setData(ClipboardData(text: json));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(strings.copiedToClipboard),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: Text(strings.btnCopyJson),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showImportDialog(context),
                  icon: const Icon(Icons.restore_page_outlined, size: 18),
                  label: Text(strings.btnImportJson),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppStatsAndConfigCard(
    BuildContext context,
    ColorScheme scheme, {
    required int totalItems,
    required int pinnedCount,
    required int tagsCount,
  }) {
    final strings = storage.l10n;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_suggest_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.preferencesCardTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    scheme,
                    label: strings.statTotalSaved,
                    value: '$totalItems',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    scheme,
                    label: strings.statPinned,
                    value: '$pinnedCount',
                    icon: Icons.push_pin_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    scheme,
                    label: strings.statCustomTags,
                    value: '$tagsCount',
                    icon: Icons.tag_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.prefConfirmDelete),
              subtitle: Text(strings.prefConfirmDeleteSubtitle),
              value: storage.confirmBeforeDelete,
              onChanged: (v) {
                storage.setConfirmBeforeDelete(v);
              },
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.mic_none_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.prefMaxAudioDuration,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    StorageService.formatAudioDurationOption(
                      storage.maxAudioDurationSeconds,
                      strings,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Slider(
              value: StorageService.audioDurationOptionsSeconds
                  .indexOf(storage.maxAudioDurationSeconds)
                  .clamp(0, StorageService.audioDurationOptionsSeconds.length - 1)
                  .toDouble(),
              min: 0,
              max: (StorageService.audioDurationOptionsSeconds.length - 1).toDouble(),
              divisions: StorageService.audioDurationOptionsSeconds.length - 1,
              label: StorageService.formatAudioDurationOption(
                storage.maxAudioDurationSeconds,
                strings,
              ),
              onChanged: (val) {
                final selectedOption =
                    StorageService.audioDurationOptionsSeconds[val.round()];
                storage.setMaxAudioDurationSeconds(selectedOption);
              },
            ),
            if (storage.maxAudioDurationSeconds == 0) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.prefAudioNoLimitWarning,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB78103),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.prefMaxFileSize,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    StorageService.formatFileSizeOption(
                      storage.maxFileSizeMb,
                      strings,
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Slider(
              value: StorageService.fileSizeOptionsMb
                  .indexOf(storage.maxFileSizeMb)
                  .clamp(0, StorageService.fileSizeOptionsMb.length - 1)
                  .toDouble(),
              min: 0,
              max: (StorageService.fileSizeOptionsMb.length - 1).toDouble(),
              divisions: StorageService.fileSizeOptionsMb.length - 1,
              label: StorageService.formatFileSizeOption(
                storage.maxFileSizeMb,
                strings,
              ),
              onChanged: (val) {
                final selectedOption =
                    StorageService.fileSizeOptionsMb[val.round()];
                storage.setMaxFileSizeMb(selectedOption);
              },
            ),
            const SizedBox(height: 10),
            Text(
              strings.backupDescription,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    ColorScheme scheme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final ctrl = TextEditingController();
    final strings = storage.l10n;

    Future<void> processJsonString(String rawJson) async {
      try {
        final result = await storage.importBackupJson(rawJson);
        final added = result['addedCount'] ?? 0;
        final merged = result['mergedTagsCount'] ?? 0;

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.importSuccessMessage(added, merged)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.importEmptyOrInvalidError),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.importDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.importDialogInstruction,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: strings.importPasteHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  final picked = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json', 'txt'],
                    withData: true,
                  );
                  if (picked != null && picked.files.isNotEmpty) {
                    final file = picked.files.first;
                    final bytes = file.bytes;
                    if (bytes != null) {
                      if (bytes.length > 15 * 1024 * 1024) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('File troppo grande (max 15 MB)'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                        return;
                      }
                      final jsonStr = utf8.decode(bytes);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      await processJsonString(jsonStr);
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: Text(strings.btnChooseFile),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.actionCancel),
          ),
          FilledButton(
            onPressed: () => processJsonString(ctrl.text.trim()),
            child: Text(strings.btnConfirmImport),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    final strings = storage.l10n;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.clearAllDialogTitle),
        content: Text(strings.clearAllDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(strings.actionCancel),
          ),
          FilledButton(
            onPressed: () async {
              await storage.clearAllItems();
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.allDataCleared)),
                );
              }
            },
            child: Text(strings.btnClearAll),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditsAndSupportCard(BuildContext context, ColorScheme scheme) {
    const mediaChannel = MethodChannel('com.example.keep_in_mind/media');

    Future<void> handleTip(String productId, String title, String price) async {
      try {
        await mediaChannel.invokeMethod('launchPlayBillingTip', {
          'productId': productId,
        });
      } catch (_) {}

      if (context.mounted) {
        final strings = storage.l10n;
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.coffee_rounded, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(child: Text(title)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.symbolicSupportLabel(price),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  strings.coffeeDialogBody,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(strings.actionClose),
              ),
            ],
          ),
        );
      }
    }

    final strings = storage.l10n;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.coffee_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.creditsCardTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              strings.creditsDescription,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Text('☕'),
                  label: Text(strings.coffeeOption1),
                  onPressed: () =>
                      handleTip('coffee_tip_1', strings.coffeeOption1, '1,99 €'),
                ),
                ActionChip(
                  avatar: const Text('🥐'),
                  label: Text(strings.coffeeOption2),
                  onPressed: () => handleTip(
                      'coffee_tip_2', strings.coffeeOption2, '3,99 €'),
                ),
                ActionChip(
                  avatar: const Text('🚀'),
                  label: Text(strings.coffeeOption3),
                  onPressed: () => handleTip(
                      'coffee_tip_3', strings.coffeeOption3, '7,99 €'),
                ),
              ],
            ),
            const Divider(height: 24),
            Center(
              child: Text(
                'Keep in Mind · v1.0.0 · 100% Local-First',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZoneCard(BuildContext context, ColorScheme scheme) {
    final strings = storage.l10n;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.error.withValues(alpha: 0.3)),
      ),
      color: scheme.errorContainer.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: scheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.clearAllDialogTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.clearAllDialogMessage,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _confirmClearAll(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
              ),
              icon: const Icon(Icons.delete_forever_outlined, size: 18),
              label: Text(strings.btnClearAll),
            ),
          ],
        ),
      ),
    );
  }
}

class WidgetSettingsScreen extends StatelessWidget {
  final StorageService storage;

  const WidgetSettingsScreen({
    super.key,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(storage.l10n.widgetConfigCardTitle),
      ),
      body: WidgetConfigView(storage: storage),
    );
  }
}
