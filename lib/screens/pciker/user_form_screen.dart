import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../constants/app_colors.dart';
import '../../providers/users_provider.dart';
import '../../models/user_model.dart';

class UserFormScreen extends StatefulWidget {
  final UserModel? user;

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _teamNameController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _selectedRole = UserRole.picker;
  bool _isActive = true;
  bool _obscurePassword = true;
  bool _isSaving = false;

  bool get isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _nameController.text = widget.user!.name;
      _teamNameController.text = widget.user!.teamName;
      _passwordController.text = widget.user!.password;
      _selectedRole = widget.user!.role;
      _isActive = widget.user!.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teamNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final usersProvider = context.read<UsersProvider>();

    if (isEditing) {
      final updatedUser = widget.user!.copyWith(
        name: _nameController.text.trim(),
        teamName: _teamNameController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        isActive: _isActive,
      );
      await usersProvider.updateUser(updatedUser);
    } else {
      await usersProvider.addUser(
        name: _nameController.text.trim(),
        teamName: _teamNameController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
        isActive: _isActive,
      );
    }

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? S.userUpdatedSuccess : S.userAddedSuccess,
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? S.editUser : S.addNewUser),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: S.name,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return S.pleaseEnterName;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _teamNameController,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: S.teamNameForLogin,
                  prefixIcon: const Icon(Icons.groups_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return S.pleaseEnterTeamName;
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
                  labelText: S.password,
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
                    return S.pleaseEnterPassword;
                  }
                  if (value.length < 6) {
                    return S.passwordMin6;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                value: _selectedRole,
                decoration: InputDecoration(
                  labelText: S.userType,
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                items: [
                  DropdownMenuItem(
                    value: UserRole.picker,
                    child: Text(S.picker),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(S.status),
                subtitle: Text(_isActive ? S.active : S.suspended),
                value: _isActive,
                onChanged: (value) {
                  setState(() => _isActive = value);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? S.saveChanges : S.addUser,
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
