import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/student.dart';

class LocalStudentCache {
  static const String _studentsByPinBoxName = 'students_by_pin';

  static Future<void> init() async {
    await Hive.openBox(_studentsByPinBoxName);
  }

  static Box get _studentsByPinBox => Hive.box(_studentsByPinBoxName);

  static Future<void> saveStudentByPin({
    required String pin,
    required Student student,
  }) async {
    final cleanPin = pin.trim();
    final now = DateTime.now().toUtc().toIso8601String();

    if (cleanPin.length != 4) {
      return;
    }

    if (!student.activo || !student.consentimientoFirmado) {
      return;
    }

    final payload = {
      'pin_corto': cleanPin,
      'id': student.id,
      'codigo_estudiante': student.codigoEstudiante,
      'nombres': student.nombres,
      'apellidos': student.apellidos,
      'fecha_nacimiento': student.fechaNacimiento
          ?.toIso8601String()
          .split('T')
          .first,
      'seccion_id': student.seccionId,
      'consentimiento_firmado': student.consentimientoFirmado,
      'nivel_lectura': student.nivelLectura,
      'nivel_fonologia': student.nivelFonologia,
      'activo': student.activo,
      'cached_at': now,
    };

    await _studentsByPinBox.put(cleanPin, payload);
  }

  static Future<int> saveStudentsFromOfflinePayload(
    List<dynamic> rawStudents,
  ) async {
    var saved = 0;

    for (final rawStudent in rawStudents) {
      if (rawStudent is! Map) {
        continue;
      }

      final map = rawStudent.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );

      final pin = map['pin_corto']?.toString().trim();

      if (pin == null || pin.length != 4) {
        continue;
      }

      final student = Student.fromJson(map);

      if (!student.activo || !student.consentimientoFirmado) {
        continue;
      }

      await saveStudentByPin(pin: pin, student: student);

      saved++;
    }

    return saved;
  }

  static Student? findByPin(String pin) {
    final cleanPin = pin.trim();
    final value = _studentsByPinBox.get(cleanPin);
    final map = _asStringMap(value);

    if (map.isEmpty) {
      return null;
    }

    final student = Student.fromJson(map);

    if (!student.activo || !student.consentimientoFirmado) {
      return null;
    }

    return student;
  }

  static Student? findByPinForSection({
    required String pin,
    required int seccionId,
  }) {
    final student = findByPin(pin);

    if (student == null) {
      return null;
    }

    if (student.seccionId != seccionId) {
      return null;
    }

    return student;
  }

  static int countCachedStudents() {
    return _studentsByPinBox.length;
  }

  static String exportDebugJson() {
    final values = _studentsByPinBox.values.map(_asStringMap).toList();

    return const JsonEncoder.withIndent('  ').convert(values);
  }

  static Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }

    return {};
  }
}
