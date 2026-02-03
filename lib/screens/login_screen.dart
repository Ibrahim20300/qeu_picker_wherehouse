import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _teamNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.login(
      _teamNameController.text.trim(),
      _passwordController.text,
    );

    // if (success && mounted) {
    //   _navigateToHome(authProvider.currentUser!);
    // } else if (mounted && authProvider.errorMessage != null) {
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(authProvider.errorMessage!),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    // }
  }

  // void _navigateToHome(UserModel user) {
  //   Widget homeScreen;
  //   switch (user.role) {
  //     case UserRole.supervisor:
  //       homeScreen = const SupervisorHomeScreen();
  //       break;
  //     case UserRole.picker:
  //       homeScreen = const PickerHomeScreen();
  //       break;
  //   }

  //   Navigator.pushReplacement(
  //     context,
  //     MaterialPageRoute(builder: (_) => homeScreen),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'QEU Picker',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'نظام إدارة المستودعات',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _teamNameController,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'اسم الفريق',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال اسم الفريق';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال كلمة المرور';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _login,
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  _buildTestCredentialsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestCredentialsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بيانات تجريبية للدخول:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          _buildTestCredential('سوبر فايزر', 'supervisor'),
          _buildTestCredential('بيكر', 'picker'),
          _buildTestCredential('مراقب جودة', 'qc'),
          const SizedBox(height: 4),
          Text(
            'كلمة المرور: 123456',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCredential(String role, String teamName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$role: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          Text(
            teamName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
            textDirection: TextDirection.ltr,
          ),
        ],
      ),
    );
  }
}
