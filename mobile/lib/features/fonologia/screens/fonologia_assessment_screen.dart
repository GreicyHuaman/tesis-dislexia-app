import '../../home/screens/student_test_completed_screen.dart';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/models/adaptive_word_bank.dart';
import '../../../core/models/local_evaluation_detail.dart';
import '../../../core/models/phonology_stimulus.dart';
import '../../../core/repositories/local_evaluation_storage.dart';
import '../../../core/repositories/phonology_repository.dart';
import '../../../core/services/evaluation_sync_service.dart';
import '../../../core/services/assessment_progress_tracker.dart';
import '../../../core/services/connection_errors.dart';
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
  final Random _random = Random();
  AssessmentProgressTracker? _progressTracker;

  bool _isLoading = true;
  bool _isFinished = false;
  bool _isSavingAnswer = false;
  bool _isSyncing = false;
  bool _isFinishing = false;

  String? _errorMessage;
  String? _feedbackMessage;
  String? _syncMessage;
  String? _localSessionId;
  String? _saveErrorMessage;

  List<PhonologyStimulus> _sessionStimuli = [];
  List<List<String>> _sessionOptions = [];
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
    _progressTracker?.dispose();
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
      var progress = LocalEvaluationStorage.getIncompleteAssessment(
        estudianteId: widget.estudianteId,
        tipoPrueba: 'FONOLOGIA',
      );
      if (progress == null) {
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
        final metadata = selection.metadata;
        final options = selection.items
            .map((item) => item.opciones.toSet().toList()..shuffle(_random))
            .toList();
        final sessionId = await LocalEvaluationStorage.createSession(
          tipoPrueba: 'FONOLOGIA',
          totalItems: selection.items.length,
          estudianteId: widget.estudianteId,
          nivelDificultadAplicado: metadata.nivelDificultadAplicado,
          totalBaja: metadata.totalBaja,
          totalMedia: metadata.totalMedia,
          totalAlta: metadata.totalAlta,
          versionBancoPalabras: metadata.versionBancoPalabras,
          assessmentItems: selection.items
              .map((item) => item.toJson())
              .toList(),
          assessmentOptions: options,
        );
        progress = LocalEvaluationStorage.getAssessment(sessionId);
      }
      await LocalEvaluationStorage.restoreAssessmentDetails(progress.sessionId);

      if (!mounted) return;

      setState(() {
        _sessionStimuli = progress!.items
            .map(PhonologyStimulus.fromJson)
            .toList();
        _sessionOptions = progress.options;
        _answers.addAll(progress.answers);
        _currentIndex = progress.answeredItems;
        _currentAdaptiveLevel = progress.nivelAplicado;
        _localSessionId = progress.sessionId;
        _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
        _isLoading = false;
      });
      _progressTracker = AssessmentProgressTracker(
        sessionId: progress.sessionId,
        onSaveError: () {
          if (mounted) {
            setState(() {
              _saveErrorMessage =
                  'No se pudo guardar. Pide ayuda a tu docente.';
            });
          }
        },
      );
      if (progress.remainingItems == 0) {
        await _finishSession();
      } else {
        _prepareCurrentQuestion(
          savedErrors: progress.currentErrors,
          savedElapsedMs: progress.currentElapsedMs,
        );
      }
    } catch (error, stackTrace) {
      logRequestFailure('Abrir prueba de fonología', error, stackTrace);
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo abrir la prueba. Pide ayuda a tu docente.';
        _isLoading = false;
      });
    }
  }

  void _prepareCurrentQuestion({int savedErrors = 0, int savedElapsedMs = 0}) {
    if (_sessionStimuli.isEmpty || _currentIndex >= _sessionStimuli.length) {
      return;
    }

    _progressTracker!.startItem(
      index: _currentIndex,
      savedErrors: savedErrors,
      savedElapsedMs: savedElapsedMs,
    );

    setState(() {
      _options = _sessionOptions[_currentIndex];
      _erroresCurrent = savedErrors;
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
        _isSavingAnswer = true;
      });
      _progressTracker!.errors = _erroresCurrent;
      try {
        await _progressTracker!.checkpoint();
        if (mounted) setState(() => _saveErrorMessage = null);
      } catch (error, stackTrace) {
        logRequestFailure('Guardar intento fonológico', error, stackTrace);
        if (mounted) {
          setState(() {
            _saveErrorMessage = 'No se pudo guardar. Pide ayuda a tu docente.';
          });
        }
      } finally {
        if (mounted) setState(() => _isSavingAnswer = false);
      }
      return;
    }

    setState(() {
      _isSavingAnswer = true;
    });

    _progressTracker!.stopItem();

    final hadErrors = _erroresCurrent > 0;
    final elapsedMs = _progressTracker!.elapsedMs;

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

    try {
      final saved = await LocalEvaluationStorage.saveAssessmentAnswer(
        sessionId: _localSessionId!,
        itemIndex: _currentIndex,
        detail: detail,
      );
      if (!mounted) return;
      setState(() {
        _answers
          ..clear()
          ..addAll(saved.answers);
        _currentIndex = saved.answeredItems;
        _feedbackMessage = null;
        _saveErrorMessage = null;
        _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
      });
      if (saved.remainingItems == 0) {
        await _finishSession();
      } else {
        _prepareCurrentQuestion();
      }
    } catch (error, stackTrace) {
      logRequestFailure('Guardar respuesta fonológica', error, stackTrace);
      if (mounted) {
        _progressTracker?.resumeItem();
        setState(() {
          _isSavingAnswer = false;
          _saveErrorMessage = 'No se pudo guardar. Pide ayuda a tu docente.';
        });
      }
    }
  }

  Future<void> _finishSession() async {
    if (_isFinishing) return;

    _progressTracker?.stopItem();
    if (_answers.length != _sessionStimuli.length || _answers.isEmpty) {
      setState(() {
        _isSavingAnswer = false;
        _saveErrorMessage = 'Faltan respuestas. Puedes continuar la prueba.';
      });
      return;
    }
    setState(() => _isFinishing = true);
    try {
      await LocalEvaluationStorage.finishSession(
        localSessionId: _localSessionId!,
        totalItems: _answers.length,
        aciertosPrimerIntento: _aciertosPrimerIntento,
        tapsErroneosTotales: _totalErrores,
        tiempoPromedioMs: _promedioTiempoMs,
      );
      if (!mounted) return;
      setState(() {
        _isFinished = true;
        _isSavingAnswer = false;
        _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
      });
      await _syncPendingSessions();
    } catch (error, stackTrace) {
      logRequestFailure('Finalizar fonología', error, stackTrace);
      if (mounted) {
        setState(() {
          _saveErrorMessage = 'No se pudo guardar. Pide ayuda a tu docente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFinishing = false;
          _isSavingAnswer = false;
        });
      }
    }
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
            _errorMessage!,
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
      return Scaffold(
        appBar: AppBar(title: const Text('Conciencia fonológica')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_saveErrorMessage ?? 'Guardando la prueba...'),
              if (_isFinishing)
                const CircularProgressIndicator()
              else
                FilledButton(
                  onPressed: _finishSession,
                  child: const Text('Reintentar guardado'),
                ),
            ],
          ),
        ),
      );
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
                onWillAcceptWithDetails: (_) =>
                    !_isSavingAnswer && !_isFinishing,
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
                        maxSimultaneousDrags: _isSavingAnswer || _isFinishing
                            ? 0
                            : 1,
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
              if (_saveErrorMessage != null) Text(_saveErrorMessage!),
              Text(
                'Errores de arrastre en este ítem: $_erroresCurrent',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Respuestas guardadas: ${_answers.length} de ${_sessionStimuli.length}. '
                'Faltan ${_sessionStimuli.length - _answers.length}.',
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
