import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/student.dart';
import '../repositories/local_student_cache.dart';

class StudentLookupResult {
  final bool success;
  final Student? student;
  final String message;
  final bool fromCache;

  const StudentLookupResult({
    required this.success,
    required this.student,
    required this.message,
    this.fromCache = false,
  });
}

class StudentCacheRefreshResult {
  final bool success;
  final int savedStudents;
  final String message;

  const StudentCacheRefreshResult({
    required this.success,
    required this.savedStudents,
    required this.message,
  });
}

class _StaffLoginResult {
  final bool success;
  final String? token;
  final String message;

  const _StaffLoginResult({
    required this.success,
    required this.token,
    required this.message,
  });
}

class StudentService {
  final String baseUrl;

  const StudentService({
    this.baseUrl = 'http://127.0.0.1:8000',
  });

  Future<StudentLookupResult> findByPin(String pin) async {
    final cleanPin = pin.trim();

    if (cleanPin.length != 4 || int.tryParse(cleanPin) == null) {
      return const StudentLookupResult(
        success: false,
        student: null,
        message: 'Ingresa un PIN válido de 4 dígitos.',
      );
    }

    try {
      final healthOk = await _checkBackendHealth();

      if (!healthOk) {
        return _findCachedStudent(cleanPin);
      }

      final uri = Uri.parse('$baseUrl/api/v1/estudiantes/pin/$cleanPin');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 403) {
        return const StudentLookupResult(
          success: false,
          student: null,
          message:
              'El estudiante no tiene autorización activa. No puede iniciar evaluación.',
        );
      }

      if (response.statusCode == 404) {
        return const StudentLookupResult(
          success: false,
          student: null,
          message: 'No se encontró estudiante activo con ese PIN.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return StudentLookupResult(
          success: false,
          student: null,
          message: 'Error del servidor: ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final student = Student.fromJson(decoded);

      await LocalStudentCache.saveStudentByPin(
        pin: cleanPin,
        student: student,
      );

      return StudentLookupResult(
        success: true,
        student: student,
        message:
            'Estudiante encontrado: ${student.nombreCompleto}. Guardado en caché local.',
      );
    } on TimeoutException {
      return _findCachedStudent(cleanPin);
    } catch (_) {
      return _findCachedStudent(cleanPin);
    }
  }

  Future<StudentCacheRefreshResult> refreshOfflineCache({
    String? staffEmail,
    String? staffPassword,
  }) async {
    try {
      final healthOk = await _checkBackendHealth();

      if (!healthOk) {
        return const StudentCacheRefreshResult(
          success: false,
          savedStudents: 0,
          message:
              'No se pudo descargar el padrón porque el backend no está disponible.',
        );
      }

      final loginResult = await _loginStaffForOfflineCache(
        email: staffEmail,
        password: staffPassword,
      );

      if (!loginResult.success || loginResult.token == null) {
        return StudentCacheRefreshResult(
          success: false,
          savedStudents: 0,
          message: loginResult.message,
        );
      }

      final uri = Uri.parse('$baseUrl/api/v1/estudiantes/offline-cache');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${loginResult.token}',
        },
      ).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        return const StudentCacheRefreshResult(
          success: false,
          savedStudents: 0,
          message:
              'No autorizado. Ingresa credenciales de personal académico autorizado.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return StudentCacheRefreshResult(
          success: false,
          savedStudents: 0,
          message: 'Error del servidor: ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        return const StudentCacheRefreshResult(
          success: false,
          savedStudents: 0,
          message: 'Formato inesperado del padrón offline.',
        );
      }

      final saved = await LocalStudentCache.saveStudentsFromOfflinePayload(
        decoded,
      );

      return StudentCacheRefreshResult(
        success: true,
        savedStudents: saved,
        message: 'Padrón descargado. Estudiantes guardados: $saved.',
      );
    } on TimeoutException {
      return const StudentCacheRefreshResult(
        success: false,
        savedStudents: 0,
        message: 'Tiempo de espera agotado descargando el padrón.',
      );
    } catch (error) {
      return StudentCacheRefreshResult(
        success: false,
        savedStudents: 0,
        message: 'Error descargando padrón offline: $error',
      );
    }
  }

  Future<_StaffLoginResult> _loginStaffForOfflineCache({
    String? email,
    String? password,
  }) async {
    final cleanEmail = email?.trim().toLowerCase() ?? '';
    final cleanPassword = password ?? '';

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return const _StaffLoginResult(
        success: false,
        token: null,
        message:
            'Para preparar el modo offline debes ingresar credenciales del personal académico.',
      );
    }

    try {
      final uri = Uri.parse('$baseUrl/api/v1/auth/login');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': cleanEmail,
              'password': cleanPassword,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 || response.statusCode == 403) {
        return const _StaffLoginResult(
          success: false,
          token: null,
          message: 'Credenciales académicas inválidas.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _StaffLoginResult(
          success: false,
          token: null,
          message: 'Error del servidor autenticando: ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final token = decoded['access_token']?.toString();

      if (token == null || token.trim().isEmpty) {
        return const _StaffLoginResult(
          success: false,
          token: null,
          message: 'El backend no devolvió token de autenticación.',
        );
      }

      final rawUser = decoded['user'];

      if (rawUser is Map) {
        final rol = rawUser['rol']?.toString().toUpperCase();

        if (!{'MAESTRO', 'PSICOLOGA', 'DIRECTORA'}.contains(rol)) {
          return const _StaffLoginResult(
            success: false,
            token: null,
            message:
                'El usuario autenticado no tiene permiso para preparar modo offline.',
          );
        }
      }

      return _StaffLoginResult(
        success: true,
        token: token,
        message: 'Personal académico autenticado.',
      );
    } on TimeoutException {
      return const _StaffLoginResult(
        success: false,
        token: null,
        message: 'Tiempo de espera agotado autenticando personal académico.',
      );
    } catch (error) {
      return _StaffLoginResult(
        success: false,
        token: null,
        message: 'Error autenticando personal académico: $error',
      );
    }
  }

  StudentLookupResult _findCachedStudent(String cleanPin) {
    final cachedStudent = LocalStudentCache.findByPin(cleanPin);

    if (cachedStudent == null) {
      return const StudentLookupResult(
        success: false,
        student: null,
        message:
            'El backend no está disponible y este PIN no existe en la caché local. Primero usa "Preparar modo offline" con backend activo.',
        fromCache: true,
      );
    }

    return StudentLookupResult(
      success: true,
      student: cachedStudent,
      message:
          'Modo offline: estudiante encontrado en caché local: ${cachedStudent.nombreCompleto}',
      fromCache: true,
    );
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
