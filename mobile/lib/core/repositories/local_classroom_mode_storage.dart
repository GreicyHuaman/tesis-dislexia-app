import 'package:hive_flutter/hive_flutter.dart';

import '../models/jornada_evaluacion.dart';

class ClassroomModeState {
  final int seccionId;
  final String sectionDisplayName;
  final int jornadaId;
  final DateTime fechaInicio;
  final DateTime? fechaExpiracion;
  final bool pruebaLecturaActiva;
  final bool pruebaFonologiaActiva;

  const ClassroomModeState({
    required this.seccionId,
    required this.sectionDisplayName,
    required this.jornadaId,
    required this.fechaInicio,
    required this.fechaExpiracion,
    required this.pruebaLecturaActiva,
    required this.pruebaFonologiaActiva,
  });

  bool get isExpired {
    final expiration = fechaExpiracion;

    if (expiration == null) return false;

    return expiration.isBefore(DateTime.now());
  }

  String get pinGuardContextKey {
    return 'student_pin_login_section_$seccionId';
  }

  factory ClassroomModeState.fromMap(Map<String, dynamic> map) {
    return ClassroomModeState(
      seccionId: _asInt(map['seccion_id']),
      sectionDisplayName: map['section_display_name']?.toString() ?? '',
      jornadaId: _asInt(map['jornada_id']),
      fechaInicio: _asDateTime(map['fecha_inicio']) ?? DateTime.now(),
      fechaExpiracion: _asDateTime(map['fecha_expiracion']),
      pruebaLecturaActiva: _asBool(
        map['prueba_lectura_activa'],
        defaultValue: true,
      ),
      pruebaFonologiaActiva: _asBool(
        map['prueba_fonologia_activa'],
        defaultValue: true,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'seccion_id': seccionId,
      'section_display_name': sectionDisplayName,
      'jornada_id': jornadaId,
      'fecha_inicio': fechaInicio.toUtc().toIso8601String(),
      'fecha_expiracion': fechaExpiracion?.toUtc().toIso8601String(),
      'prueba_lectura_activa': pruebaLecturaActiva,
      'prueba_fonologia_activa': pruebaFonologiaActiva,
    };
  }
}

class LocalClassroomModeStorage {
  static const String _boxName = 'classroom_mode';
  static const String _currentKey = 'current_classroom_mode';

  static Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox(_boxName);
    }

    return Hive.box(_boxName);
  }

  static Future<ClassroomModeState?> getCurrent() async {
    final box = await _box();
    final raw = box.get(_currentKey);

    if (raw is! Map) {
      return null;
    }

    final map = raw.map(
      (key, dynamic value) => MapEntry(key.toString(), value),
    );

    final state = ClassroomModeState.fromMap(map);

    if (state.isExpired) {
      await clear();
      return null;
    }

    return state;
  }

  static Future<void> saveFromJornada({
    required JornadaEvaluacion jornada,
    required String sectionDisplayName,
  }) async {
    final box = await _box();

    final state = ClassroomModeState(
      seccionId: jornada.seccionId,
      sectionDisplayName: sectionDisplayName,
      jornadaId: jornada.id,
      fechaInicio: jornada.fechaInicio,
      fechaExpiracion: jornada.fechaExpiracion,
      pruebaLecturaActiva: jornada.pruebaLecturaActiva,
      pruebaFonologiaActiva: jornada.pruebaFonologiaActiva,
    );

    await box.put(_currentKey, state.toMap());
    await box.flush();
  }

  static Future<void> clear() async {
    final box = await _box();
    await box.delete(_currentKey);
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;

  return DateTime.tryParse(value.toString())?.toLocal();
}

bool _asBool(dynamic value, {required bool defaultValue}) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final text = value?.toString().toLowerCase().trim();

  if (text == 'true' || text == '1' || text == 'si') return true;
  if (text == 'false' || text == '0' || text == 'no') return false;

  return defaultValue;
}
