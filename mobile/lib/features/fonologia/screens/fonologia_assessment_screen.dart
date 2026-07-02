import '../../home/screens/student_test_completed_screen.dart';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/models/adaptive_word_bank.dart';
import '../../../core/models/local_evaluation_detail.dart';
import '../../../core/models/phonology_stimulus.dart';
import '../../../core/repositories/local_evaluation_storage.dart';
import '../../../core/repositories/phonology_repository.dart';
import '../../../core/services/evaluation_sync_service.dart';
import '../../auth/screens/pin_login_screen.dart';

class FonologiaAssessmentScreen extends StatefulWidget {
  final int estudianteId;
  final String studentDisplayName;
  final int nivelFonologia;

  const FonologiaAssessmentScreen({
    super.key,
    required this.estudianteId,
    required this.studentDisplayName,
    required this.nivelFonologia,
  });

  @override
  State<FonologiaAssessmentScreen> createState() =>
      _FonologiaAssessmentScreenState();
}

class _FonologiaAssessmentScreenState extends State<FonologiaAssessmentScreen> {
  final PhonologyRepository _repository = PhonologyRepository();
  final EvaluationSyncService _syncService = const EvaluationSyncService();
  final Stopwatch _stopwatch = Stopwatch();
  final Random _random = Random();

  bool _isLoading = true;
  bool _isFinished = false;
  bool _isSavingAnswer = false;
  bool _isSyncing = false;
  bool _isFinishing = false;

  String? _errorMessage;
  String? _feedbackMessage;
  String? _syncMessage;
  String? _localSessionId;

  List<PhonologyStimulus> _sessionStimuli = [];
  List<String> _options = [];
  final List<LocalEvaluationDetail> _answers = [];

  int _currentIndex = 0;
  int _erroresCurrent = 0;
  int _pendingLocalSessions = 0;
  late int _currentAdaptiveLevel;

