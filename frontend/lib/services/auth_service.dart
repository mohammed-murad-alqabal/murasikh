import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'local_account_scope.dart';
import 'notification_service.dart';
import 'settings_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final String _authUrl = '${ApiService.baseUrl}/auth';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String?> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_authUrl/login'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'username': username, 'password': password},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _storeSession(username, data);
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['detail']?.toString() ?? 'فشل تسجيل الدخول';
    } catch (_) {
      return 'تعذر الاتصال بالخادم';
    }
  }

  Future<String?> register(
    String username,
    String password, {
    String? email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_authUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
              'email': email,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await _storeSession(username, data);
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['detail']?.toString() ?? 'فشل التسجيل';
    } catch (_) {
      return 'تعذر الاتصال بالخادم';
    }
  }

  Future<void> loginWithTokens(String token, String refreshToken) async {
    final username = await getUsername() ?? '';
    await _storeSession(username, {
      'access_token': token,
      'refresh_token': refreshToken,
    });
  }

  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        try {
          await http
              .post(
                Uri.parse('$_authUrl/logout'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 5));
        } catch (_) {}
      }
    } finally {
      await _clearLocalSession();
    }
  }

  Future<String?> deleteAccount() async {
    final token = await getToken();
    if (token == null) return 'لا توجد جلسة مصادقة نشطة';

    try {
      final response = await http
          .delete(
            Uri.parse('$_authUrl/account'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return data['detail']?.toString() ?? 'تعذر حذف الحساب من الخادم';
        } catch (_) {
          return 'تعذر حذف الحساب من الخادم';
        }
      }

      await _clearLocalSession();
      return null;
    } catch (_) {
      return 'تعذر الاتصال بالخادم؛ لم يتم حذف الحساب';
    }
  }

  Future<void> _storeSession(
    String username,
    Map<String, dynamic> data,
  ) async {
    if (username.trim().isNotEmpty) {
      await LocalAccountScope.activate(username);
    }
    final accessToken = data['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Authentication response did not contain access_token');
    }
    await _secureStorage.write(
      key: 'jwt_token',
      value: accessToken,
    );
    final refreshToken = data['refresh_token']?.toString();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    } else {
      await _secureStorage.delete(key: 'refresh_token');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', username);
    await prefs.remove('jwt_token');
    await SettingsService().init();
    await NotificationService().init();
  }

  Future<void> _clearLocalSession() async {
    try {
      await NotificationService().clearStoredData();
    } catch (_) {}
    await LocalAccountScope.activate(null);
    await _secureStorage.delete(key: 'jwt_token');
    await _secureStorage.delete(key: 'refresh_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('jwt_token');
    await SettingsService().init();
  }

  Future<String?> getToken() async {
    String? token = await _secureStorage.read(key: 'jwt_token');

    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('jwt_token');
      if (token != null) {
        await _secureStorage.write(key: 'jwt_token', value: token);
        await prefs.remove('jwt_token');
      }
    }
    return token;
  }

  Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: 'refresh_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }
}
