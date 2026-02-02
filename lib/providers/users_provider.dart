import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';

class UsersProvider extends ChangeNotifier {
  final MockDataService _dataService = MockDataService();

  List<UserModel> _users = [];
  bool _isLoading = false;

  // Getters
  List<UserModel> get users => _users;
  List<UserModel> get pickers =>
      _users.where((u) => u.role == UserRole.picker).toList();
  bool get isLoading => _isLoading;

  void loadUsers() {
    _isLoading = true;
    notifyListeners();

    _users = _dataService.getPickers();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addUser({
    required String name,
    required String teamName,
    required String password,
    required UserRole role,
    bool isActive = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final newUser = UserModel(
      id: _dataService.generateUserId(),
      name: name,
      teamName: teamName,
      password: password,
      role: role,
      isActive: isActive,
    );

    _dataService.addUser(newUser);
    loadUsers();
  }

  Future<void> updateUser(UserModel user) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    _dataService.updateUser(user);
    loadUsers();
  }

  Future<void> deleteUser(String userId) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    _dataService.deleteUser(userId);
    loadUsers();
  }

  Future<void> toggleUserStatus(UserModel user) async {
    final updatedUser = user.copyWith(isActive: !user.isActive);
    await updateUser(updatedUser);
  }
}
