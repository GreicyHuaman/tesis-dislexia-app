class LocalEvaluationDetail {
  final String stimulusId;
  final String texto;
  final String tipoPrueba;
  final int tiempoRespuestaMs;
  final int? duracionDragDropMs;
  final int tapsErroneos;
  final String? tipoError;
  final String complejidadEstimulo;
  final bool acierto;

  const LocalEvaluationDetail({
    required this.stimulusId,
    required this.texto,
    required this.tipoPrueba,
    required this.tiempoRespuestaMs,
    required this.duracionDragDropMs,
    required this.tapsErroneos,
    required this.tipoError,
    required this.complejidadEstimulo,
    required this.acierto,
  });

  Map<String, dynamic> toJson() {
    return {
      'stimulus_id': stimulusId,
      'texto': texto,
      'tipo_prueba': tipoPrueba,
      'tiempo_respuesta_ms': tiempoRespuestaMs,
      'duracion_drag_drop_ms': duracionDragDropMs,
      'taps_erroneos': tapsErroneos,
      'tipo_error': tipoError,
      'complejidad_estimulo': complejidadEstimulo,
      'acierto': acierto,
    };
  }
}
