import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/memory_item.dart';
import '../../services/storage_service.dart';
import '../widgets/home_widget_preview.dart';
import 'item_detail_screen.dart';

class WidgetSettingsScreen extends StatelessWidget {
  final StorageService storage;

  const WidgetSettingsScreen({
    super.key,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final config = storage.widgetConfig;
        final widgetItems = storage.widgetItems;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Widget (1-5) & Privacy Locale'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 24),
              _buildPrivacyAndBackupCard(context, scheme),
            ],
          ),
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
                Icon(Icons.lock_outline_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Privacy 100% Locale & Backup',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Keep in Mind non utilizza alcun server cloud né telemetria. '
              'Tutti i link, testi, immagini e file risiedono esclusivamente nella memoria locale del dispositivo.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
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
                  label: const Text('Esporta Backup'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showImportDialog(context),
                  icon: const Icon(Icons.restore_page_outlined, size: 18),
                  label: const Text('Importa JSON'),
                ),
                TextButton.icon(
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
              ],
            ),
          ],
        ),
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
