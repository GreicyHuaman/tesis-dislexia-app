class EvaluationReportItem {
  final int id;
  final int? estudianteId;
  final String? estudianteNombre;
  final int? seccionId;
  final DateTime fechaEvaluacion;
  final String? tipoPrueba;
  final int? totalItems;
  final int? aciertosPrimerIntento;
  final int? tapsErroneosTotales;
  final int? tiempoPromedioMs;
  final double? porcentajeRiesgo;
  final String? semaforo;

  final String? fuentePrediccion;
  final String? modeloNombre;
  final String? modeloVersion;
  final double? probabilidadVerde;
  final double? probabilidadAmarillo;
  final double? probabilidadRojo;

  const EvaluationReportItem({
    required this.id,
    required this.estudianteId,
    required this.estudianteNombre,
    required this.seccionId,
    required this.fechaEvaluacion,
    required this.tipoPrueba,
    required this.totalItems,
    required this.aciertosPrimerIntento,
    required this.tapsErroneosTotales,
    required this.tiempoPromedioMs,
    required this.porcentajeRiesgo,
    required this.semaforo,
    required this.fuentePrediccion,
    required this.modeloNombre,
    required this.modeloVersion,
    required this.probabilidadVerde,
    required this.probabilidadAmarillo,
    required this.probabilidadRojo,
  });

  factory EvaluationReportItem.fromJson(Map<String, dynamic> json) {
    return EvaluationReportItem(
      id: _asInt(json['id']),
      estudianteId: _asNullableInt(json['estudiante_id']),
      estudianteNombre: json['estudiante_nombre']?.toString(),
      seccionId: _asNullableInt(json['seccion_id']),
      fechaEvaluacion: DateTime.tryParse(
            json['fecha_evaluacion']?.toString() ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      tipoPrueba: json['tipo_prueba']?.toString(),
      totalItems: _asNullableInt(json['total_items']),
      aciertosPrimerIntento: _asNullableInt(
        json['aciertos_primer_intento'],
      ),
      tapsErroneosTotales: _asNullableInt(
        json['taps_erroneos_totales'],
      ),
      tiempoPromedioMs: _asNullableInt(json['tiempo_promedio_ms']),
      porcentajeRiesgo: _asNullableDouble(json['porcentaje_riesgo']),
      semaforo: json['semaforo']?.toString(),
      fuentePrediccion: json['fuente_prediccion']?.toString(),
      modeloNombre: json['modelo_nombre']?.toString(),
      modeloVersion: json['modelo_version']?.toString(),
      probabilidadVerde: _asNullableDouble(json['probabilidad_verde']),
      probabilidadAmarillo: _asNullableDouble(
        json['probabilidad_amarillo'],
      ),
      probabilidadRojo: _asNullableDouble(json['probabilidad_rojo']),
    );
  }

  String get fechaTexto {
    final local = fechaEvaluacion.toLocal();

    return '${_two(local.day)}/${_two(local.month)}/${local.year} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String get estudianteTexto {
    final name = estudianteNombre?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    if (estudianteId != null) {
      return 'Estudiante ID $estudianteId';
    }

    return 'Sin estudiante asociado';
  }

  String get fuenteTexto {
    final fuente = fuentePrediccion?.trim();

    if (fuente == null || fuente.isEmpty) {
      return 'Sin trazabilidad';
    }

    if (fuente == 'ML_RANDOM_FOREST') {
      return 'IA: Random Forest';
    }

    if (fuente == 'HEURISTICA') {
      return 'Heurística de respaldo';
    }

    return fuente;
  }

  String get modeloTexto {
    final modelo = modeloNombre?.trim();

    if (modelo == null || modelo.isEmpty) {
      return 'Modelo: N/D';
    }

    final version = modeloVersion?.trim();

    if (version == null || version.isEmpty) {
      return 'Modelo: $modelo';
    }

    return 'Modelo: $modelo ($version)';
  }

  String get probabilidadesTexto {
    final verde = _formatProbability(probabilidadVerde);
    final amarillo = _formatProbability(probabilidadAmarillo);
    final rojo = _formatProbability(probabilidadRojo);

    if (verde == 'N/D' && amarillo == 'N/D' && rojo == 'N/D') {
      return 'Probabilidades: N/D';
    }

    return 'P(Verde): $verde | P(Amarillo): $amarillo | P(Rojo): $rojo';
  }

  static String _formatProbability(double? value) {
    if (value == null) return 'N/D';

    return '${(value * 100).toStringAsFixed(1)}%';
  }

  static String _two(int value) {
    return value.toString().padLeft(2, '0');
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

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }
}

class SemaforoSummaryItem {
  final String semaforo;
  final int total;

  const SemaforoSummaryItem({
    required this.semaforo,
    required this.total,
  });

  factory SemaforoSummaryItem.fromJson(Map<String, dynamic> json) {
    return SemaforoSummaryItem(
      semaforo: json['semaforo']?.toString() ?? 'SIN_RESULTADO',
      total: _asInt(json['total']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class ReportSummary {
  final int totalEvaluaciones;
  final double? porcentajePromedioRiesgo;
  final List<SemaforoSummaryItem> semaforos;

  const ReportSummary({
    required this.totalEvaluaciones,
    required this.porcentajePromedioRiesgo,
    required this.semaforos,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> json) {
    final rawSemaforos = json['semaforos'];
    final parsedSemaforos = <SemaforoSummaryItem>[];

    if (rawSemaforos is List) {
      for (final item in rawSemaforos) {
        if (item is Map) {
          parsedSemaforos.add(
            SemaforoSummaryItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return ReportSummary(
      totalEvaluaciones: _asInt(json['total_evaluaciones']),
      porcentajePromedioRiesgo: _asNullableDouble(
        json['porcentaje_promedio_riesgo'],
      ),
      semaforos: parsedSemaforos,
    );
  }

  int totalBySemaforo(String semaforo) {
    final normalized = semaforo.toUpperCase();

    for (final item in semaforos) {
      if (item.semaforo.toUpperCase() == normalized) {
        return item.total;
      }
    }

    return 0;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }
}


class StudentTestProfile {
  final String tipoPrueba;
  final int totalEvaluaciones;
  final double? porcentajePromedioRiesgo;
  final double? ultimoPorcentajeRiesgo;
  final String? ultimoSemaforo;
  final DateTime? ultimaFecha;
  final double? promedioTiempoMs;
  final double? promedioErrores;
  final int totalVerde;
  final int totalAmarillo;
  final int totalRojo;
  final int totalSinResultado;

  const StudentTestProfile({
    required this.tipoPrueba,
    required this.totalEvaluaciones,
    required this.porcentajePromedioRiesgo,
    required this.ultimoPorcentajeRiesgo,
    required this.ultimoSemaforo,
    required this.ultimaFecha,
    required this.promedioTiempoMs,
    required this.promedioErrores,
    required this.totalVerde,
    required this.totalAmarillo,
    required this.totalRojo,
    required this.totalSinResultado,
  });

  factory StudentTestProfile.fromJson(Map<String, dynamic> json) {
    return StudentTestProfile(
      tipoPrueba: json['tipo_prueba']?.toString() ?? 'SIN_TIPO',
      totalEvaluaciones: _profileAsInt(json['total_evaluaciones']),
      porcentajePromedioRiesgo: _profileAsNullableDouble(
        json['porcentaje_promedio_riesgo'],
      ),
      ultimoPorcentajeRiesgo: _profileAsNullableDouble(
        json['ultimo_porcentaje_riesgo'],
      ),
      ultimoSemaforo: json['ultimo_semaforo']?.toString(),
      ultimaFecha: _profileAsNullableDateTime(json['ultima_fecha']),
      promedioTiempoMs: _profileAsNullableDouble(json['promedio_tiempo_ms']),
      promedioErrores: _profileAsNullableDouble(json['promedio_errores']),
      totalVerde: _profileAsInt(json['total_verde']),
      totalAmarillo: _profileAsInt(json['total_amarillo']),
      totalRojo: _profileAsInt(json['total_rojo']),
      totalSinResultado: _profileAsInt(json['total_sin_resultado']),
    );
  }

  String get tipoPruebaTexto {
    if (tipoPrueba.toUpperCase() == 'LECTURA') return 'Lectura';
    if (tipoPrueba.toUpperCase() == 'FONOLOGIA') {
      return 'Conciencia fonológica';
    }

    return tipoPrueba;
  }

  String get ultimaFechaTexto {
    final value = ultimaFecha;

    if (value == null) return 'Sin fecha';

    final local = value.toLocal();

    return '${_profileTwo(local.day)}/${_profileTwo(local.month)}/${local.year} '
        '${_profileTwo(local.hour)}:${_profileTwo(local.minute)}';
  }
}

class StudentRiskProfile {
  final int estudianteId;
  final String? estudianteNombre;
  final int? seccionId;
  final int totalEvaluaciones;
  final double? porcentajePromedioGeneral;
  final double? ultimoPorcentajeRiesgoGeneral;
  final String? ultimoSemaforoGeneral;
  final DateTime? ultimaFechaGeneral;
  final List<StudentTestProfile> pruebas;

  const StudentRiskProfile({
    required this.estudianteId,
    required this.estudianteNombre,
    required this.seccionId,
    required this.totalEvaluaciones,
    required this.porcentajePromedioGeneral,
    required this.ultimoPorcentajeRiesgoGeneral,
    required this.ultimoSemaforoGeneral,
    required this.ultimaFechaGeneral,
    required this.pruebas,
  });

  factory StudentRiskProfile.fromJson(Map<String, dynamic> json) {
    final rawPruebas = json['pruebas'];
    final parsedPruebas = <StudentTestProfile>[];

    if (rawPruebas is List) {
      for (final item in rawPruebas) {
        if (item is Map) {
          parsedPruebas.add(
            StudentTestProfile.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return StudentRiskProfile(
      estudianteId: _profileAsInt(json['estudiante_id']),
      estudianteNombre: json['estudiante_nombre']?.toString(),
      seccionId: _profileAsNullableInt(json['seccion_id']),
      totalEvaluaciones: _profileAsInt(json['total_evaluaciones']),
      porcentajePromedioGeneral: _profileAsNullableDouble(
        json['porcentaje_promedio_general'],
      ),
      ultimoPorcentajeRiesgoGeneral: _profileAsNullableDouble(
        json['ultimo_porcentaje_riesgo_general'],
      ),
      ultimoSemaforoGeneral: json['ultimo_semaforo_general']?.toString(),
      ultimaFechaGeneral: _profileAsNullableDateTime(
        json['ultima_fecha_general'],
      ),
      pruebas: parsedPruebas,
    );
  }

  String get estudianteTexto {
    final name = estudianteNombre?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return 'Estudiante ID $estudianteId';
  }

  String get ultimaFechaGeneralTexto {
    final value = ultimaFechaGeneral;

    if (value == null) return 'Sin fecha';

    final local = value.toLocal();

    return '${_profileTwo(local.day)}/${_profileTwo(local.month)}/${local.year} '
        '${_profileTwo(local.hour)}:${_profileTwo(local.minute)}';
  }
}

int _profileAsInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _profileAsNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();

  return int.tryParse(value.toString());
}

double? _profileAsNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();

  return double.tryParse(value.toString());
}

DateTime? _profileAsNullableDateTime(dynamic value) {
  if (value == null) return null;

  return DateTime.tryParse(value.toString());
}

String _profileTwo(int value) {
  return value.toString().padLeft(2, '0');
}
