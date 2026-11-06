import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../repositories/local_evaluation_storage.dart';
import 'evaluation_sync_service.dart';
import 'connection_errors.dart';

enum AutoSyncPhase { idle, offline, syncing, synced, error }

class AutoSyncSnapshot {
  final AutoSyncPhase phase;
  final String message;
  final int pendingSessions;
  final String connectionLabel;
  final DateTime updatedAt;
  final double? porcentajeRiesgo;
  final String? semaforo;

  const AutoSyncSnapshot({
    required this.phase,
    required this.message,
    required this.pendingSessions,
    required this.connectionLabel,
    required this.updatedAt,
    this.porcentajeRiesgo,
    this.semaforo,
  });

  bool get isBusy => phase == AutoSyncPhase.syncing;
}

class AutoSyncService {
  AutoSyncService._();

  static final AutoSyncService instance = AutoSyncService._();

  final Connectivity _connectivity = Connectivity();
  final EvaluationSyncService _syncService = const EvaluationSyncService();

  final ValueNotifier<AutoSyncSnapshot> status =
      ValueNotifier<AutoSyncSnapshot>(
        AutoSyncSnapshot(
          phase: AutoSyncPhase.idle,
          message: 'Sincronización automática lista.',
          pendingSessions: 0,
          connectionLabel: 'No verificado',
          updatedAt: DateTime.now(),
        ),
      );

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _isStarted = false;
  bool _isSyncing = false;

  Future<void> start() async {
    if (_isStarted) return;

    _isStarted = true;

    await checkAndSync(reason: 'inicio_app');

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        unawaited(_handleConnectivity(results, reason: 'cambio_conectividad'));
      },
      onError: (Object error, StackTrace stackTrace) {
        logRequestFailure('Escuchar conectividad', error, stackTrace);
        _updateStatus(
          phase: AutoSyncPhase.error,
          message: connectionCheckFailedMessage,
          connectionLabel: 'Error',
        );
      },
    );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _isStarted = false;
  }

  Future<void> checkAndSync({String reason = 'manual'}) async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _handleConnectivity(results, reason: reason);
    } on PlatformException catch (error, stackTrace) {
      _reportCheckFailure(error, stackTrace, connectionCheckFailedMessage);
    } on MissingPluginException catch (error, stackTrace) {
      _reportCheckFailure(error, stackTrace, connectionCheckFailedMessage);
    } on HiveError catch (error, stackTrace) {
      _reportCheckFailure(
        error,
        stackTrace,
        'No se pudo consultar el envío guardado. Pida ayuda al personal educativo.',
      );
    }
  }

  void _reportCheckFailure(
    Object error,
    StackTrace stackTrace,
    String message,
  ) {
    logRequestFailure('Revisar sincronización', error, stackTrace);
    _updateStatus(
      phase: AutoSyncPhase.error,
      message: message,
      pendingSessions: status.value.pendingSessions,
      connectionLabel: status.value.connectionLabel,
    );
  }

  Future<void> syncNow() async {
    await checkAndSync(reason: 'manual');
  }

  Future<void> _handleConnectivity(
    List<ConnectivityResult> results, {
    required String reason,
  }) async {
    final connectionLabel = _connectionLabel(results);
    final pendingSessions =
        LocalEvaluationStorage.countCompletedPendingSyncSessions();

    if (!_hasNetwork(results)) {
      _updateStatus(
        phase: AutoSyncPhase.offline,
        message: noInternetMessage,
        pendingSessions: pendingSessions,
        connectionLabel: connectionLabel,
      );
      return;
    }

    if (pendingSessions == 0) {
      _updateStatus(
        phase: AutoSyncPhase.synced,
        message: 'No hay sesiones pendientes para sincronizar.',
        pendingSessions: 0,
        connectionLabel: connectionLabel,
      );
      return;
    }

    await _syncPending(
      connectionLabel: connectionLabel,
      pendingSessions: pendingSessions,
      reason: reason,
    );
  }

  Future<void> _syncPending({
    required String connectionLabel,
    required int pendingSessions,
    required String reason,
  }) async {
    if (_isSyncing) return;

    _isSyncing = true;

    try {
      _updateStatus(
        phase: AutoSyncPhase.syncing,
        message:
            'Sincronizando automáticamente $pendingSessions sesión(es) pendiente(s)...',
        pendingSessions: pendingSessions,
        connectionLabel: connectionLabel,
      );

      final result = await _syncService.syncPendingEvaluations();

      final remainingSessions =
          LocalEvaluationStorage.countCompletedPendingSyncSessions();

      if (result.success) {
        _updateStatus(
          phase: AutoSyncPhase.synced,
          message: result.message,
          pendingSessions: remainingSessions,
          connectionLabel: connectionLabel,
          porcentajeRiesgo: result.porcentajeRiesgo,
          semaforo: result.semaforo,
        );
      } else {
        _updateStatus(
          phase: AutoSyncPhase.error,
          message: result.message,
          pendingSessions: remainingSessions,
          connectionLabel: connectionLabel,
        );
      }
    } finally {
      _isSyncing = false;
    }
  }

  bool _hasNetwork(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;

    return results.any((result) => result != ConnectivityResult.none);
  }

  String _connectionLabel(List<ConnectivityResult> results) {
    if (results.isEmpty) return 'Sin conexión';

    if (results.contains(ConnectivityResult.none)) {
      return 'Sin conexión';
    }

    if (results.contains(ConnectivityResult.wifi)) {
      return 'Wi-Fi';
    }

    if (results.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    }

    if (results.contains(ConnectivityResult.mobile)) {
      return 'Datos móviles';
    }

    return results.map((result) => result.name).join(', ');
  }

  void _updateStatus({
    required AutoSyncPhase phase,
    required String message,
    int? pendingSessions,
    String? connectionLabel,
    double? porcentajeRiesgo,
    String? semaforo,
  }) {
    status.value = AutoSyncSnapshot(
      phase: phase,
      message: message,
      pendingSessions:
          pendingSessions ??
          LocalEvaluationStorage.countCompletedPendingSyncSessions(),
      connectionLabel: connectionLabel ?? status.value.connectionLabel,
      updatedAt: DateTime.now(),
      porcentajeRiesgo: porcentajeRiesgo,
      semaforo: semaforo,
    );
  }
}
