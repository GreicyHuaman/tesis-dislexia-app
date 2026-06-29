import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/models/local_evaluation_detail.dart';
import '../../../core/models/stimulus.dart';
import '../../../core/repositories/local_evaluation_storage.dart';
import '../../../core/repositories/stimuli_repository.dart';
import '../../../core/services/evaluation_sync_service.dart';
import '../../auth/screens/pin_login_screen.dart';

class LecturaAssessmentScreen extends StatefulWidget {
  final int estudianteId;
  final String studentDisplayName;

  const LecturaAssessmentScreen({
    super.key,
    required this.estudianteId,
    required this.studentDisplayName,
  });

  @override
  State<LecturaAssessmentScreen> createState() =>
      _LecturaAssessmentScreenState();
}

class _LecturaAssessmentScreenState extends State<LecturaAssessmentScreen> {
  final StimuliRepository _repository = StimuliRepository();
  final EvaluationSyncService _syncService = const EvaluationSyncService();
  final Stopwatch _stopwatch = Stopwatch();
  final Random _random = Random();

  bool _isLoading = true;
  bool _isFinished = false;
  bool _isSavingAnswer = false;
  bool _isSyncing = false;

  String? _errorMessage;
  String? _feedbackMessage;
  String? _syncMessage;
  String? _localSessionId;
  String? _lastSemaforo;

  double? _lastPorcentajeRiesgo;

  List<Stimulus> _allStimuli = [];
  List<Stimulus> _sessionStimuli = [];
  List<String> _options = [];
  final List<LocalEvaluationDetail> _answers = [];

  int _currentIndex = 0;
  int _tapsErroneosCurrent = 0;
  int _pendingLocalSessions = 0;

