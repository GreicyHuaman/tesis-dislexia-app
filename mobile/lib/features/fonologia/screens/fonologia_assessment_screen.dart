import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/models/local_evaluation_detail.dart';
import '../../../core/models/phonology_stimulus.dart';
import '../../../core/repositories/local_evaluation_storage.dart';
import '../../../core/repositories/phonology_repository.dart';
import '../../../core/services/evaluation_sync_service.dart';
import '../../auth/screens/pin_login_screen.dart';

class FonologiaAssessmentScreen extends StatefulWidget {
  final int estudianteId;
  final String studentDisplayName;

  const FonologiaAssessmentScreen({
    super.key,
    required this.estudianteId,
    required this.studentDisplayName,
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
  String? _lastSemaforo;

  double? _lastPorcentajeRiesgo;

  List<PhonologyStimulus> _allStimuli = [];
  List<PhonologyStimulus> _sessionStimuli = [];
  List<String> _options = [];
  final List<LocalEvaluationDetail> _answers = [];

  int _currentIndex = 0;
  int _erroresCurrent = 0;
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

  List<PhonologyStimulus> _buildSessionStimuli(List<PhonologyStimulus> source) {
    final realItems =
        source
            .where((stimulus) => stimulus.tipoEstimulo == 'PALABRA_REAL')
            .toList()
          ..shuffle(_random);

    final pseudoItems =
        source
            .where((stimulus) => stimulus.tipoEstimulo == 'PSEUDOPALABRA')
            .toList()
          ..shuffle(_random);

    final selected = <PhonologyStimulus>[];

    selected.addAll(realItems.take(7));
    selected.addAll(pseudoItems.take(3));

    if (selected.length < 10) {
      final selectedIds = selected.map((stimulus) => stimulus.id).toSet();

      final fallbackItems =
          source
              .where((stimulus) => !selectedIds.contains(stimulus.id))
              .toList()
            ..shuffle(_random);

      selected.addAll(fallbackItems.take(10 - selected.length));
    }

    selected.shuffle(_random);

    return selected.take(10).toList();
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

      final sessionStimuli = _buildSessionStimuli(validStimuli);

      String? sessionId;

      if (sessionStimuli.isNotEmpty) {
        sessionId = await LocalEvaluationStorage.createSession(
          tipoPrueba: 'FONOLOGIA',
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

    debugPrint('TELEMETRIA LOCAL DE FONOLOGIA - SESION ACTUAL');
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

  Future<void> _restartSession() async {
    final sessionStimuli = _buildSessionStimuli(_allStimuli);

    String? sessionId;

    if (sessionStimuli.isNotEmpty) {
      sessionId = await LocalEvaluationStorage.createSession(
        tipoPrueba: 'FONOLOGIA',
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
      _erroresCurrent = 0;
      _isSavingAnswer = false;
      _isFinishing = false;
      _pendingLocalSessions = LocalEvaluationStorage.countPendingSessions();
    });

    if (_sessionStimuli.isNotEmpty) {
      _prepareCurrentQuestion();
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
    final canSync = _pendingLocalSessions > 0 && !_isSyncing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen fonológico'),
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
              _SummaryTile(label: 'Tipo de prueba', value: 'FONOLOGIA'),
              _SummaryTile(
                label: 'Total de ítems',
                value: '${_answers.length}',
              ),
              _SummaryTile(
                label: 'Aciertos al primer intento',
                value: '$_aciertosPrimerIntento',
              ),
              _SummaryTile(
                label: 'Errores de arrastre totales',
                value: '$_totalErrores',
              ),
              _SummaryTile(
                label: 'Tiempo promedio',
                value: '$_promedioTiempoMs ms',
              ),
              _SummaryTile(
                label: 'Sesiones pendientes',
                value: '$_pendingLocalSessions',
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
