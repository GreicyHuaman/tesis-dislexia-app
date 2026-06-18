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

  Future<StudentCacheRefreshResult> refreshOfflineCache() async {
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

      final uri = Uri.parse('$baseUrl/api/v1/estudiantes/offline-cache');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 15),
          );

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
