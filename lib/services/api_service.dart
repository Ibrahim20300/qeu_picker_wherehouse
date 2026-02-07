import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/picker_model.dart';
import 'api_endpoints.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserModel user;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });
}

class ApiService {
  final http.Client _client;
  String? _accessToken;
  String _language = 'ar';

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  String get language => _language;

  void setLanguage(String lang) {
    _language = lang;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Accept-Language': _language,
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      final message = body['message'] ?? body['error'] ?? 'حدث خطأ غير متوقع';
      throw ApiException(message, statusCode: response.statusCode);
    }
  }

  // ==================== Generic ====================

  Future<Map<String, dynamic>> getRequest(String endpoint) async {
    final response = await _client.get(
      ApiEndpoints.uri(endpoint),
      headers: _headers,
    );
    return await _handleResponse(response);
  }

  // ==================== Picker Auth ====================

  Future<LoginResponse> pickerLogin(String phone, String password) async {
    final response = await _client.post(

      
      ApiEndpoints.uri(ApiEndpoints.pickerLogin),
      headers: _headers,
      body: jsonEncode({
        'phone': phone,
        'password': password,
      }),
    );

    final data = await _handleResponse(response);

    // Check state
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

    // Store access token for future requests
    _accessToken = data['access_token'];

    return LoginResponse(
      accessToken: data['access_token'] ?? '',
      refreshToken: data['refresh_token'] ?? '',
      expiresIn: int.tryParse(data['expires_in']?.toString() ?? '0') ?? 0,
      user: user,
    );
  }

  // ==================== Picking Tasks ====================

  Future<List<dynamic>> getPickingTasks() async {
    final response = await _client.get(
      ApiEndpoints.uri(ApiEndpoints.pickingTasks),
      headers: _headers,
    );

    final data = await _handleResponse(response);

    // Return tasks list - adjust based on actual response structure
    if (data['tasks'] != null) {
      return data['tasks'] as List<dynamic>;
    } else if (data['data'] != null) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<void> startPickingTask(String taskId) async {
    final response = await _client.post(
      ApiEndpoints.uri(ApiEndpoints.startPickingTask(taskId)),
      headers: _headers,
      body: jsonEncode({}),
    );

    await _handleResponse(response);
  }

  Future<Map<String, dynamic>> getTaskDetails(String taskId) async {
    final response = await _client.get(
      ApiEndpoints.uri(ApiEndpoints.taskDetails(taskId)),
      headers: _headers,
    );

    return await _handleResponse(response);
  }

  // ==================== Picking Submission ====================

  Future<Map<String, dynamic>> scanTaskItem(String taskId, String barcode, int quantity) async {
    final response = await _client.post(
      ApiEndpoints.uri(ApiEndpoints.scanTask(taskId)),
      headers: _headers,
      body: jsonEncode({
        'barcode': barcode,
        'quantity': quantity,
      }),
    );

    return await _handleResponse(response);
  }

  Future<Map<String, dynamic>> completeTask(String taskId, int packageCount) async {
    final response = await _client.post(
      ApiEndpoints.uri(ApiEndpoints.completeTask(taskId)),
      headers: _headers,
      body: jsonEncode({'package_count': packageCount}),
    );

    return await _handleResponse(response);
  }

  // ==================== Item Exception ====================

  Future<Map<String, dynamic>> reportItemException(
    String taskId,
    String itemId, {
    required String exceptionType,
    required int quantity,
    String? note,
  }) async {
    final response = await _client.post(
      ApiEndpoints.uri(ApiEndpoints.itemException(taskId, itemId)),
      headers: _headers,
      body: jsonEncode({
        'exceptionType': exceptionType,
        'quantity': quantity,
        if (note != null && note.isNotEmpty) 'note': note,
      }),
    );

    return await _handleResponse(response);
  }

  // ==================== Picker Profile ====================

  Future<PickerModel> getMe() async {
    final response = await _client.get(
      ApiEndpoints.uri(ApiEndpoints.pickerMe),
      headers: _headers,
    );

    final data = await _handleResponse(response);

    // Response is the picker object directly
    return PickerModel.fromJson(data);
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

  void dispose() {
    _client.close();
  }
}
