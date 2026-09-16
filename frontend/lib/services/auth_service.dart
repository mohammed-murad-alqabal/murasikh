import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart'; // To get baseUrl

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final String _authUrl = '${ApiService.baseUrl}/auth';

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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('username', username);
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'فشل تسجيل الدخول';
      }
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

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('username', username);
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        return data['detail'] ?? 'فشل التسجيل';
      }
    } catch (e) {
      return 'تعذر الاتصال بالخادم';
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('username');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('jwt_token');
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }
}
