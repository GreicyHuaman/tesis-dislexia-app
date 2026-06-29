class AdminStudent {
  final int id;
  final String nombres;
  final String apellidos;
  final String? fechaNacimiento;
  final String? pinCorto;
  final int? seccionId;
  final bool activo;

  const AdminStudent({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.fechaNacimiento,
    required this.pinCorto,
    required this.seccionId,
    required this.activo,
  });

  factory AdminStudent.fromJson(Map<String, dynamic> json) {
    return AdminStudent(
      id: _asInt(json['id']),
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      fechaNacimiento: json['fecha_nacimiento']?.toString(),
      pinCorto: json['pin_corto']?.toString(),
      seccionId: _asNullableInt(json['seccion_id']),
      activo: _asBool(json['activo'], defaultValue: true),
    );
  }

  String get nombreCompleto => '$nombres $apellidos'.trim();
}

class AdminSection {
  final int id;
  final int grado;
  final String nombre;
  final String? turno;
  final bool activo;

  const AdminSection({
    required this.id,
    required this.grado,
    required this.nombre,
    required this.turno,
    required this.activo,
  });

  factory AdminSection.fromJson(Map<String, dynamic> json) {
    return AdminSection(
      id: _asInt(json['id']),
      grado: _asInt(json['grado']),
      nombre: json['nombre']?.toString() ?? '',
      turno: json['turno']?.toString(),
      activo: _asBool(json['activo'], defaultValue: true),
    );
  }

  String get displayName => '$grado $nombre';
}

class AcademicUser {
  final int id;
  final String nombres;
  final String apellidos;
  final String email;
  final String rol;
  final int? gradoScope;
  final bool activo;

  const AcademicUser({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.email,
    required this.rol,
    required this.gradoScope,
    required this.activo,
  });

  factory AcademicUser.fromJson(Map<String, dynamic> json) {
    return AcademicUser(
      id: _asInt(json['id']),
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      rol: json['rol']?.toString() ?? '',
      gradoScope: _asNullableInt(json['grado_scope']),
      activo: _asBool(json['activo'], defaultValue: true),
    );
  }

  String get nombreCompleto => '$nombres $apellidos'.trim();

  String get rolTexto {
    final normalized = rol.toUpperCase();

    if (normalized == 'MAESTRO') return 'Maestro';
    if (normalized == 'PSICOLOGA') return 'Psicóloga';
    if (normalized == 'DIRECTORA') return 'Directora';

    return rol;
  }
}

class TeacherSectionLink {
  final int id;
  final int usuarioId;
  final int seccionId;

  const TeacherSectionLink({
    required this.id,
    required this.usuarioId,
    required this.seccionId,
  });

  factory TeacherSectionLink.fromJson(Map<String, dynamic> json) {
    return TeacherSectionLink(
      id: _asInt(json['id']),
      usuarioId: _asInt(json['usuario_id']),
      seccionId: _asInt(json['seccion_id']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value.toString());
}

bool _asBool(dynamic value, {required bool defaultValue}) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final text = value?.toString().toLowerCase();

  if (text == 'true') return true;
  if (text == 'false') return false;

  return defaultValue;
}
