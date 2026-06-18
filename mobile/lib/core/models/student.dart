class Student {
  final int id;
  final String nombres;
  final String apellidos;
  final DateTime? fechaNacimiento;
  final int? seccionId;
  final bool activo;

  const Student({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.fechaNacimiento,
    required this.seccionId,
    required this.activo,
  });

  String get nombreCompleto {
    return '$nombres $apellidos'.trim();
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: _asInt(json['id']),
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      fechaNacimiento: _asDateTime(json['fecha_nacimiento']),
      seccionId: _asNullableInt(json['seccion_id']),
      activo: json['activo'] == true,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }
}