  @override
  void initState() {
    super.initState();
    _loadStimuli();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  Future<void> _loadStimuli() async {
    try {
      final stimuli = await _repository.loadLecturaStimuli();

      final validStimuli = stimuli
          .where((stimulus) => stimulus.texto.trim().isNotEmpty)
          .toList();

      validStimuli.shuffle(_random);

      final sessionSize = min(10, validStimuli.length);
      final sessionStimuli = validStimuli.take(sessionSize).toList();

      String? sessionId;

      if (sessionStimuli.isNotEmpty) {
        sessionId = await LocalEvaluationStorage.createSession(
          tipoPrueba: 'LECTURA',
          totalItems: sessionStimuli.length,
          estudianteId: widget.estudianteId,
        );
      }

      if (!mounted) return;

      setState(() {
        _allStimuli = validStimuli;
        _sessionStimuli = sessionStimuli;
        _localSessionId = sessionId;
        _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
        _isLoading = false;
        _isFinished = _sessionStimuli.isEmpty;
      });

      if (_sessionStimuli.isNotEmpty) {
        _prepareCurrentQuestion();
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _prepareCurrentQuestion() {
    if (_sessionStimuli.isEmpty || _currentIndex >= _sessionStimuli.length) {
      _finishSession();
      return;
    }

    final currentStimulus = _sessionStimuli[_currentIndex];

    final distractors = _allStimuli
        .where((stimulus) => stimulus.texto != currentStimulus.texto)
        .map((stimulus) => stimulus.texto)
        .toSet()
        .toList();

    distractors.shuffle(_random);

    final generatedOptions = <String>[
      currentStimulus.texto,
      ...distractors.take(2),
    ];

    generatedOptions.shuffle(_random);

    _stopwatch
      ..reset()
      ..start();

    setState(() {
      _options = generatedOptions;
      _tapsErroneosCurrent = 0;
      _feedbackMessage = null;
      _syncMessage = null;
      _isSavingAnswer = false;
    });
  }

  Future<void> _handleOptionTap(String selectedText) async {
    if (_isSavingAnswer) return;

    if (_sessionStimuli.isEmpty || _currentIndex >= _sessionStimuli.length) {
      await _finishSession();
      return;
    }

    final currentStimulus = _sessionStimuli[_currentIndex];
    final isCorrectOption = selectedText == currentStimulus.texto;

    if (!isCorrectOption) {
      setState(() {
        _tapsErroneosCurrent++;
        _feedbackMessage = 'Intenta otra vez';
      });
      return;
    }

    setState(() {
      _isSavingAnswer = true;
    });

    _stopwatch.stop();

    final hadErrors = _tapsErroneosCurrent > 0;

    final detail = LocalEvaluationDetail(
      stimulusId: currentStimulus.id,
      texto: currentStimulus.texto,
      tipoPrueba: currentStimulus.tipoPrueba,
      tiempoRespuestaMs: _stopwatch.elapsedMilliseconds,
      duracionDragDropMs: null,
      tapsErroneos: _tapsErroneosCurrent,
      tipoError: hadErrors ? 'SELECCION_INCORRECTA' : null,
      complejidadEstimulo: currentStimulus.complejidadEstimulo,
      acierto: !hadErrors,
    );

    final sessionId = _localSessionId;

    if (sessionId != null) {
      await LocalEvaluationStorage.saveDetail(
        localSessionId: sessionId,
        detail: detail,
      );
    }

    if (!mounted) return;

    final isLastQuestion = _currentIndex == _sessionStimuli.length - 1;

    if (isLastQuestion) {
      setState(() {
        _answers.add(detail);
        _feedbackMessage = null;
        _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
      });

      await _finishSession();
      return;
    }

    setState(() {
      _answers.add(detail);
      _currentIndex++;
      _feedbackMessage = null;
      _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
    });

    _prepareCurrentQuestion();
  }

  Future<void> _finishSession() async {
    _stopwatch.stop();

    final sessionId = _localSessionId;

    if (sessionId != null) {
      await LocalEvaluationStorage.finishSession(
        localSessionId: sessionId,
        totalItems: _answers.length,
        aciertosPrimerIntento: _aciertosPrimerIntento,
        tapsErroneosTotales: _totalTapsErroneos,
        tiempoPromedioMs: _promedioTiempoMs,
      );
    }

    final telemetryJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(_answers.map((answer) => answer.toJson()).toList());

    debugPrint('TELEMETRIA LOCAL DE LECTURA - SESION ACTUAL');
    debugPrint(telemetryJson);

    debugPrint('DATOS HIVE PENDIENTES DE SINCRONIZACION');
    debugPrint(LocalEvaluationStorage.exportDebugJson());

    if (!mounted) return;

    setState(() {
      _isFinished = true;
      _isSavingAnswer = false;
      _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
    });

    await _syncPendingSessions();
  }

  void _changeStudent() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _restartSession() async {
    final shuffled = List<Stimulus>.from(_allStimuli)..shuffle(_random);
    final sessionSize = min(10, shuffled.length);
    final sessionStimuli = shuffled.take(sessionSize).toList();

    String? sessionId;

    if (sessionStimuli.isNotEmpty) {
      sessionId = await LocalEvaluationStorage.createSession(
        tipoPrueba: 'LECTURA',
        totalItems: sessionStimuli.length,
        estudianteId: widget.estudianteId,
      );
    }

    if (!mounted) return;

    setState(() {
      _sessionStimuli = sessionStimuli;
      _localSessionId = sessionId;
      _answers.clear();
      _currentIndex = 0;
      _isFinished = _sessionStimuli.isEmpty;
      _feedbackMessage = null;
      _syncMessage = null;
      _lastPorcentajeRiesgo = null;
      _lastSemaforo = null;
      _tapsErroneosCurrent = 0;
      _isSavingAnswer = false;
      _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
    });

    if (_sessionStimuli.isNotEmpty) {
      _prepareCurrentQuestion();
    }
  }

  Future<void> _syncPendingSessions() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _syncMessage = 'Sincronizando con el backend...';
    });

    final result = await _syncService.syncPendingEvaluations();

    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      _syncMessage = result.message;
      _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();

      if (result.success && result.porcentajeRiesgo != null) {
        _lastPorcentajeRiesgo = result.porcentajeRiesgo;
        _lastSemaforo = result.semaforo;
      }
    });
  }

  int get _totalTapsErroneos {
    return _answers.fold<int>(0, (sum, answer) => sum + answer.tapsErroneos);
  }

  int get _aciertosPrimerIntento {
    return _answers.where((answer) => answer.acierto).length;
  }

  int get _promedioTiempoMs {
    if (_answers.isEmpty) return 0;

    final totalMs = _answers.fold<int>(
      0,
      (sum, answer) => sum + answer.tiempoRespuestaMs,
    );

    return (totalMs / _answers.length).round();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Evaluación lectora')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error cargando estímulos:\n$_errorMessage',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_isFinished) {
      return _buildSummaryScreen();
    }

    return _buildQuestionScreen();
  }

  Widget _buildQuestionScreen() {
    if (_sessionStimuli.isEmpty || _currentIndex >= _sessionStimuli.length) {
      return _buildSummaryScreen();
    }

    final currentStimulus = _sessionStimuli[_currentIndex];
    final progress = (_currentIndex + 1) / _sessionStimuli.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Evaluación lectora'),
        actions: [
          IconButton(
            tooltip: 'Cambiar estudiante',
            onPressed: _changeStudent,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.studentDisplayName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 12),
              Text(
                'Ítem ${_currentIndex + 1} de ${_sessionStimuli.length}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              const Text(
                'Toca la palabra igual:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    currentStimulus.texto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ..._options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton(
                    onPressed: _isSavingAnswer
                        ? null
                        : () => _handleOptionTap(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(option, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_feedbackMessage != null)
                Text(
                  _feedbackMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Taps erróneos en este ítem: $_tapsErroneosCurrent',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sesiones locales pendientes: $_pendingLocalSessions',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryScreen() {
    final canSync = _pendingLocalSessions > 0 && !_isSyncing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen de lectura'),
        actions: [
          IconButton(
            tooltip: 'Cambiar estudiante',
            onPressed: _isSyncing ? null : _changeStudent,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle_outline, size: 64),
              const SizedBox(height: 16),
              Text(
                'Evaluación finalizada',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              _SummaryTile(
                label: 'Estudiante',
                value: widget.studentDisplayName,
              ),
              _SummaryTile(
                label: 'ID estudiante',
                value: '${widget.estudianteId}',
              ),
              _SummaryTile(
                label: 'Total de ítems',
                value: '${_answers.length}',
              ),
              _SummaryTile(
                label: 'Aciertos al primer intento',
                value: '$_aciertosPrimerIntento',
              ),
              _SummaryTile(
                label: 'Taps erróneos totales',
                value: '$_totalTapsErroneos',
              ),
              _SummaryTile(
                label: 'Tiempo promedio',
                value: '$_promedioTiempoMs ms',
              ),
              _SummaryTile(
                label: 'Sesiones pendientes de sincronizar',
                value: '$_pendingLocalSessions',
              ),
              const SizedBox(height: 20),
              const Text(
                'La sesión fue guardada en Hive DB localmente.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: canSync ? _syncPendingSessions : null,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isSyncing ? 'Sincronizando...' : 'Sincronizar con backend',
                ),
              ),
              if (_syncMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _syncMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        _syncMessage!.toLowerCase().contains('exitosa') ||
                            _syncMessage!.toLowerCase().contains('no hay')
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_lastPorcentajeRiesgo != null && _lastSemaforo != null) ...[
                const SizedBox(height: 16),
                _RiskResultCard(
                  porcentajeRiesgo: _lastPorcentajeRiesgo!,
                  semaforo: _lastSemaforo!,
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSyncing ? null : _restartSession,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reiniciar prueba con el mismo estudiante'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isSyncing ? null : _changeStudent,
                icon: const Icon(Icons.logout),
                label: const Text('Cambiar estudiante'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _RiskResultCard extends StatelessWidget {
  final double porcentajeRiesgo;
  final String semaforo;

  const _RiskResultCard({
    required this.porcentajeRiesgo,
    required this.semaforo,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = semaforo.toUpperCase();

    Color color;
    IconData icon;

    if (normalized == 'ROJO') {
      color = Colors.red;
      icon = Icons.warning_amber_rounded;
    } else if (normalized == 'AMARILLO') {
      color = Colors.orange;
      icon = Icons.info_outline;
    } else {
      color = Colors.green;
      icon = Icons.check_circle_outline;
    }

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            const Text(
              'Resultado preliminar de tamizaje',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '${porcentajeRiesgo.toStringAsFixed(2)}%',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Semáforo: $normalized',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Este resultado es un indicador de riesgo para tamizaje educativo. No representa un diagnóstico clínico.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
