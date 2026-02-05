import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  StorageService? _storageService;

  UserModel? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null && _accessToken != null;
  ApiService get apiService => _apiService;

  // Initialize and check for saved auth data
  Future<bool> init() async {
    if (_isInitialized) return isLoggedIn;

    _storageService = await StorageService.getInstance();

    final savedToken = _storageService?.getAccessToken();
    final savedUser = _storageService?.getUser();

    if (savedToken != null && savedUser != null) {
      _accessToken = savedToken;
      _refreshToken = _storageService?.getRefreshToken();
      _currentUser = savedUser;
      _apiService.setAccessToken(savedToken);
      _isInitialized = true;
      notifyListeners();
      return true;
    }

    _isInitialized = true;
    notifyListeners();
    return false;
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.pickerLogin(phone, password);
      _currentUser = response.user;
      _accessToken = response.accessToken;
      _refreshToken = response.refreshToken;

      // Save to storage for auto login
      _storageService ??= await StorageService.getInstance();
      await _storageService?.saveAuthData(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        user: response.user,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل الاتصال بالخادم. تحقق من اتصال الإنترنت';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _storageService ??= await StorageService.getInstance();
    await _storageService?.clearAuthData();

    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _apiService.setAccessToken(null);
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
