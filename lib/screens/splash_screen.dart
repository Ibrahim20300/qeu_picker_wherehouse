import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../constants/app_colors.dart';
import '../services/supabase_service.dart';
import 'login_screen.dart';
import 'pciker/picker_home_screen.dart';
import 'master_picker/master_picker_home_screen.dart';
import 'qc/qc_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Load app settings from Supabase in parallel with auth
    final authProvider = context.read<AuthProvider>();
    final results = await Future.wait([
      authProvider.init(),
      _loadAppSettings(),
    ]);

    if (!mounted) return;

    final isLoggedIn = results[0] as bool;
    final settings = results[1] as Map<String, String>;
    // Check maintenance mode
    if (settings['maintenance_mode'] == 'true') {
      _showMaintenanceDialog(settings['maintenance_message'] ?? '');
      return;
    }

    // Check minimum version
    final minVersion = settings['min_version'];
    if (minVersion != null && minVersion.isNotEmpty) {
      final info = await PackageInfo.fromPlatform();
      if (_isVersionLower(info.version, minVersion)) {
        if (!mounted) return;
        _showUpdateDialog(settings['apk_url'] ?? '');
        return;
      }
    }

    if (!mounted) return;

    Widget homeScreen;
    if (isLoggedIn) {
      final role = authProvider.currentUser?.role;
      switch (role) {
        case UserRole.masterPicker:
          homeScreen = const MasterPickerHomeScreen();
          break;
        case UserRole.qc:
          homeScreen = const QCHomeScreen();
          break;
        default:
          homeScreen = const PickerScreen();
      }
    } else {
      homeScreen = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => homeScreen),
    );
  }

  Future<Map<String, String>> _loadAppSettings() async {
    try {
      return await SupabaseService.fetchAppSettings();
    } catch (_) {
      return {};
    }
  }

  /// Compare semantic versions: returns true if [current] < [minimum].
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

  void _showMaintenanceDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.construction, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('صيانة'),
          ],
        ),
        content: Text(
          message.isNotEmpty ? message : 'التطبيق تحت الصيانة حالياً، يرجى المحاولة لاحقاً.',
        ),
      ),
    );
  }

  void _showUpdateDialog(String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update, color: AppColors.primary, size: 28),
              SizedBox(width: 8),
              Text('تحديث مطلوب'),
            ],
          ),
          content: const Text('يوجد إصدار جديد من التطبيق. يرجى التحديث للاستمرار.'),
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
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'QEU Picker',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
