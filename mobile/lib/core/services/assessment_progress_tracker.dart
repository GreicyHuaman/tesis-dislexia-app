import 'dart:async';

import 'package:flutter/widgets.dart';

import '../repositories/local_evaluation_storage.dart';
import 'connection_errors.dart';

class AssessmentProgressTracker with WidgetsBindingObserver {
  final String sessionId;
  final VoidCallback onSaveError;
  final Stopwatch _clock = Stopwatch();
  late final Timer _timer;
  int _itemIndex = 0;
  int _savedElapsedMs = 0;
  int errors = 0;
  bool _recording = false;
  bool _disposed = false;
  bool _backgroundSaving = false;

  AssessmentProgressTracker({
    required this.sessionId,
    required this.onSaveError,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_clock.isRunning) unawaited(_saveInBackground());
    });
  }

  int get elapsedMs => _savedElapsedMs + _clock.elapsedMilliseconds;

  void startItem({
    required int index,
    int savedErrors = 0,
    int savedElapsedMs = 0,
  }) {
    _itemIndex = index;
    errors = savedErrors;
    _savedElapsedMs = savedElapsedMs;
    _clock.stop();
    _clock.reset();
    resumeItem();
  }

  void resumeItem() {
    _recording = true;
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == null || state == AppLifecycleState.resumed) _clock.start();
  }

  void stopItem() {
    _recording = false;
    _clock.stop();
  }

  Future<void> checkpoint() async {
    await LocalEvaluationStorage.saveCurrentItemState(
      sessionId: sessionId,
      itemIndex: _itemIndex,
      errors: errors,
      elapsedMs: elapsedMs,
    );
  }

  Future<void> _saveInBackground() async {
    if (_backgroundSaving) return;
    _backgroundSaving = true;
    try {
      await checkpoint();
    } catch (error, stackTrace) {
      logRequestFailure('Guardar avance de prueba', error, stackTrace);
      if (!_disposed) onSaveError();
    } finally {
      _backgroundSaving = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_recording) _clock.start();
    } else {
      _clock.stop();
      unawaited(_saveInBackground());
    }
  }

  void dispose() {
    _timer.cancel();
    _clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    unawaited(_saveInBackground());
  }
}
