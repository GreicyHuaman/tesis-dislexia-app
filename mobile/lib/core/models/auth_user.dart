class AuthUser {
  final int id;
  final String nombres;
  final String apellidos;
  final String email;
  final String rol;
  final int? gradoScope;
  final bool activo;
  final String? accessToken;

  const AuthUser({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.email,
    required this.rol,
    required this.gradoScope,
    required this.activo,
    this.accessToken,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final source = rawUser is Map
        ? rawUser.map(
            (key, dynamic value) => MapEntry(key.toString(), value),
          )
        : json;

    return AuthUser(
      id: _asInt(source['id']),
      nombres: source['nombres']?.toString() ?? '',
      apellidos: source['apellidos']?.toString() ?? '',
      email: source['email']?.toString() ?? '',
      rol: source['rol']?.toString() ?? '',
      gradoScope: _asNullableInt(source['grado_scope']),
      activo: _asBool(source['activo'], defaultValue: true),
      accessToken: json['access_token']?.toString(),
    );
  }

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

  bool get hasAccessToken {
    return accessToken != null && accessToken!.trim().isNotEmpty;
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

bool _asBool(
  dynamic value, {
  required bool defaultValue,
}) {
  if (value is bool) return value;

  final text = value?.toString().toLowerCase().trim();

  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;

  return defaultValue;
}
