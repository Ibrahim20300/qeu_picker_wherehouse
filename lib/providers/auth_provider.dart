import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/picker_model.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';
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
  bool _forceLogout = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null && _accessToken != null;
  bool get forceLogout => _forceLogout;
  ApiService get apiService => _apiService;

  AuthProvider() {
    _apiService.onTokenRefreshed = _onTokenRefreshed;
    _apiService.onAuthFailed = _onAuthFailed;
  }

  /// Called by ApiService when tokens are refreshed successfully.
  void _onTokenRefreshed(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    _storageService ??= await StorageService.getInstance();
    await _storageService?.saveAccessToken(accessToken);
    await _storageService?.saveRefreshToken(refreshToken);
  }

  /// Called by ApiService when refresh token fails — forces logout.
  void _onAuthFailed() {
    _forceLogout = true;
    notifyListeners();
  }

  void clearForceLogout() {
    _forceLogout = false;
  }

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
      _apiService.setRefreshToken(_refreshToken);
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
      final response = await _apiService.postNoAuth(
        ApiEndpoints.pickerLogin,
        body: {'phone': phone, 'password': password},
      );

      final data = _apiService.handleResponse(response);

      if (data['state'] != 'SUCCESS') {
        throw ApiException(data['message'] ?? 'فشل تسجيل الدخول');
      }

      final picker = data['picker'] as Map<String, dynamic>;

      final user = UserModel(
        id: picker['id']?.toString() ?? '',
        name: picker['name'] ?? '',
        teamName: picker['employee_id'] ?? '',
        password: '',
        role: _parseRole(picker['role']),
        zone: picker['zone_name']?.toString().isNotEmpty == true
            ? picker['zone_name']
            : picker['zone_id'],
        isActive: picker['status'] == 'active',
        createdAt: picker['created_at'] != null
            ? DateTime.parse(picker['created_at'])
            : DateTime.now(),
      );

      _currentUser = user;
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];

      _apiService.setAccessToken(_accessToken);
      _apiService.setRefreshToken(_refreshToken);

      // Save to storage for auto login
      _storageService ??= await StorageService.getInstance();
      await _storageService?.saveAuthData(
        accessToken: _accessToken!,
        refreshToken: _refreshToken ?? '',
        user: user,
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

  Future<PickerModel> getMe() async {
    final response = await _apiService.get(ApiEndpoints.pickerMe);
    final data = _apiService.handleResponse(response);
    return PickerModel.fromJson(data);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final response = await _apiService.post(
      ApiEndpoints.changePassword,
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    final data = _apiService.handleResponse(response);
    if (data['success'] == false) {
      throw ApiException(data['message'] ?? 'فشل تغيير كلمة المرور');
    }
  }

  Future<void> logout() async {
    _storageService ??= await StorageService.getInstance();
    await _storageService?.clearAuthData();

    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _forceLogout = false;
    _apiService.setAccessToken(null);
    _apiService.setRefreshToken(null);
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  UserRole _parseRole(dynamic role) {
    if (role == null) return UserRole.picker;

    final roleStr = role.toString().toLowerCase();

    if (roleStr.contains('master_picker') || roleStr.contains('master')) {
      return UserRole.masterPicker;
    } else if (roleStr.contains('supervisor') || roleStr.contains('super')) {
      return UserRole.supervisor;
    } else if (roleStr.contains('qc') || roleStr.contains('quality')) {
      return UserRole.qc;
    } else {
      return UserRole.picker;
    }
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
