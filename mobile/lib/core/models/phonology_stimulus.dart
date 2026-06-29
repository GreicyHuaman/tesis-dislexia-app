class PhonologyStimulus {
  final String id;
  final String tipoEstimulo;
  final String palabra;
  final String silabaObjetivo;
  final List<String> opciones;
  final int? numSilabas;
  final int? numLetras;
  final double? frecuencia;
  final String complejidadEstimulo;
  final String tipoPrueba;

  const PhonologyStimulus({
    required this.id,
    required this.tipoEstimulo,
    required this.palabra,
    required this.silabaObjetivo,
    required this.opciones,
    required this.numSilabas,
    required this.numLetras,
    required this.frecuencia,
    required this.complejidadEstimulo,
    required this.tipoPrueba,
  });

  factory PhonologyStimulus.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['opciones'];
    final parsedOptions = <String>[];

    if (rawOptions is List) {
      for (final option in rawOptions) {
        final text = option?.toString().trim();

        if (text != null && text.isNotEmpty) {
          parsedOptions.add(text);
        }
      }
    }

    final target = json['silaba_objetivo']?.toString().trim() ?? '';

    if (target.isNotEmpty && !parsedOptions.contains(target)) {
      parsedOptions.add(target);
    }

    return PhonologyStimulus(
      id: json['id']?.toString() ?? '',
      tipoEstimulo: json['tipo_estimulo']?.toString() ?? 'PALABRA_REAL',
      palabra: json['palabra']?.toString() ?? '',
      silabaObjetivo: target,
      opciones: parsedOptions,
      numSilabas: _asNullableInt(json['num_silabas']),
      numLetras: _asNullableInt(json['num_letras']),
      frecuencia: _asNullableDouble(json['frecuencia']),
      complejidadEstimulo: json['complejidad_estimulo']?.toString() ?? 'MEDIA',
      tipoPrueba: json['tipo_prueba']?.toString() ?? 'FONOLOGIA',
    );
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
