import '../../home/screens/student_test_completed_screen.dart';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/models/adaptive_word_bank.dart';
import '../../../core/models/local_evaluation_detail.dart';
import '../../../core/models/stimulus.dart';
import '../../../core/repositories/local_evaluation_storage.dart';
import '../../../core/repositories/stimuli_repository.dart';
import '../../../core/services/evaluation_sync_service.dart';
import '../../../core/services/assessment_progress_tracker.dart';
import '../../../core/services/connection_errors.dart';
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

  List<Stimulus> _sessionStimuli = [];
  List<List<String>> _sessionOptions = [];
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
    _progressTracker?.dispose();
    super.dispose();
  }

  Future<void> _loadStimuli() async {
    try {
      var progress = LocalEvaluationStorage.getIncompleteAssessment(
        estudianteId: widget.estudianteId,
        tipoPrueba: 'LECTURA',
      );
      if (progress == null) {
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
        final metadata = selection.metadata;
        final options = selection.items.map((current) {
          final distractors =
              validStimuli
                  .where((stimulus) => stimulus.texto != current.texto)
                  .map((stimulus) => stimulus.texto)
                  .toSet()
                  .toList()
                ..shuffle(_random);
          return [current.texto, ...distractors.take(2)]..shuffle(_random);
        }).toList();
        final sessionId = await LocalEvaluationStorage.createSession(
          tipoPrueba: 'LECTURA',
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
        _sessionStimuli = progress!.items.map(Stimulus.fromJson).toList();
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
      logRequestFailure('Abrir prueba de lectura', error, stackTrace);
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo abrir la prueba. Pide ayuda a tu docente.';
        _isLoading = false;
      });
    }
  }

  void _prepareCurrentQuestion({int savedErrors = 0, int savedElapsedMs = 0}) {
    if (_sessionStimuli.isEmpty || _currentIndex >= _sessionStimuli.length) {
      _finishSession();
      return;
    }

    _progressTracker!.startItem(
      index: _currentIndex,
      savedErrors: savedErrors,
      savedElapsedMs: savedElapsedMs,
    );

    setState(() {
      _options = _sessionOptions[_currentIndex];
      _tapsErroneosCurrent = savedErrors;
      _feedbackMessage = null;
      _syncMessage = null;
      _isSavingAnswer = false;
    });
  }

  Future<void> _handleOptionTap(String selectedText) async {
    if (_isSavingAnswer || _isFinishing) return;

    if (_sessionStimuli.isEmpty || _currentIndex >= _sessionStimuli.length) {
      await _finishSession();
      return;
    }

    final currentStimulus = _sessionStimuli[_currentIndex];
    final isCorrectOption = selectedText == currentStimulus.texto;

    if (!isCorrectOption) {
      setState(() {
        _tapsErroneosCurrent++;
        _feedbackMessage = 'Vuelve a intentarlo';
        _isSavingAnswer = true;
      });
      _progressTracker!.errors = _tapsErroneosCurrent;
      try {
        await _progressTracker!.checkpoint();
        if (mounted) setState(() => _saveErrorMessage = null);
      } catch (error, stackTrace) {
        logRequestFailure('Guardar intento de lectura', error, stackTrace);
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

    final hadErrors = _tapsErroneosCurrent > 0;

    final detail = LocalEvaluationDetail(
      stimulusId: currentStimulus.id,
      texto: currentStimulus.texto,
      tipoPrueba: currentStimulus.tipoPrueba,
      tiempoRespuestaMs: _progressTracker!.elapsedMs,
      duracionDragDropMs: null,
      tapsErroneos: _tapsErroneosCurrent,
      tipoError: hadErrors ? 'SELECCION_INCORRECTA' : null,
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
      logRequestFailure('Guardar respuesta de lectura', error, stackTrace);
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
        tapsErroneosTotales: _totalTapsErroneos,
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
      logRequestFailure('Finalizar lectura', error, stackTrace);
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
        appBar: AppBar(title: const Text('Evaluación lectora')),
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
              if (_saveErrorMessage != null) Text(_saveErrorMessage!),
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
      testName: 'lectura',
      syncSuccess: syncSuccess,
      syncMessage: message,
    );
  }
}
