import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'constants/app_colors.dart';
import 'package:qeu_pickera/screens/pciker/picker_home_screen.dart';
import 'package:qeu_pickera/screens/qc/qc_home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/users_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/picker_provider.dart';
import 'providers/picking_provider.dart';
import 'providers/master_picker_provider.dart';
import 'providers/qc_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initAppVersion();
  }

  String _appVersion = '';

  Future<void> _initAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = info.version);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UsersProvider()),
        ChangeNotifierProvider(create: (_) => OrdersProvider()),
        ChangeNotifierProvider(create: (_) => PickerProvider()),
        ChangeNotifierProvider(create: (_) => PickingProvider()),
        ChangeNotifierProvider(create: (_) => MasterPickerProvider()),
        ChangeNotifierProvider(create: (_) => QCProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          // Sync language and app version to API headers
          final apiService = context.read<AuthProvider>().apiService;
          apiService.setLanguage(localeProvider.locale.languageCode);
          if (_appVersion.isNotEmpty) apiService.setAppVersion(_appVersion);
          return _AuthListener(
          child: MaterialApp(
            key: ValueKey(localeProvider.locale.languageCode),
            navigatorKey: navigatorKey,
            title: 'Q_Warehouse',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primary,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
              ),
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
          ),
        );
        },
      ),
    );
  }
}

/// Listens for forceLogout and redirects to LoginScreen.
class _AuthListener extends StatelessWidget {
  final Widget child;
  const _AuthListener({required this.child});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (authProvider.forceLogout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        authProvider.logout();
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      });
    }

    return child;
  }
}
