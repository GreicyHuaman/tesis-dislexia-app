class Stimulus {
  final String id;
  final String texto;
  final String tipoPrueba;
  final String tipoEstimulo;
  final double? frq;
  final int? numLetters;
  final int? saNumSyll;
  final String complejidadEstimulo;
  final String? audioAsset;
  final String? fuente;
  final String? fuenteArchivo;
  final int orden;

  const Stimulus({
    required this.id,
    required this.texto,
    required this.tipoPrueba,
    required this.tipoEstimulo,
    required this.frq,
    required this.numLetters,
    required this.saNumSyll,
    required this.complejidadEstimulo,
    required this.audioAsset,
    required this.fuente,
    required this.fuenteArchivo,
    required this.orden,
  });

  factory Stimulus.fromJson(Map<String, dynamic> json) {
    return Stimulus(
      id: json['id']?.toString() ?? '',
      texto: json['texto']?.toString() ?? '',
      tipoPrueba: json['tipo_prueba']?.toString() ?? '',
      tipoEstimulo: json['tipo_estimulo']?.toString() ?? '',
      frq: _toDouble(json['frq']),
      numLetters: _toInt(json['num_letters']),
      saNumSyll: _toInt(json['sa_num_syll']),
      complejidadEstimulo:
          json['complejidad_estimulo']?.toString() ?? 'SIN_CLASIFICAR',
      audioAsset: json['audio_asset']?.toString(),
      fuente: json['fuente']?.toString(),
      fuenteArchivo: json['fuente_archivo']?.toString(),
      orden: _toInt(json['orden']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'texto': texto,
    'tipo_prueba': tipoPrueba,
    'tipo_estimulo': tipoEstimulo,
    'frq': frq,
    'num_letters': numLetters,
    'sa_num_syll': saNumSyll,
    'complejidad_estimulo': complejidadEstimulo,
    'audio_asset': audioAsset,
    'fuente': fuente,
    'fuente_archivo': fuenteArchivo,
    'orden': orden,
  };

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
