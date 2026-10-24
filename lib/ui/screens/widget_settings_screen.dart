import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/memory_item.dart';
import '../../services/share_intent_service.dart';
import '../../services/storage_service.dart';
import '../widgets/home_widget_preview.dart';
import 'item_detail_screen.dart';

/// Vista dedicata esclusivamente alla configurazione del Widget Home Screen.
class WidgetConfigView extends StatelessWidget {
  final StorageService storage;
  final VoidCallback? onQuickAddTap;

  const WidgetConfigView({
    super.key,
    required this.storage,
    this.onQuickAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final config = storage.widgetConfig;
        final widgetItems = storage.widgetItems;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Anteprima Live del Widget',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ecco come appare il widget Keep in Mind sulla schermata Home del dispositivo con gli ultimi ${config.maxItems} contenuti:',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            HomeWidgetPreview(
              items: widgetItems,
              config: config,
              totalCount: storage.allItems.length,
              onQuickAddTap: onQuickAddTap,
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
                Text(
                  'Impostazioni Widget (1 - 5 contenuti)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Numero di elementi mostrati:'),
                Chip(
                  label: Text(
                    '${config.maxItems} ${config.maxItems == 1 ? "elemento" : "elementi"}',
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
              title: const Text('Dai priorità ai contenuti Fissati'),
              subtitle: const Text(
                'Mostra prima gli elementi con la puntina e poi gli ultimi salvati',
              ),
              value: config.prioritizePinned,
              onChanged: (v) {
                storage.updateWidgetConfig(
                  config.copyWith(prioritizePinned: v),
                );
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostra tag nel Widget'),
              value: config.showTags,
              onChanged: (v) {
                storage.updateWidgetConfig(config.copyWith(showTags: v));
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Filtra tipo di contenuto nel Widget:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Tutti'),
                  selected: config.filterType == null,
                  onSelected: (_) {
                    storage.updateWidgetConfig(
                      config.copyWith(clearFilterType: true),
                    );
                  },
                ),
                ...MemoryItemType.values.map((t) {
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: config.filterType == t,
                    onSelected: (_) {
                      storage.updateWidgetConfig(
                        config.copyWith(filterType: t),
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

/// Vista dedicata alla configurazione dell'App, Esportazione/Importazione JSON e Privacy.
class AppAndExportView extends StatelessWidget {
  final StorageService storage;
  final ShareIntentService? shareService;

  const AppAndExportView({
    super.key,
    required this.storage,
    this.shareService,
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
            _buildPrivacyAndBackupCard(context, scheme),
            const SizedBox(height: 20),
            _buildAppStatsAndConfigCard(
              context,
              scheme,
              totalItems: totalItems,
              pinnedCount: pinnedCount,
              tagsCount: tagsCount,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPrivacyAndBackupCard(BuildContext context, ColorScheme scheme) {
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
                Text(
                  'Esporta & Ripristina Contenuti',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Esporta tutti i tuoi contenuti salvati in formato JSON per conservarne una copia di backup o trasferirli su un altro dispositivo.',
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
                        subject: 'Keep in Mind Backup Locale',
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Esporta Contenuti'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final json = storage.exportBackupJson();
                    Clipboard.setData(ClipboardData(text: json));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Backup JSON copiato negli appunti'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Copia Backup JSON'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showImportDialog(context),
                  icon: const Icon(Icons.restore_page_outlined, size: 18),
                  label: const Text('Importa JSON'),
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
                Text(
                  'Configurazione App & Memoria Locale',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
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
                    label: 'Contenuti',
                    value: '$totalItems',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    scheme,
                    label: 'Fissati',
                    value: '$pinnedCount',
                    icon: Icons.push_pin_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatTile(
                    scheme,
                    label: 'Tag',
                    value: '$tagsCount',
                    icon: Icons.tag_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Keep in Mind non utilizza alcun server cloud né telemetria. '
              'Tutti i link, testi, immagini e file risiedono esclusivamente nella memoria locale del dispositivo.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            if (shareService != null) ...[
              const Divider(height: 28),
              Text(
                'Strumenti di Test Condivisione:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      shareService!.simulateIncomingShare(
                        const SharedIncomingPayload(
                          subject: 'Articolo approfondimento Flutter Local-First',
                          text:
                              'Articolo approfondimento Flutter Local-First https://docs.flutter.dev/platform-integration/android/install-app',
                          source: 'Share to Self (Simulato)',
                        ),
                      );
                    },
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: const Text('Simula Share Link'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      shareService!.simulateIncomingShare(
                        const SharedIncomingPayload(
                          subject: 'Idea progetto Keep in Mind',
                          text:
                              'Ricordarsi di testare il widget sulla schermata Home con gli ultimi 1-5 contenuti salvati.',
                          source: 'Share to Self (Simulato)',
                        ),
                      );
                    },
                    icon: const Icon(Icons.notes_rounded, size: 16),
                    label: const Text('Simula Share Nota'),
                  ),
                ],
              ),
            ],
            const Divider(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _confirmClearAll(context),
                icon: Icon(
                  Icons.delete_forever_outlined,
                  size: 18,
                  color: scheme.error,
                ),
                label: Text(
                  'Svuota memoria locale',
                  style: TextStyle(color: scheme.error),
                ),
              ),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importa Backup JSON Locale'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Incolla qui il JSON esportato da Keep in Mind...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final count =
                    await storage.importBackupJson(ctrl.text.trim());
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Importati $count nuovi elementi in locale!'),
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Formato JSON non valido'),
                    ),
                  );
                }
              }
            },
            child: const Text('Importa'),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Svuotare tutta la memoria locale?'),
        content: const Text(
          'Questa operazione eliminerà definitivamente tutti i contenuti e i file allegati salvati sul dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              await storage.clearAllItems();
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Elimina tutto'),
          ),
        ],
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
        title: const Text('Configura Widget (1-5)'),
      ),
      body: WidgetConfigView(storage: storage),
    );
  }
}
