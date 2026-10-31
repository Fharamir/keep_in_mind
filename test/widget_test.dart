import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_in_mind/l10n/app_localizations.dart';
import 'package:keep_in_mind/main.dart';
import 'package:keep_in_mind/models/memory_item.dart';
import 'package:keep_in_mind/services/share_intent_service.dart';
import 'package:keep_in_mind/services/storage_service.dart';
import 'package:keep_in_mind/services/widget_sync_service.dart';
import 'package:keep_in_mind/ui/screens/widget_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const widgetChannel = MethodChannel('dev.fharamir.keepinmind/widget');
  String? lastWidgetPayloadJson;

  setUp(() {
    lastWidgetPayloadJson = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, (MethodCall call) async {
      if (call.method == 'updateWidget') {
        final args = call.arguments as Map<dynamic, dynamic>?;
        lastWidgetPayloadJson = args?['payloadJson'] as String?;
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, null);
  });

  group('Keep in Mind - MemoryItem & Share to Self Parser', () {
    test('Riconosce automaticamente un link condiviso ed estrae dominio e titolo', () {
      final item = MemoryItem.fromSharedPayload(
        id: 'test-1',
        rawText: 'Guida architettura Flutter https://docs.flutter.dev/ui',
      );

      expect(item.type, MemoryItemType.link);
      expect(item.url, 'https://docs.flutter.dev/ui');
      expect(item.domain, 'docs.flutter.dev');
      expect(item.title, 'Guida architettura Flutter');
      expect(item.tags, contains('link'));
    });

    test('Riconosce automaticamente immagini e file allegati', () {
      final imgItem = MemoryItem.fromSharedPayload(
        id: 'test-img',
        filePath: '/data/user/0/app/files/screenshot.png',
        fileName: 'screenshot.png',
        mimeType: 'image/png',
        fileSizeBytes: 204800,
      );
      expect(imgItem.type, MemoryItemType.image);
      expect(imgItem.formattedFileSize, '200.0 KB');

      final pdfItem = MemoryItem.fromSharedPayload(
        id: 'test-pdf',
        filePath: '/data/user/0/app/files/contratto.pdf',
        fileName: 'contratto.pdf',
        mimeType: 'application/pdf',
        fileSizeBytes: 1048576,
      );
      expect(pdfItem.type, MemoryItemType.file);
      expect(pdfItem.formattedFileSize, '1.0 MB');
    });

    test('WidgetSyncService seleziona da 1 a 5 contenuti rispettando i fissati', () {
      final now = DateTime.now();
      final items = List.generate(
        7,
        (i) => MemoryItem(
          id: 'id-$i',
          type: MemoryItemType.text,
          title: 'Elemento $i',
          content: 'Contenuto $i',
          isPinned: i == 5,
          createdAt: now.subtract(Duration(minutes: i * 10)),
        ),
      );

      const config3 = WidgetConfig(maxItems: 3, prioritizePinned: true);
      final selected3 = WidgetSyncService.selectWidgetItems(items, config3);
      expect(selected3.length, 3);
      expect(selected3.first.id, 'id-5');

      const config5 = WidgetConfig(maxItems: 5, prioritizePinned: false);
      final selected5 = WidgetSyncService.selectWidgetItems(items, config5);
      expect(selected5.length, 5);
      expect(selected5.first.id, 'id-0');
    });

    test('Valori di default e opzioni configurazione audio e file', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      // Verifica default: 5min per l'audio (300 sec) e no limit per i file (0 MB)
      expect(storage.maxAudioDurationSeconds, 300);
      expect(StorageService.formatAudioDurationOption(storage.maxAudioDurationSeconds), '5m');
      expect(storage.maxFileSizeMb, 0);
      expect(StorageService.formatFileSizeOption(storage.maxFileSizeMb), 'No limit');
      expect(storage.maxFileSizeBytes, isNull);

      // Modifica valori
      await storage.setMaxAudioDurationSeconds(0); // no limit
      expect(storage.maxAudioDurationSeconds, 0);
      expect(StorageService.formatAudioDurationOption(0), 'No limit');

      await storage.setMaxFileSizeMb(50); // 50M
      expect(storage.maxFileSizeMb, 50);
      expect(StorageService.formatFileSizeOption(50), '50M');
      expect(storage.maxFileSizeBytes, 50 * 1024 * 1024);

      // Ricarica per verificare la persistenza in SharedPreferences
      final storageReloaded = StorageService();
      await storageReloaded.init();
      expect(storageReloaded.maxAudioDurationSeconds, 0);
      expect(storageReloaded.maxFileSizeMb, 50);
    });
  });

  testWidgets('KeepInMindApp mostra la libreria locale e riceve Share to Self',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.setLanguageOverride('it');

    final shareService = ShareIntentService();
    addTearDown(shareService.dispose);

    await tester.pumpWidget(
      KeepInMindApp(
        storage: storage,
        shareService: shareService,
      ),
    );
    await tester.pump();

    expect(find.text('Keep in Mind'), findsWidgets);
    expect(find.text('Locale'), findsOneWidget);

    // Simulate incoming OS share payload
    shareService.simulateIncomingShare(
      const SharedIncomingPayload(
        subject: 'Articolo Test Privacy',
        text: 'Articolo Test Privacy https://example.org/privacy',
        source: 'Share to Self',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Articolo Test Privacy'), findsWidgets);
    expect(storage.allItems.first.domain, 'example.org');
    expect(lastWidgetPayloadJson, contains('Articolo Test Privacy'));
  });

  testWidgets('AppAndExportView mostra gli slider audio/file e la nota di avviso per audio no limit',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.init();
    await storage.setLanguageOverride('it');

    await tester.pumpWidget(
      MaterialApp(
        locale: storage.effectiveLocale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLanguage.values.map((l) => Locale(l.code)).toList(),
        home: Scaffold(
          body: AppAndExportView(storage: storage),
        ),
      ),
    );
    await tester.pump();

    // Verifica controlli visibili con i loro default (audio: 5m, file: No limit)
    expect(find.text(storage.l10n.prefMaxAudioDuration), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);

    expect(find.text(storage.l10n.prefMaxFileSize), findsOneWidget);
    expect(find.text(storage.l10n.optionNoLimit), findsOneWidget);

    // Con audio a 5m, il messaggio di avviso NON deve essere presente
    expect(
      find.textContaining('ricordati di interrompere la registrazione'),
      findsNothing,
    );

    // Impostiamo l'audio a no limit (0)
    await storage.setMaxAudioDurationSeconds(0);
    await tester.pump();

    // Ora l'avviso per memoria e batteria DEVE essere visibile
    expect(
      find.textContaining('ricordati di interrompere la registrazione o memoria e batteria saranno a rischio'),
      findsOneWidget,
    );
  });

  group('Keep in Mind - Multi-language, OS detection, Fallback and Override', () {
    test('Risolve correttamente le lingue di sistema supportate', () {
      expect(AppLanguage.resolve(systemLocale: const Locale('it')), AppLanguage.it);
      expect(AppLanguage.resolve(systemLocale: const Locale('en')), AppLanguage.en);
      expect(AppLanguage.resolve(systemLocale: const Locale('es')), AppLanguage.es);
      expect(AppLanguage.resolve(systemLocale: const Locale('fr')), AppLanguage.fr);
      expect(AppLanguage.resolve(systemLocale: const Locale('de')), AppLanguage.de);
      expect(AppLanguage.resolve(systemLocale: const Locale('pt')), AppLanguage.pt);
      expect(AppLanguage.resolve(systemLocale: const Locale('zh')), AppLanguage.zh);
    });

    test('Effettua fallback su inglese (en) se la lingua di sistema non è supportata', () {
      // Lingue non supportate come ja (Giapponese), ru (Russo), ar (Arabo)
      expect(AppLanguage.resolve(systemLocale: const Locale('ja')), AppLanguage.en);
      expect(AppLanguage.resolve(systemLocale: const Locale('ru')), AppLanguage.en);
      expect(AppLanguage.resolve(systemLocale: const Locale('ar')), AppLanguage.en);
    });

    test('L\'override dell\'utente ha precedenza sulla lingua di sistema', () {
      // Sistema in italiano, ma override su spagnolo
      expect(
        AppLanguage.resolve(overrideCode: 'es', systemLocale: const Locale('it')),
        AppLanguage.es,
      );
      // Sistema non supportato (ja), override su francese
      expect(
        AppLanguage.resolve(overrideCode: 'fr', systemLocale: const Locale('ja')),
        AppLanguage.fr,
      );
      // Override resettato a null -> torna a lingua di sistema
      expect(
        AppLanguage.resolve(overrideCode: null, systemLocale: const Locale('de')),
        AppLanguage.de,
      );
    });

    test('StorageService persiste l\'override della lingua e notifica i listener', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      expect(storage.languageOverride, isNull);

      await storage.setLanguageOverride('de');
      expect(storage.languageOverride, 'de');
      expect(storage.effectiveLanguage, AppLanguage.de);
      expect(storage.effectiveLocale, const Locale('de'));
      expect(storage.l10n.actionSave, 'Speichern');

      // Verifica persistenza ricaricando SharedPreferences
      final reloadedStorage = StorageService();
      await reloadedStorage.init();
      expect(reloadedStorage.languageOverride, 'de');
      expect(reloadedStorage.effectiveLanguage, AppLanguage.de);
      expect(reloadedStorage.l10n.actionSave, 'Speichern');

      // Ripristino su automatico (null)
      await reloadedStorage.setLanguageOverride(null);
      expect(reloadedStorage.languageOverride, isNull);
    });

    testWidgets('Selettore di lingua aggiorna dinamicamente tutta l\'interfaccia a runtime',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final shareService = ShareIntentService();
      addTearDown(shareService.dispose);

      await tester.pumpWidget(
        KeepInMindApp(
          storage: storage,
          shareService: shareService,
        ),
      );
      await tester.pump();

      // Default su sistema (es. IT o fallback EN)
      // Cambiamo esplicitamente l'override a 'es' (Spagnolo)
      await storage.setLanguageOverride('es');
      await tester.pumpAndSettle();

      // Verifichiamo che i testi siano in spagnolo
      expect(find.text('Biblioteca'), findsOneWidget); // Tab
      expect(find.text('App y Exportar'), findsOneWidget); // Tab
      expect(find.text('Añadir'), findsOneWidget); // FAB

      // Cambiamo l'override a 'fr' (Francese)
      await storage.setLanguageOverride('fr');
      await tester.pumpAndSettle();

      expect(find.text('Bibliothèque'), findsOneWidget);
      expect(find.text('App et Exporter'), findsOneWidget);
      expect(find.text('Ajouter'), findsOneWidget);

      // Cambiamo l'override a 'zh' (Cinese)
      await storage.setLanguageOverride('zh');
      await tester.pumpAndSettle();

      expect(find.text('资料库'), findsOneWidget);
      expect(find.text('应用与导出'), findsOneWidget);
      expect(find.text('添加'), findsOneWidget);

      // Ripristino su 'it' (Italiano)
      await storage.setLanguageOverride('it');
      await tester.pumpAndSettle();

      expect(find.text('Libreria'), findsOneWidget);
      expect(find.text('App & Esporta'), findsOneWidget);
      expect(find.text('Aggiungi'), findsOneWidget);
    });

    testWidgets('AppAndExportView non include pulsanti simulazione e posiziona clear all in fondo',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLanguage.values.map((l) => Locale(l.code)).toList(),
          home: Scaffold(
            body: AppAndExportView(storage: storage),
          ),
        ),
      );
      await tester.pump();

      // I pulsanti di simulazione share non devono più essere presenti
      expect(find.text(storage.l10n.btnSimulateShareLink), findsNothing);
      expect(find.text(storage.l10n.btnSimulateShareNote), findsNothing);

      // Il pulsante "Cancella tutti i dati" deve essere presente nel menu
      expect(find.text(storage.l10n.btnClearAll), findsOneWidget);
    });

    test('Hardening Import JSON: rifiuta schemi URL pericolosi, path traversal e tipi non validi', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      const maliciousJson = '''
      {
        "items": [
          {
            "id": "item-exploit-1",
            "type": "link",
            "title": "Malicious Link Test",
            "content": "Trying javascript injection",
            "url": "javascript:alert(1)",
            "tags": ["test"]
          },
          {
            "id": "item-exploit-2",
            "type": "file",
            "title": "Malicious File Path Test",
            "content": "Trying path traversal",
            "filePath": "/data/data/com.example.keep_in_mind/shared_prefs/secret.xml",
            "fileName": "secret.xml",
            "tags": ["test"]
          },
          {
            "id": "item-corrupted-types",
            "title": 99999,
            "content": true,
            "isPinned": "true",
            "tags": "non-list-tag"
          }
        ]
      }
      ''';

      final result = await storage.importBackupJson(maliciousJson);
      expect(result['addedCount'], 3);

      final linkItem = storage.allItems.firstWhere((e) => e.id == 'item-exploit-1');
      // Lo schema javascript: deve essere stato azzerato / ignorato
      expect(linkItem.url, isNull);

      final fileItem = storage.allItems.firstWhere((e) => e.id == 'item-exploit-2');
      // Il path non è nella cartella attachments autorizzata, quindi deve essere sanitizzato a null
      expect(fileItem.filePath, isNull);

      final corruptedItem = storage.allItems.firstWhere((e) => e.id == 'item-corrupted-types');
      // I tipi non validi sono stati convertiti in modo difensivo senza crashare
      expect(corruptedItem.title, '99999');
      expect(corruptedItem.content, 'true');
      expect(corruptedItem.isPinned, isTrue);
    });

    test('Import Backup JSON preserva base64Data se filePath non esiste sul dispositivo', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      const backupWithBase64 = '''
      {
        "items": [
          {
            "id": "item-with-base64",
            "type": "image",
            "title": "Foto ripristinata",
            "content": "Nota con immagine",
            "filePath": "/old/nonexistent/device/path/photo.png",
            "fileName": "photo.png",
            "mimeType": "image/png",
            "base64Data": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=",
            "tags": ["immagine"]
          }
        ]
      }
      ''';

      final result = await storage.importBackupJson(backupWithBase64);
      expect(result['addedCount'], 1);

      final imported = storage.allItems.firstWhere((e) => e.id == 'item-with-base64');
      expect(imported.base64Data, isNotNull);
      expect(imported.base64Data!.isNotEmpty, isTrue);
    });

  });
}


