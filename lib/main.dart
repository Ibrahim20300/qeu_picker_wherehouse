import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'services/api_endpoints.dart';
import 'services/supabase_service.dart';
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

Timer? _pickerStatusTimer;

void startPickerStatusTimer() {
  if (_pickerStatusTimer != null) return;
  _sendPickerStatus();
  _pickerStatusTimer = Timer.periodic(
    const Duration(seconds: 30),
    (_) => _sendPickerStatus(),
  );
}

Future<void> _sendPickerStatus() async {
  try {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final authProvider = ctx.read<AuthProvider>();
    if (!authProvider.isLoggedIn) return;

    final info = await DeviceInfoPlugin().androidInfo;
    final manufacturer = info.manufacturer.toLowerCase();
    String deviceType = '';
    if (manufacturer.contains('zebra')) {
      deviceType = 'Z';
    } else if (manufacturer.contains('honeywell')) {
      deviceType = 'H';
    }

    final packageInfo = await PackageInfo.fromPlatform();
    await authProvider.apiService.post(ApiEndpoints.pickerStatus, body: {
      'app_version': deviceType + packageInfo.version,
    });
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://wopknlncigglzzxbkcxy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndvcGtubG5jaWdnbHp6eGJrY3h5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4OTI4OTIsImV4cCI6MjA4NjQ2ODg5Mn0.WEnKXqPaz3a91tdO0Uqm_r2L80_KuB29oLn_a9RUKS4',
  );
  WakelockPlus.enable();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _appVersion = '';
  Timer? _settingsTimer;
  bool _isBlocked = false;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _initAppVersion();
    _settingsTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkRemoteSettings(),
    );
  }

  @override
  void dispose() {
    _settingsTimer?.cancel();
    super.dispose();
  }

  Future<void> _initAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _appVersion = info.version);
  }

  Future<void> _checkRemoteSettings() async {
    if (_isBlocked || !mounted) return;
    try {
      final settings = await SupabaseService.fetchAppSettings();
      if (!mounted) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;

      // Check maintenance
      if (settings['maintenance_mode'] == 'true') {
        _isBlocked = true;
        _showBlockingDialog(
          icon: Icons.construction,
          iconColor: Colors.orange,
          title: 'صيانة',
          message: settings['maintenance_message']?.isNotEmpty == true
              ? settings['maintenance_message']!
              : 'التطبيق تحت الصيانة حالياً، يرجى المحاولة لاحقاً.',
        );
        return;
      }

      // Check min version
      final minVersion = settings['min_version'];
      if (minVersion != null && minVersion.isNotEmpty && _appVersion.isNotEmpty) {
        if (_isVersionLower(_appVersion, minVersion)) {
          _isBlocked = true;
          _showBlockingDialog(
            icon: Icons.system_update,
            iconColor: AppColors.primary,
            title: 'تحديث مطلوب',
            message: 'يوجد إصدار جديد من التطبيق. يرجى التحديث للاستمرار.',
            apkUrl: settings['apk_url'] ?? '',
          );
        }
      }
    } catch (_) {}
  }

  bool _isVersionLower(String current, String minimum) {
    final cur = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final min = minimum.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      final c = i < cur.length ? cur[i] : 0;
      final m = i < min.length ? min[i] : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }

  void _showBlockingDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    String apkUrl = '',
  }) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            if (apkUrl.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(apkUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('تحميل التحديث'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
