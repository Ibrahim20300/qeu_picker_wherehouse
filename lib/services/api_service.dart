import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'api_endpoints.dart';
import '../l10n/app_localizations.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Callback when tokens are refreshed successfully.
typedef OnTokenRefreshed = void Function(String accessToken, String refreshToken);
/// Callback when refresh fails and user must re-login.
typedef OnAuthFailed = void Function();

class ApiService {
  final http.Client _client;
  String? _accessToken;
  String? _refreshToken;
  String _language = 'ar';
  String _appVersion = '';
  bool _isRefreshing = false;

  /// Set these callbacks from AuthProvider to persist new tokens / force logout.
  OnTokenRefreshed? onTokenRefreshed;
  OnAuthFailed? onAuthFailed;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  String get language => _language;

  void setLanguage(String lang) {
    _language = lang;
  }

  void setAppVersion(String version) {
    _appVersion = version;
  }

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (!kIsWeb) 'Accept-Language': _language,
    if (!kIsWeb && _appVersion.isNotEmpty) 'X-Qeu-App-Version': _appVersion,
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  void setRefreshToken(String? token) {
    _refreshToken = token;
  }

  Map<String, dynamic> handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      final message = body['message'] ?? body['error'] ?? S.unexpectedError;
      throw ApiException(message, statusCode: response.statusCode);
    }
  }

  // ==================== Token Refresh ====================

  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null || _isRefreshing) return false;

    _isRefreshing = true;
    try {
      final response = await _client.post(
        ApiEndpoints.uri(ApiEndpoints.refreshToken),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (!kIsWeb) 'Accept-Language': _language,
          if (!kIsWeb && _appVersion.isNotEmpty) 'X-Qeu-App-Version': _appVersion,
        },
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final newAccessToken = body['access_token']?.toString();
        final newRefreshToken = body['refresh_token']?.toString() ?? _refreshToken!;

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          _accessToken = newAccessToken;
          _refreshToken = newRefreshToken;
          onTokenRefreshed?.call(newAccessToken, newRefreshToken);
          return true;
        }
      }

      onAuthFailed?.call();
      return false;
    } catch (_) {
      onAuthFailed?.call();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // ==================== HTTP Methods ====================

  /// Authenticated GET — auto-retries once on 401 after refreshing token.
  Future<http.Response> get(String endpoint) async {
    final url = ApiEndpoints.uri(endpoint);
    var response = await _client.get(url, headers: headers);
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        response = await _client.get(url, headers: headers);
      }
    }
    return response;
  }

  /// Authenticated POST — auto-retries once on 401 after refreshing token.
  Future<http.Response> post(String endpoint, {Map<String, dynamic>? body}) async {
    final url = ApiEndpoints.uri(endpoint);
    final encodedBody = body != null ? jsonEncode(body) : null;
    var response = await _client.post(url, headers: headers, body: encodedBody);
    if (response.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        response = await _client.post(url, headers: headers, body: encodedBody);
      }
    }
    return response;
  }

  /// Unauthenticated POST — for login and similar endpoints.
  Future<http.Response> postNoAuth(String endpoint, {Map<String, dynamic>? body}) async {
    final url = ApiEndpoints.uri(endpoint);
    final encodedBody = body != null ? jsonEncode(body) : null;
    return await _client.post(url, headers: headers, body: encodedBody);
  }

  void dispose() {
    _client.close();
  }
}
