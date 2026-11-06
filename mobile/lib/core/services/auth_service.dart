import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_user.dart';
import 'connection_errors.dart';

class AuthLoginResult {
  final bool success;
  final AuthUser? user;
  final String message;
  final int expiresInMinutes;

  const AuthLoginResult({
    required this.success,
    required this.user,
    required this.message,
    required this.expiresInMinutes,
  });
}

class AuthService {
  final String baseUrl;

  const AuthService({
    this.baseUrl = 'https://tesis-dislexia-app-production.up.railway.app',
  });

  Future<AuthLoginResult> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || password.isEmpty) {
      return const AuthLoginResult(
        success: false,
        user: null,
        message: 'Ingresa correo y contraseña.',
        expiresInMinutes: 0,
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/login');

      final response = await runNetworkRequest(
        () => http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({'email': cleanEmail, 'password': password}),
            )
            .timeout(const Duration(seconds: 15)),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        return const AuthLoginResult(
          success: false,
          user: null,
          message: 'Credenciales inválidas.',
          expiresInMinutes: 0,
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw httpRequestFailure(
          response.statusCode,
          fallbackMessage: 'No se pudo iniciar sesión. Vuelva a intentarlo.',
        );
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final user = AuthUser.fromJson(decoded);

      if (!user.hasAccessToken) {
        throw const FormatException('Respuesta de autenticación sin token.');
      }

      final expiresIn = _asInt(decoded['expires_in_minutes']);

      return AuthLoginResult(
        success: true,
        user: user,
        message: 'Sesión iniciada correctamente.',
        expiresInMinutes: expiresIn <= 0 ? 480 : expiresIn,
      );
    } catch (error, stackTrace) {
      logRequestFailure('Inicio de sesión', error, stackTrace);
      return AuthLoginResult(
        success: false,
        user: null,
        message: requestErrorMessage(
          error,
          fallbackMessage: 'No se pudo iniciar sesión. Vuelva a intentarlo.',
        ),
        expiresInMinutes: 0,
      );
    }
  }

  Future<AuthUser?> fetchCurrentUser({required String accessToken}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/me');

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      return AuthUser.fromJson({...decoded, 'access_token': accessToken});
    } catch (_) {
      return null;
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
