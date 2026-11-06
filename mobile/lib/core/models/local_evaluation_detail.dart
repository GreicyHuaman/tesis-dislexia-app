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

  factory LocalEvaluationDetail.fromJson(Map<String, dynamic> json) {
    final stimulusId = json['stimulus_id'];
    final texto = json['texto'];
    final tipo = json['tipo_prueba'];
    final tiempo = json['tiempo_respuesta_ms'];
    final drag = json['duracion_drag_drop_ms'];
    final errores = json['taps_erroneos'];
    final tipoError = json['tipo_error'];
    final complejidad = json['complejidad_estimulo'];
    final acierto = json['acierto'];
    if (stimulusId is! String ||
        stimulusId.isEmpty ||
        texto is! String ||
        tipo is! String ||
        tiempo is! int ||
        tiempo < 0 ||
        (drag != null && (drag is! int || drag < 0)) ||
        errores is! int ||
        errores < 0 ||
        (tipoError != null && tipoError is! String) ||
        complejidad is! String ||
        acierto is! bool) {
      throw const FormatException('Respuesta local inválida.');
    }
    return LocalEvaluationDetail(
      stimulusId: stimulusId,
      texto: texto,
      tipoPrueba: tipo,
      tiempoRespuestaMs: tiempo,
      duracionDragDropMs: drag is int ? drag : null,
      tapsErroneos: errores,
      tipoError: tipoError is String ? tipoError : null,
      complejidadEstimulo: complejidad,
      acierto: acierto,
    );
  }

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
