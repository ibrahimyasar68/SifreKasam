import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/app_lock.dart';
import 'services/backup_actions.dart';
import 'services/theme_controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  // Kenardan kenara görünüm: içerik gezinme çubuğunun arkasına uzanır.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  await ThemeController.instance.init();
  await BackupActions.init();
  await AppLock.instance.init();
  runApp(const SifreKasamApp());
}

class SifreKasamApp extends StatefulWidget {
  const SifreKasamApp({super.key});
  @override
  State<SifreKasamApp> createState() => _SifreKasamAppState();
}

class _SifreKasamAppState extends State<SifreKasamApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      AppLock.instance.onBackground();
    } else if (state == AppLifecycleState.resumed) {
      AppLock.instance.onForeground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => _app(),
    );
  }

  Widget _app() {
    return MaterialApp(
      title: 'Şifre Kasam',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppLock.instance.navigatorKey,
      theme: AppTheme.build(Brightness.light),
      darkTheme: AppTheme.build(Brightness.dark),
      themeMode: ThemeController.instance.mode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Uygulama her açılışta önce kilit ekranıyla başlar.
      onGenerateInitialRoutes: (_) => [
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        AppLock.instance.createLockRoute(),
      ],
      onGenerateRoute: (_) =>
          MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }
}
