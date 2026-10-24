import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keep_in_mind/main.dart';
import 'package:keep_in_mind/models/memory_item.dart';
import 'package:keep_in_mind/services/share_intent_service.dart';
import 'package:keep_in_mind/services/storage_service.dart';
import 'package:keep_in_mind/services/widget_sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const widgetChannel = MethodChannel('com.example.keep_in_mind/widget');
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
  });

  testWidgets('KeepInMindApp mostra la libreria locale e riceve Share to Self',
      (WidgetTester tester) async {
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

    expect(find.text('Keep in Mind'), findsWidgets);
    expect(find.text('Locale'), findsOneWidget);

    // Simula l'arrivo di una condivisione dal Sistema Operativo ("Share to Self")
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
}


