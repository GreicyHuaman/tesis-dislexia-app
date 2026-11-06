import 'local_evaluation_detail.dart';

class LocalAssessmentProgress {
  final String sessionId;
  final int estudianteId;
  final String tipoPrueba;
  final int nivelAplicado;
  final List<Map<String, dynamic>> items;
  final List<List<String>> options;
  final List<LocalEvaluationDetail> answers;
  final int currentErrors;
  final int currentElapsedMs;

  const LocalAssessmentProgress({
    required this.sessionId,
    required this.estudianteId,
    required this.tipoPrueba,
    required this.nivelAplicado,
    required this.items,
    required this.options,
    required this.answers,
    required this.currentErrors,
    required this.currentElapsedMs,
  });

  int get totalItems => items.length;
  int get answeredItems => answers.length;
  int get remainingItems => totalItems - answeredItems;
}
