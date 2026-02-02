import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';

class AuthProvider extends ChangeNotifier {
  final MockDataService _dataService = MockDataService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;

  Future<bool> login(String teamName, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));

    final user = _dataService.login(teamName, password);

    _isLoading = false;

    if (user != null) {
      _currentUser = user;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'اسم الفريق أو كلمة المرور غير صحيحة';
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _dataService.logout();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
