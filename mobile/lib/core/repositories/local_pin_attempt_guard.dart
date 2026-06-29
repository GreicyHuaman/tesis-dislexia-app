import 'package:hive_flutter/hive_flutter.dart';

enum PinAttemptFailureOutcome {
  normalFailure,
  warning,
  temporaryBlocked,
  teacherUnlockRequired,
}

class PinAttemptFailureResult {
  final PinAttemptFailureOutcome outcome;
  final String message;

  const PinAttemptFailureResult({required this.outcome, required this.message});
}

class PinAttemptState {
  final int failedAttempts;
  final int temporaryBlockCount;
  final DateTime? temporaryBlockUntil;
  final bool requiresTeacherUnlock;

  const PinAttemptState({
    required this.failedAttempts,
    required this.temporaryBlockCount,
    required this.temporaryBlockUntil,
    required this.requiresTeacherUnlock,
  });

  factory PinAttemptState.empty() {
    return const PinAttemptState(
      failedAttempts: 0,
      temporaryBlockCount: 0,
      temporaryBlockUntil: null,
      requiresTeacherUnlock: false,
    );
  }

  bool get isTemporarilyBlocked {
    final until = temporaryBlockUntil;

    if (until == null) {
      return false;
    }

    return until.isAfter(DateTime.now());
  }

  Duration get remainingBlockDuration {
    final until = temporaryBlockUntil;

    if (until == null) {
      return Duration.zero;
    }

    final remaining = until.difference(DateTime.now());

    if (remaining.isNegative) {
      return Duration.zero;
    }

    return remaining;
  }

  PinAttemptState copyWith({
    int? failedAttempts,
    int? temporaryBlockCount,
    DateTime? temporaryBlockUntil,
    bool clearTemporaryBlockUntil = false,
    bool? requiresTeacherUnlock,
  }) {
    return PinAttemptState(
      failedAttempts: failedAttempts ?? this.failedAttempts,
      temporaryBlockCount: temporaryBlockCount ?? this.temporaryBlockCount,
      temporaryBlockUntil: clearTemporaryBlockUntil
          ? null
          : temporaryBlockUntil ?? this.temporaryBlockUntil,
      requiresTeacherUnlock:
          requiresTeacherUnlock ?? this.requiresTeacherUnlock,
    );
  }

  factory PinAttemptState.fromMap(Map<String, dynamic> map) {
    final rawUntil = map['temporary_block_until']?.toString();
    final parsedUntil = rawUntil == null || rawUntil.isEmpty
        ? null
        : DateTime.tryParse(rawUntil)?.toLocal();

    return PinAttemptState(
      failedAttempts: _asInt(map['failed_attempts']),
      temporaryBlockCount: _asInt(map['temporary_block_count']),
      temporaryBlockUntil: parsedUntil,
      requiresTeacherUnlock: map['requires_teacher_unlock'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'failed_attempts': failedAttempts,
      'temporary_block_count': temporaryBlockCount,
      'temporary_block_until': temporaryBlockUntil?.toUtc().toIso8601String(),
      'requires_teacher_unlock': requiresTeacherUnlock,
    };
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class LocalPinAttemptGuard {
  static const String _boxName = 'pin_attempt_guard';

  static const int warningThreshold = 3;
  static const int maxFailedAttemptsBeforeBlock = 5;
  static const int temporaryBlockMinutes = 2;
  static const int maxTemporaryBlocksBeforeTeacherUnlock = 3;

  static Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox(_boxName);
    }

    return Hive.box(_boxName);
  }

  static Future<PinAttemptState> getState(String contextKey) async {
    final box = await _box();
    final raw = box.get(contextKey);

    final state = raw is Map
        ? PinAttemptState.fromMap(
            raw.map((key, dynamic value) => MapEntry(key.toString(), value)),
          )
        : PinAttemptState.empty();

    if (!state.requiresTeacherUnlock &&
        state.temporaryBlockUntil != null &&
        !state.isTemporarilyBlocked) {
      final updated = state.copyWith(
        clearTemporaryBlockUntil: true,
        failedAttempts: 0,
      );

      await box.put(contextKey, updated.toMap());

      return updated;
    }

    return state;
  }

  static Future<PinAttemptFailureResult> registerFailure(
    String contextKey,
  ) async {
    final box = await _box();
    final state = await getState(contextKey);

    if (state.requiresTeacherUnlock) {
      return const PinAttemptFailureResult(
        outcome: PinAttemptFailureOutcome.teacherUnlockRequired,
        message:
            'El ingreso está bloqueado. Pide a tu docente o directora que lo desbloquee.',
      );
    }

    if (state.isTemporarilyBlocked) {
      final remaining = _formatDuration(state.remainingBlockDuration);

      return PinAttemptFailureResult(
        outcome: PinAttemptFailureOutcome.temporaryBlocked,
        message:
            'Demasiados intentos. Espera $remaining antes de volver a intentar.',
      );
    }

    final nextFailedAttempts = state.failedAttempts + 1;

    if (nextFailedAttempts >= maxFailedAttemptsBeforeBlock) {
      final nextBlockCount = state.temporaryBlockCount + 1;

      if (nextBlockCount >= maxTemporaryBlocksBeforeTeacherUnlock) {
        final updated = PinAttemptState(
          failedAttempts: 0,
          temporaryBlockCount: nextBlockCount,
          temporaryBlockUntil: null,
          requiresTeacherUnlock: true,
        );

        await box.put(contextKey, updated.toMap());

        return const PinAttemptFailureResult(
          outcome: PinAttemptFailureOutcome.teacherUnlockRequired,
          message:
              'Se alcanzaron varios bloqueos. Pide a tu docente o directora que desbloquee el ingreso.',
        );
      }

      final until = DateTime.now().add(
        const Duration(minutes: temporaryBlockMinutes),
      );

      final updated = PinAttemptState(
        failedAttempts: 0,
        temporaryBlockCount: nextBlockCount,
        temporaryBlockUntil: until,
        requiresTeacherUnlock: false,
      );

      await box.put(contextKey, updated.toMap());

      return const PinAttemptFailureResult(
        outcome: PinAttemptFailureOutcome.temporaryBlocked,
        message:
            'Demasiados intentos. El ingreso queda bloqueado por 2 minutos.',
      );
    }

    final updated = state.copyWith(failedAttempts: nextFailedAttempts);

    await box.put(contextKey, updated.toMap());

    final remaining = maxFailedAttemptsBeforeBlock - nextFailedAttempts;

    if (nextFailedAttempts >= warningThreshold) {
      return PinAttemptFailureResult(
        outcome: PinAttemptFailureOutcome.warning,
        message:
            'PIN no reconocido. Te quedan $remaining intentos antes del bloqueo. Pide ayuda a tu docente.',
      );
    }

    return PinAttemptFailureResult(
      outcome: PinAttemptFailureOutcome.normalFailure,
      message: 'PIN no reconocido. Revisa los números e intenta nuevamente.',
    );
  }

  static Future<void> registerSuccess(String contextKey) async {
    final box = await _box();
    await box.put(contextKey, PinAttemptState.empty().toMap());
  }

  static Future<void> unlockByStaff(String contextKey) async {
    final box = await _box();
    await box.put(contextKey, PinAttemptState.empty().toMap());
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }
}
