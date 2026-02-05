import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';

  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // ==================== Access Token ====================

  Future<void> saveAccessToken(String token) async {
    await _prefs?.setString(_accessTokenKey, token);
  }

  String? getAccessToken() {
    return _prefs?.getString(_accessTokenKey);
  }

  // ==================== Refresh Token ====================

  Future<void> saveRefreshToken(String token) async {
    await _prefs?.setString(_refreshTokenKey, token);
  }

  String? getRefreshToken() {
    return _prefs?.getString(_refreshTokenKey);
  }

  // ==================== User Data ====================

  Future<void> saveUser(UserModel user) async {
    final userJson = jsonEncode(user.toJson());
    await _prefs?.setString(_userKey, userJson);
  }

  UserModel? getUser() {
    final userJson = _prefs?.getString(_userKey);
    if (userJson == null) return null;

    try {
      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      return UserModel.fromJson(userData);
    } catch (e) {
      return null;
    }
  }

  // ==================== Auth Data ====================

  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required UserModel user,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      saveUser(user),
    ]);
  }

  bool hasAuthData() {
    return getAccessToken() != null && getUser() != null;
  }

  // ==================== Clear ====================

  Future<void> clearAuthData() async {
    await Future.wait([
      _prefs?.remove(_accessTokenKey) ?? Future.value(),
      _prefs?.remove(_refreshTokenKey) ?? Future.value(),
      _prefs?.remove(_userKey) ?? Future.value(),
    ]);
  }

  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
