import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'local_account_scope.dart';

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
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final refreshToken = data['refresh_token']; // Read refresh_token

        await LocalAccountScope.activate(username);

        await _secureStorage.write(key: 'jwt_token', value: token);
        if (refreshToken != null) {
          await _secureStorage.write(key: 'refresh_token', value: refreshToken);
        } else {
          await _secureStorage.delete(key: 'refresh_token');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.remove('jwt_token');

        return null;
      }
      final data = jsonDecode(response.body);
      return data['detail'] ?? 'فشل تسجيل الدخول';
    } catch (e) {
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
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final refreshToken = data['refresh_token'];

        await LocalAccountScope.activate(username);

        await _secureStorage.write(key: 'jwt_token', value: token);
        if (refreshToken != null) {
          await _secureStorage.write(key: 'refresh_token', value: refreshToken);
        } else {
          await _secureStorage.delete(key: 'refresh_token');
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.remove('jwt_token');
        return null; // Success
      }
      final data = jsonDecode(response.body);
      return data['detail'] ?? 'فشل التسجيل';
    } catch (e) {
      return 'تعذر الاتصال بالخادم';
    }
  }

  Future<void> loginWithTokens(String token, String refreshToken) async {
    await _secureStorage.write(key: 'jwt_token', value: token);
    await _secureStorage.write(key: 'refresh_token', value: refreshToken);
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
      await LocalAccountScope.activate(null);
      await _secureStorage.delete(key: 'jwt_token');
      await _secureStorage.delete(key: 'refresh_token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('jwt_token');
    }
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
    return await _secureStorage.read(key: 'refresh_token');
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
