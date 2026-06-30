class SeguimientoResumen {
  final int totalEstudiantes;
  final int sinEvaluacion;
  final int alDia;
  final int venceHoy;
  final int vencida;
  final int prioridadAlta;
  final int prioridadMedia;
  final int prioridadBaja;

  const SeguimientoResumen({
    required this.totalEstudiantes,
    required this.sinEvaluacion,
    required this.alDia,
    required this.venceHoy,
    required this.vencida,
    required this.prioridadAlta,
    required this.prioridadMedia,
    required this.prioridadBaja,
  });

  factory SeguimientoResumen.fromJson(Map<String, dynamic> json) {
    return SeguimientoResumen(
      totalEstudiantes: _asInt(json['total_estudiantes']),
      sinEvaluacion: _asInt(json['sin_evaluacion']),
      alDia: _asInt(json['al_dia']),
      venceHoy: _asInt(json['vence_hoy']),
      vencida: _asInt(json['vencida']),
      prioridadAlta: _asInt(json['prioridad_alta']),
      prioridadMedia: _asInt(json['prioridad_media']),
      prioridadBaja: _asInt(json['prioridad_baja']),
    );
  }
}

class SeguimientoItem {
  final int estudianteId;
  final String estudianteNombre;
  final int? seccionId;
  final int? seguimientoId;
  final int? evaluacionId;
  final String? ultimaFechaEvaluacion;
  final int? diasDesdeUltimaEvaluacion;
  final double? porcentajeRiesgo;
  final String? semaforo;
  final String estadoSemanal;
  final String prioridad;
  final String tendencia;
  final String accionSugerida;
  final String? proximaEvaluacion;
  final String? observacionDocente;
  final List<String> categorias;
  final String? estado;
  final String? responsableNombre;

  const SeguimientoItem({
    required this.estudianteId,
    required this.estudianteNombre,
    required this.seccionId,
    required this.seguimientoId,
    required this.evaluacionId,
    required this.ultimaFechaEvaluacion,
    required this.diasDesdeUltimaEvaluacion,
    required this.porcentajeRiesgo,
    required this.semaforo,
    required this.estadoSemanal,
    required this.prioridad,
    required this.tendencia,
    required this.accionSugerida,
    required this.proximaEvaluacion,
    required this.observacionDocente,
    required this.categorias,
    required this.estado,
    required this.responsableNombre,
  });

  factory SeguimientoItem.fromJson(Map<String, dynamic> json) {
    final rawCategorias = json['categorias'];

    return SeguimientoItem(
      estudianteId: _asInt(json['estudiante_id']),
      estudianteNombre: json['estudiante_nombre']?.toString() ?? '',
      seccionId: _asNullableInt(json['seccion_id']),
      seguimientoId: _asNullableInt(json['seguimiento_id']),
      evaluacionId: _asNullableInt(json['evaluacion_id']),
      ultimaFechaEvaluacion: json['ultima_fecha_evaluacion']?.toString(),
      diasDesdeUltimaEvaluacion: _asNullableInt(
        json['dias_desde_ultima_evaluacion'],
      ),
      porcentajeRiesgo: _asNullableDouble(json['porcentaje_riesgo']),
      semaforo: json['semaforo']?.toString(),
      estadoSemanal: json['estado_semanal']?.toString() ?? 'SIN_EVALUACION',
      prioridad: json['prioridad']?.toString() ?? 'BAJA',
      tendencia: json['tendencia']?.toString() ?? 'SIN_HISTORIAL',
      accionSugerida: json['accion_sugerida']?.toString() ?? '',
      proximaEvaluacion: json['proxima_evaluacion']?.toString(),
      observacionDocente: json['observacion_docente']?.toString(),
      categorias: rawCategorias is List
          ? rawCategorias.map((item) => item.toString()).toList()
          : const [],
      estado: json['estado']?.toString(),
      responsableNombre: json['responsable_nombre']?.toString(),
    );
  }

  bool get prioridadAlta => prioridad.toUpperCase() == 'ALTA';
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

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();

  return double.tryParse(value.toString());
}
