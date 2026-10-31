import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
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

    return ListenableBuilder(
      listenable: storage,
      builder: (context, _) {
        final activeLocale = storage.effectiveLocale;

        return MaterialApp(
          title: 'Keep in Mind',
          debugShowCheckedModeBanner: false,
          locale: activeLocale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales:
              AppLanguage.values.map((l) => Locale(l.code)).toList(),
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (storage.languageOverride != null) {
              return activeLocale;
            }
            if (deviceLocale != null) {
              final matched = AppLanguage.fromCode(deviceLocale.languageCode);
              if (matched != null) return Locale(matched.code);
            }
            return const Locale('en');
          },
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
      },
    );
  }
}


