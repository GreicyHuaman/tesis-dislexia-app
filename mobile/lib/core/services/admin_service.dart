import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/admin_models.dart';
import 'connection_errors.dart';

class AdminService {
  final String baseUrl;

  const AdminService({
    this.baseUrl = 'https://tesis-dislexia-app-production.up.railway.app',
  });

  Future<List<AdminStudent>> fetchStudents({required String? authToken}) async {
    final list = await _getList(
      path: '/api/v1/estudiantes/admin/list',
      authToken: authToken,
    );

    return list
        .whereType<Map>()
        .map(
          (item) => AdminStudent.fromJson(
            item.map((key, dynamic value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<AdminStudent> createStudent({
    required String? authToken,
    String? codigoEstudiante,
    required String nombres,
    required String apellidos,
    required String fechaNacimiento,
    required int seccionId,
    required bool consentimientoFirmado,
    String? fechaConsentimiento,
    bool activo = true,
  }) async {
    final json = await _postJson(
      path: '/api/v1/estudiantes',
      authToken: authToken,
      body: {
        'codigo_estudiante': codigoEstudiante,
        'nombres': nombres,
        'apellidos': apellidos,
        'fecha_nacimiento': fechaNacimiento,
        'seccion_id': seccionId,
        'consentimiento_firmado': consentimientoFirmado,
        'fecha_consentimiento': fechaConsentimiento,
        'activo': activo,
      },
    );

    return AdminStudent.fromJson(json);
  }

  Future<AdminStudent> updateStudent({
    required String? authToken,
    required int estudianteId,
    String? codigoEstudiante,
    required String nombres,
    required String apellidos,
    required String fechaNacimiento,
    int? seccionId,
    required bool consentimientoFirmado,
    String? fechaConsentimiento,
    required bool activo,
  }) async {
    final json = await _patchJson(
      path: '/api/v1/estudiantes/$estudianteId',
      authToken: authToken,
      body: {
        'codigo_estudiante': codigoEstudiante,
        'nombres': nombres,
        'apellidos': apellidos,
        'fecha_nacimiento': fechaNacimiento,
        'seccion_id': seccionId,
        'consentimiento_firmado': consentimientoFirmado,
        'fecha_consentimiento': fechaConsentimiento,
        'activo': activo,
      },
    );

    return AdminStudent.fromJson(json);
  }

  Future<AdminStudent> regenerateStudentPin({
    required String? authToken,
    required int estudianteId,
  }) async {
    final json = await _postJson(
      path: '/api/v1/estudiantes/$estudianteId/regenerar-pin',
      authToken: authToken,
      body: {},
    );

    return AdminStudent.fromJson(json);
  }

  Future<StudentImportResponse> importStudentsFile({
    required String? authToken,
    required String filePath,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/estudiantes/importar');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll(_multipartHeaders(authToken));
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
    );

    final response = await http.Response.fromStream(streamedResponse);

    _ensureSuccess(response);

    return StudentImportResponse.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<List<AdminSection>> fetchSections({required String? authToken}) async {
    final list = await _getList(
      path: '/api/v1/secciones',
      authToken: authToken,
    );

    return list
        .whereType<Map>()
        .map(
          (item) => AdminSection.fromJson(
            item.map((key, dynamic value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<AdminSection> createSection({
    required String? authToken,
    required String nombre,
    required String turno,
    bool activo = true,
  }) async {
    final json = await _postJson(
      path: '/api/v1/secciones',
      authToken: authToken,
      body: {'grado': 3, 'nombre': nombre, 'turno': turno, 'activo': activo},
    );

    return AdminSection.fromJson(json);
  }

  Future<AdminSection> updateSection({
    required String? authToken,
    required int seccionId,
    required String nombre,
    required String turno,
    required bool activo,
  }) async {
    final json = await _patchJson(
      path: '/api/v1/secciones/$seccionId',
      authToken: authToken,
      body: {'grado': 3, 'nombre': nombre, 'turno': turno, 'activo': activo},
    );

    return AdminSection.fromJson(json);
  }

  Future<List<AcademicUser>> fetchUsers({required String? authToken}) async {
    final list = await _getList(
      path: '/api/v1/admin/usuarios',
      authToken: authToken,
    );

    return list
        .whereType<Map>()
        .map(
          (item) => AcademicUser.fromJson(
            item.map((key, dynamic value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<AcademicUser> createUser({
    required String? authToken,
    required String nombres,
    required String apellidos,
    required String email,
    required String rol,
    required String password,
    int? gradoScope,
    bool activo = true,
  }) async {
    final json = await _postJson(
      path: '/api/v1/admin/usuarios',
      authToken: authToken,
      body: {
        'nombres': nombres,
        'apellidos': apellidos,
        'email': email,
        'rol': rol,
        'password': password,
        'grado_scope': gradoScope,
        'activo': activo,
      },
    );

    return AcademicUser.fromJson(json);
  }

  Future<AcademicUser> updateUser({
    required String? authToken,
    required int usuarioId,
    required String nombres,
    required String apellidos,
    required String email,
    required String rol,
    String? password,
    int? gradoScope,
    required bool activo,
  }) async {
    final body = {
      'nombres': nombres,
      'apellidos': apellidos,
      'email': email,
      'rol': rol,
      'grado_scope': gradoScope,
      'activo': activo,
    };

    if (password != null && password.trim().isNotEmpty) {
      body['password'] = password;
    }

    final json = await _patchJson(
      path: '/api/v1/admin/usuarios/$usuarioId',
      authToken: authToken,
      body: body,
    );

    return AcademicUser.fromJson(json);
  }

  Future<List<TeacherSectionLink>> fetchTeacherSectionLinks({
    required String? authToken,
  }) async {
    final list = await _getList(
      path: '/api/v1/admin/docente-seccion',
      authToken: authToken,
    );

    return list
        .whereType<Map>()
        .map(
          (item) => TeacherSectionLink.fromJson(
            item.map((key, dynamic value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<TeacherSectionLink> createTeacherSectionLink({
    required String? authToken,
    required int usuarioId,
    required int seccionId,
  }) async {
    final json = await _postJson(
      path: '/api/v1/admin/docente-seccion',
      authToken: authToken,
      body: {'usuario_id': usuarioId, 'seccion_id': seccionId},
    );

    return TeacherSectionLink.fromJson(json);
  }

  Future<void> deleteTeacherSectionLink({
    required String? authToken,
    required int linkId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/admin/docente-seccion/$linkId');

    final response = await http
        .delete(uri, headers: _headers(authToken))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);
  }

  Future<List<dynamic>> _getList({
    required String path,
    required String? authToken,
  }) async {
    final uri = Uri.parse('$baseUrl$path');

    final response = await http
        .get(uri, headers: _headers(authToken))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is List) {
      return decoded;
    }

    return [];
  }

  Future<Map<String, dynamic>> _postJson({
    required String path,
    required String? authToken,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final cleanBody = _withoutNulls(body);

    final response = await http
        .post(uri, headers: _headers(authToken), body: jsonEncode(cleanBody))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _patchJson({
    required String path,
    required String? authToken,
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final cleanBody = _withoutNulls(body);

    final response = await http
        .patch(uri, headers: _headers(authToken), body: jsonEncode(cleanBody))
        .timeout(const Duration(seconds: 15));

    _ensureSuccess(response);

    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Map<String, dynamic> _withoutNulls(Map<String, dynamic> input) {
    final output = Map<String, dynamic>.from(input);

    output.removeWhere((_, value) => value == null);

    return output;
  }

  Map<String, String> _multipartHeaders(String? authToken) {
    final token = authToken?.trim();

    if (token == null || token.isEmpty) {
      throw Exception('No existe token de sesión académica.');
    }

    return {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
  }

  Map<String, String> _headers(String? authToken) {
    final token = authToken?.trim();

    if (token == null || token.isEmpty) {
      throw Exception('No existe token de sesión académica.');
    }

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Error HTTP ${response.statusCode}.';

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {
      // Mantener mensaje generico.
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw RequestFailure(
        'Sesión no autorizada. $message',
        statusCode: response.statusCode,
      );
    }

    throw RequestFailure(message, statusCode: response.statusCode);
  }
}
