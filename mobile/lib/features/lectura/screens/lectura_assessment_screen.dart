import '../../home/screens/student_test_completed_screen.dart';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/models/adaptive_word_bank.dart';
import '../../../core/models/local_evaluation_detail.dart';
import '../../../core/models/stimulus.dart';
import '../../../core/repositories/local_evaluation_storage.dart';
import '../../../core/repositories/stimuli_repository.dart';
import '../../../core/services/evaluation_sync_service.dart';
import '../../auth/screens/pin_login_screen.dart';

class LecturaAssessmentScreen extends StatefulWidget {
  final int estudianteId;
  final String studentDisplayName;
  final int nivelLectura;

  const LecturaAssessmentScreen({
    super.key,
    required this.estudianteId,
    required this.studentDisplayName,
    required this.nivelLectura,
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

  List<Stimulus> _allStimuli = [];
  List<Stimulus> _sessionStimuli = [];
  List<String> _options = [];
  final List<LocalEvaluationDetail> _answers = [];

  int _currentIndex = 0;
  int _tapsErroneosCurrent = 0;
  int _pendingLocalSessions = 0;
  late int _currentAdaptiveLevel;

  @override
  void initState() {
    super.initState();
    _currentAdaptiveLevel = AdaptiveWordBankSelector.clampLevel(
      widget.nivelLectura,
    );
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

      final selection = AdaptiveWordBankSelector.select<Stimulus>(
        items: validStimuli,
        level: _currentAdaptiveLevel,
        difficultyOf: (stimulus) => stimulus.complejidadEstimulo,
        random: _random,
      );
      final sessionStimuli = selection.items;
      final metadata = selection.metadata;

      String? sessionId;

      if (sessionStimuli.isNotEmpty) {
        sessionId = await LocalEvaluationStorage.createSession(
          tipoPrueba: 'LECTURA',
          totalItems: sessionStimuli.length,
          estudianteId: widget.estudianteId,
          nivelDificultadAplicado: metadata.nivelDificultadAplicado,
          totalBaja: metadata.totalBaja,
          totalMedia: metadata.totalMedia,
          totalAlta: metadata.totalAlta,
          versionBancoPalabras: metadata.versionBancoPalabras,
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

    debugPrint('TELEMETRÍA LOCAL DE LECTURA - SESIÓN ACTUAL');
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

  Future<void> _syncPendingSessions() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
      _syncMessage = 'Sincronizando con el servidor...';
    });

    final result = await _syncService.syncPendingEvaluations();

    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      _syncMessage = result.message;
      _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();

      if (result.success && result.nivelLectura != null) {
        _currentAdaptiveLevel = AdaptiveWordBankSelector.clampLevel(
          result.nivelLectura!,
        );
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
    final normalizedSyncMessage = (_syncMessage ?? '').toLowerCase();

    final syncSuccess =
        (!_isSyncing && _pendingLocalSessions == 0) ||
        normalizedSyncMessage.contains('exitosa') ||
        normalizedSyncMessage.contains('completada') ||
        normalizedSyncMessage.contains('no hay evaluaciones');

    final message = _isSyncing
        ? 'Sincronizando con el servidor...'
        : syncSuccess
        ? 'Sincronización completada.'
        : 'Se sincronizará automáticamente cuando haya conexión.';

    return StudentTestCompletedScreen(
      testName: 'lectura',
      syncSuccess: syncSuccess,
      syncMessage: message,
    );
  }
}
