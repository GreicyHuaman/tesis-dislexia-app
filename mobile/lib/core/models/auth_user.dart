class AuthUser {
  final int id;
  final String nombres;
  final String apellidos;
  final String email;
  final String rol;
  final int? gradoScope;

  const AuthUser({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.email,
    required this.rol,
    required this.gradoScope,
  });

  String get nombreCompleto {
    return '$nombres $apellidos'.trim();
  }

  String get rolTexto {
    final normalized = rol.toUpperCase();

    if (normalized == 'MAESTRO') return 'Maestro';
    if (normalized == 'PSICOLOGA') return 'Psicóloga';
    if (normalized == 'DIRECTORA') return 'Directora';

    return rol;
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: _asInt(json['id']),
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      rol: json['rol']?.toString() ?? '',
      gradoScope: _asNullableInt(json['grado_scope']),
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
}
