import 'package:flutter/material.dart';
import 'services/share_intent_service.dart';
import 'services/storage_service.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final shareIntentService = ShareIntentService();
  await shareIntentService.init();

  runApp(
    KeepInMindApp(
      storage: storageService,
      shareService: shareIntentService,
    ),
  );
}

class KeepInMindApp extends StatelessWidget {
  final StorageService storage;
  final ShareIntentService shareService;

  const KeepInMindApp({
    super.key,
    required this.storage,
    required this.shareService,
  });

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF3F51B5);

    return MaterialApp(
      title: 'Keep in Mind',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
      ),
      home: HomeScreen(
        storage: storage,
        shareService: shareService,
      ),
    );
  }
}

