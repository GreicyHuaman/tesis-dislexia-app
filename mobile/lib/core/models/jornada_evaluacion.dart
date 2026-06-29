class JornadaEvaluacion {
  final int id;
  final int seccionId;
  final int responsableId;
  final DateTime fechaInicio;
  final DateTime? fechaCierre;
  final DateTime? fechaExpiracion;
  final String estado;
  final bool pruebaLecturaActiva;
  final bool pruebaFonologiaActiva;

  const JornadaEvaluacion({
    required this.id,
    required this.seccionId,
    required this.responsableId,
    required this.fechaInicio,
    required this.fechaCierre,
    required this.fechaExpiracion,
    required this.estado,
    required this.pruebaLecturaActiva,
    required this.pruebaFonologiaActiva,
  });

  factory JornadaEvaluacion.fromJson(Map<String, dynamic> json) {
    return JornadaEvaluacion(
      id: _asInt(json['id']),
      seccionId: _asInt(json['seccion_id']),
      responsableId: _asInt(json['responsable_id']),
      fechaInicio: _asDateTime(json['fecha_inicio']) ?? DateTime.now(),
      fechaCierre: _asDateTime(json['fecha_cierre']),
      fechaExpiracion: _asDateTime(json['fecha_expiracion']),
      estado: json['estado']?.toString() ?? '',
      pruebaLecturaActiva: _asBool(
        json['prueba_lectura_activa'],
        defaultValue: true,
      ),
      pruebaFonologiaActiva: _asBool(
        json['prueba_fonologia_activa'],
        defaultValue: true,
      ),
    );
  }

  bool get estaActiva => estado.toUpperCase() == 'ACTIVA';

  bool get estaExpirada {
    final expiracion = fechaExpiracion;

    if (expiracion == null) return false;

    return expiracion.toLocal().isBefore(DateTime.now());
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
