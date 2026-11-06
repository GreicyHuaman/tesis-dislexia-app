import 'dart:convert';

const seguimientoObservationCategories = [
  'Refuerzo pedagógico',
  'Reevaluación',
  'Coordinación con familia',
  'Seguimiento general',
  'Otro',
];

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

  String get estadoSemanalTexto => switch (estadoSemanal.toUpperCase()) {
    'SIN_EVALUACION' => 'Sin evaluación',
    'AL_DIA' => 'Al día',
    'VENCE_HOY' => 'Vence hoy',
    'VENCIDA' => 'Vencida',
    _ => estadoSemanal,
  };

  String get tendenciaTexto => switch (tendencia.toUpperCase()) {
    'MEJORA' => 'Mejora',
    'ESTABLE' => 'Estable',
    'EMPEORA' => 'Empeora',
    'SIN_HISTORIAL' => 'Sin historial',
    _ => tendencia,
  };
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

class SeguimientoObservacion {
  final int id;
  final int estudianteId;
  final int? evaluacionId;
  final String fechaSeguimiento;
  final String? semanaIso;
  final double? porcentajeRiesgo;
  final String? semaforo;
  final String? prioridad;
  final String? tendencia;
  final String? accionSugerida;
  final String? proximaEvaluacion;
  final String? observacionDocente;
  final String? categoriasJson;
  final String estado;
  final int? responsableId;
  final String? responsableNombre;
  final String? responsableCargo;

  const SeguimientoObservacion({
    required this.id,
    required this.estudianteId,
    required this.evaluacionId,
    required this.fechaSeguimiento,
    required this.semanaIso,
    required this.porcentajeRiesgo,
    required this.semaforo,
    required this.prioridad,
    required this.tendencia,
    required this.accionSugerida,
    required this.proximaEvaluacion,
    required this.observacionDocente,
    required this.categoriasJson,
    required this.estado,
    required this.responsableId,
    required this.responsableNombre,
    required this.responsableCargo,
  });

  factory SeguimientoObservacion.fromJson(Map<String, dynamic> json) {
    return SeguimientoObservacion(
      id: _asInt(json['id']),
      estudianteId: _asInt(json['estudiante_id']),
      evaluacionId: _asNullableInt(json['evaluacion_id']),
      fechaSeguimiento: json['fecha_seguimiento']?.toString() ?? '',
      semanaIso: json['semana_iso']?.toString(),
      porcentajeRiesgo: _asNullableDouble(json['porcentaje_riesgo']),
      semaforo: json['semaforo']?.toString(),
      prioridad: json['prioridad']?.toString(),
      tendencia: json['tendencia']?.toString(),
      accionSugerida: json['accion_sugerida']?.toString(),
      proximaEvaluacion: json['proxima_evaluacion']?.toString(),
      observacionDocente: json['observacion_docente']?.toString(),
      categoriasJson: json['categorias_json']?.toString(),
      estado: json['estado']?.toString() ?? 'ABIERTO',
      responsableId: _asNullableInt(json['responsable_id']),
      responsableNombre: json['responsable_nombre']?.toString(),
      responsableCargo: json['responsable_cargo']?.toString(),
    );
  }

  List<String> get categorias => _decodeCategoriasSeguimiento(categoriasJson);
}

class SeguimientoHistorial {
  final int estudianteId;
  final String estudianteNombre;
  final int? seccionId;
  final SeguimientoItem actual;
  final List<SeguimientoObservacion> observaciones;

  const SeguimientoHistorial({
    required this.estudianteId,
    required this.estudianteNombre,
    required this.seccionId,
    required this.actual,
    required this.observaciones,
  });

  factory SeguimientoHistorial.fromJson(Map<String, dynamic> json) {
    final actualRaw = json['actual'];

    if (actualRaw is! Map) {
      throw const FormatException('Respuesta sin seguimiento actual.');
    }

    final observacionesRaw = json['observaciones'];

    return SeguimientoHistorial(
      estudianteId: _asInt(json['estudiante_id']),
      estudianteNombre: json['estudiante_nombre']?.toString() ?? '',
      seccionId: _asNullableInt(json['seccion_id']),
      actual: SeguimientoItem.fromJson(
        actualRaw.map((key, dynamic value) => MapEntry(key.toString(), value)),
      ),
      observaciones: observacionesRaw is List
          ? observacionesRaw
                .whereType<Map>()
                .map(
                  (item) => SeguimientoObservacion.fromJson(
                    item.map(
                      (key, dynamic value) => MapEntry(key.toString(), value),
                    ),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

List<String> _decodeCategoriasSeguimiento(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }

  try {
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList();
    }
  } catch (_) {
    return const [];
  }

  return const [];
}
