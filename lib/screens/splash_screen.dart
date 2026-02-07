import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../constants/app_colors.dart';
import 'login_screen.dart';
import 'pciker/picker_home_screen.dart';
import 'master_picker/master_picker_home_screen.dart';

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
    final authProvider = context.read<AuthProvider>();
    final isLoggedIn = await authProvider.init();

    if (!mounted) return;

    Widget homeScreen;
    if (isLoggedIn) {
      final role = authProvider.currentUser?.role;
      homeScreen = role == UserRole.masterPicker
          ? const MasterPickerHomeScreen()
          : const PickerScreen();
    } else {
      homeScreen = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => homeScreen),
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