  @override
  void initState() {
    super.initState();
    _currentAdaptiveLevel = AdaptiveWordBankSelector.clampLevel(
      widget.nivelFonologia,
    );
    _loadStimuli();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  AdaptiveSelection<PhonologyStimulus> _buildSessionSelection(
    List<PhonologyStimulus> source,
  ) {
    return AdaptiveWordBankSelector.select<PhonologyStimulus>(
      items: source,
      level: _currentAdaptiveLevel,
      difficultyOf: (stimulus) => stimulus.complejidadEstimulo,
      random: _random,
    );
  }

  Future<void> _loadStimuli() async {
    try {
      final stimuli = await _repository.loadPhonologyStimuli();

      final validStimuli = stimuli
          .where(
            (stimulus) =>
                stimulus.palabra.trim().isNotEmpty &&
                stimulus.silabaObjetivo.trim().isNotEmpty &&
                stimulus.opciones.length >= 3,
          )
          .toList();

      final selection = _buildSessionSelection(validStimuli);
      final sessionStimuli = selection.items;
      final metadata = selection.metadata;

      String? sessionId;

      if (sessionStimuli.isNotEmpty) {
        sessionId = await LocalEvaluationStorage.createSession(
          tipoPrueba: 'FONOLOGIA',
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
      return;
    }

    final currentStimulus = _sessionStimuli[_currentIndex];
    final generatedOptions = currentStimulus.opciones.toSet().toList();

    generatedOptions.shuffle(_random);

    _stopwatch
      ..reset()
      ..start();

    setState(() {
      _options = generatedOptions;
      _erroresCurrent = 0;
      _feedbackMessage = null;
      _syncMessage = null;
      _isSavingAnswer = false;
    });
  }

  Future<void> _handleDrop(String selectedSyllable) async {
    if (_isSavingAnswer || _isFinishing) return;

    if (_sessionStimuli.isEmpty || _currentIndex >= _sessionStimuli.length) {
      await _finishSession();
      return;
    }

    final currentStimulus = _sessionStimuli[_currentIndex];
    final isCorrect = selectedSyllable == currentStimulus.silabaObjetivo;

    if (!isCorrect) {
      setState(() {
        _erroresCurrent++;
        _feedbackMessage = 'Esa no es la sílaba inicial. Intenta otra vez.';
      });
      return;
    }

    setState(() {
      _isSavingAnswer = true;
    });

    _stopwatch.stop();

    final hadErrors = _erroresCurrent > 0;
    final elapsedMs = _stopwatch.elapsedMilliseconds;

    final detail = LocalEvaluationDetail(
      stimulusId: currentStimulus.id,
      texto:
          '${currentStimulus.tipoEstimulo}|${currentStimulus.palabra}|${currentStimulus.silabaObjetivo}',
      tipoPrueba: currentStimulus.tipoPrueba,
      tiempoRespuestaMs: elapsedMs,
      duracionDragDropMs: elapsedMs,
      tapsErroneos: _erroresCurrent,
      tipoError: hadErrors ? 'DRAG_DROP_INCORRECTO' : null,
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

    setState(() {
      _answers.add(detail);
      _feedbackMessage = null;
      _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
    });

    if (isLastQuestion) {
      await _finishSession();
      return;
    }

    setState(() {
      _currentIndex++;
    });

    _prepareCurrentQuestion();
  }

  Future<void> _finishSession() async {
    if (_isFinishing) return;

    _isFinishing = true;
    _stopwatch.stop();

    final sessionId = _localSessionId;

    if (sessionId != null) {
      await LocalEvaluationStorage.finishSession(
        localSessionId: sessionId,
        totalItems: _answers.length,
        aciertosPrimerIntento: _aciertosPrimerIntento,
        tapsErroneosTotales: _totalErrores,
        tiempoPromedioMs: _promedioTiempoMs,
      );
    }

    final telemetryJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(_answers.map((answer) => answer.toJson()).toList());

    debugPrint('TELEMETRÍA LOCAL DE FONOLOGÍA - SESIÓN ACTUAL');
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

    _isFinishing = false;
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

      if (result.success && result.nivelFonologia != null) {
        _currentAdaptiveLevel = AdaptiveWordBankSelector.clampLevel(
          result.nivelFonologia!,
        );
      }
    });
  }

  int get _totalErrores {
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
        appBar: AppBar(title: const Text('Conciencia fonológica')),
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
        title: const Text('Conciencia fonológica'),
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
                'Arrastra la sílaba inicial de la palabra:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 21),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    children: [
                      Text(
                        currentStimulus.palabra,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentStimulus.tipoEstimulo == 'PSEUDOPALABRA'
                            ? 'Pseudopalabra'
                            : 'Palabra real',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DragTarget<String>(
                onWillAcceptWithDetails: (_) => true,
                onAcceptWithDetails: (details) {
                  _handleDrop(details.data);
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovering = candidateData.isNotEmpty;

                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(
                        width: 2,
                        color: isHovering ? Colors.indigo : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      isHovering
                          ? 'Suelta aquí'
                          : 'Coloca aquí la sílaba correcta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: isHovering ? Colors.indigo : Colors.black87,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 26),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _options
                    .map(
                      (option) => Draggable<String>(
                        data: option,
                        feedback: Material(
                          color: Colors.transparent,
                          child: _SyllableChip(text: option, isFloating: true),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _SyllableChip(text: option),
                        ),
                        child: _SyllableChip(text: option),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              if (_feedbackMessage != null)
                Text(
                  _feedbackMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Errores de arrastre en este ítem: $_erroresCurrent',
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
      testName: 'fonología',
      syncSuccess: syncSuccess,
      syncMessage: message,
    );
  }
}

class _SyllableChip extends StatelessWidget {
  final String text;
  final bool isFloating;

  const _SyllableChip({required this.text, this.isFloating = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isFloating ? 8 : 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        child: Text(
          text,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
