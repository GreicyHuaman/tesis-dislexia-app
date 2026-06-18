import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_user.dart';

class AuthLoginResult {
  final bool success;
  final AuthUser? user;
  final String message;

  const AuthLoginResult({
    required this.success,
    required this.user,
    required this.message,
  });
}

class AuthService {
  final String baseUrl;

  const AuthService({
    this.baseUrl = 'http://127.0.0.1:8000',
  });

  Future<AuthLoginResult> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || password.trim().isEmpty) {
      return const AuthLoginResult(
        success: false,
        user: null,
        message: 'Ingresa correo y contraseña.',
      );
    }

    try {
      final healthOk = await _checkBackendHealth();

      if (!healthOk) {
        return const AuthLoginResult(
          success: false,
          user: null,
          message: 'El backend no está disponible. Verifica Docker.',
        );
      }

      final uri = Uri.parse('$baseUrl/api/v1/auth/login');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email': cleanEmail,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        return const AuthLoginResult(
          success: false,
          user: null,
          message: 'Credenciales inválidas.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthLoginResult(
          success: false,
          user: null,
          message: 'Error del servidor: ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final user = AuthUser.fromJson(decoded);

      return AuthLoginResult(
        success: true,
        user: user,
        message: 'Bienvenido, ${user.nombreCompleto}',
      );
    } on TimeoutException {
      return const AuthLoginResult(
        success: false,
        user: null,
        message: 'Tiempo de espera agotado al iniciar sesión.',
      );
    } catch (error) {
      return AuthLoginResult(
        success: false,
        user: null,
        message: 'Error iniciando sesión: $error',
      );
    }
  }

  Future<bool> _checkBackendHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 5),
          );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
