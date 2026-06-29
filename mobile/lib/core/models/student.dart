class Student {
  final int id;
  final String? codigoEstudiante;
  final String nombres;
  final String apellidos;
  final DateTime? fechaNacimiento;
  final int? seccionId;
  final bool consentimientoFirmado;
  final int nivelLectura;
  final int nivelFonologia;
  final bool activo;

  const Student({
    required this.id,
    this.codigoEstudiante,
    required this.nombres,
    required this.apellidos,
    required this.fechaNacimiento,
    required this.seccionId,
    this.consentimientoFirmado = false,
    this.nivelLectura = 1,
    this.nivelFonologia = 1,
    required this.activo,
  });

  String get nombreCompleto {
    return '$nombres $apellidos'.trim();
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: _asInt(json['id']),
      codigoEstudiante: json['codigo_estudiante']?.toString(),
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      fechaNacimiento: _asDateTime(json['fecha_nacimiento']),
      seccionId: _asNullableInt(json['seccion_id']),
      consentimientoFirmado: _asBool(
        json['consentimiento_firmado'],
        defaultValue: false,
      ),
      nivelLectura: _asIntWithDefault(json['nivel_lectura'], 1),
      nivelFonologia: _asIntWithDefault(json['nivel_fonologia'], 1),
      activo: _asBool(json['activo'], defaultValue: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codigo_estudiante': codigoEstudiante,
      'nombres': nombres,
      'apellidos': apellidos,
      'fecha_nacimiento': fechaNacimiento?.toIso8601String().split('T').first,
      'seccion_id': seccionId,
      'consentimiento_firmado': consentimientoFirmado,
      'nivel_lectura': nivelLectura,
      'nivel_fonologia': nivelFonologia,
      'activo': activo,
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _asIntWithDefault(dynamic value, int defaultValue) {
    final parsed = _asNullableInt(value);

    return parsed ?? defaultValue;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  static bool _asBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;

    final normalized = value?.toString().trim().toLowerCase();

    if (normalized == 'true' || normalized == '1' || normalized == 'si') {
      return true;
    }

    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }

    return defaultValue;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }
}
