import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/repositories/local_classroom_mode_storage.dart';
import '../../../core/repositories/local_pin_attempt_guard.dart';
import '../../../core/services/student_service.dart';
import '../../home/screens/test_selection_screen.dart';
import 'staff_login_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  static const _missingClassroomNotice =
      'No hay una sección preparada con jornada vigente. '
      'Pide al docente que use “Descargar sección” con conexión a Internet.';
  final TextEditingController _pinController = TextEditingController();
  final StudentService _studentService = StudentService();

  bool _isLoading = false;
  bool _obscurePin = true;
  String? _message;
  bool _isSuccessMessage = false;

  ClassroomModeState? _classroomMode;
  PinAttemptState? _attemptState;
  Timer? _blockTimer;

  String get _pinGuardContextKey {
    return _classroomMode?.pinGuardContextKey ?? 'student_pin_login_global';
  }

  bool get _hasClassroomMode {
    return _classroomMode != null;
  }

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  @override
  void dispose() {
    _blockTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialState() async {
    await _loadClassroomMode();
    await _loadAttemptState();
  }

  Future<void> _loadClassroomMode() async {
    final mode = await LocalClassroomModeStorage.getCurrent();

    if (!mounted) return;

    setState(() {
      _classroomMode = mode;
    });
  }

  Future<void> _loadAttemptState() async {
    final state = await LocalPinAttemptGuard.getState(_pinGuardContextKey);

    if (!mounted) return;

    setState(() {
      _attemptState = state;
    });

    _configureBlockTimer();
  }

  void _configureBlockTimer() {
    _blockTimer?.cancel();

    final state = _attemptState;

    if (state == null || !state.isTemporarilyBlocked) {
      return;
    }

    _blockTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final current = await LocalPinAttemptGuard.getState(_pinGuardContextKey);

      if (!mounted) return;

      setState(() {
        _attemptState = current;
      });

      if (!current.isTemporarilyBlocked) {
        _blockTimer?.cancel();
      }
    });
  }

  PinAttemptState get _currentAttemptState {
    return _attemptState ?? PinAttemptState.empty();
  }

  bool get _isPinInputLocked {
    final state = _currentAttemptState;

    return !_hasClassroomMode ||
        state.requiresTeacherUnlock ||
        state.isTemporarilyBlocked;
  }

  Future<void> _submitPin() async {
    if (_isLoading) return;

    final mode = await LocalClassroomModeStorage.getCurrent();

    if (mode == null) {
      await _loadClassroomMode();

      _setMessage(_missingClassroomNotice, isSuccess: false);
      return;
    }

    setState(() {
      _classroomMode = mode;
    });

    final state = await LocalPinAttemptGuard.getState(mode.pinGuardContextKey);

    if (state.requiresTeacherUnlock) {
      _setMessage(
        'El ingreso est? bloqueado. Pide a tu docente o director que lo desbloquee.',
        isSuccess: false,
      );
      await _loadAttemptState();
      return;
    }

    if (state.isTemporarilyBlocked) {
      _setMessage(
        'Demasiados intentos. Espera ${_formatDuration(state.remainingBlockDuration)} antes de volver a intentar.',
        isSuccess: false,
      );
      await _loadAttemptState();
      return;
    }

    final pin = _pinController.text.trim();

    if (pin.length != 4) {
      _setMessage('Ingrese los 4 numeros de su PIN.', isSuccess: false);
      return;
    }

    if (!mounted) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await _studentService.findByPinForModoAula(
        seccionId: mode.seccionId,
        pin: pin,
      );

      if (!mounted) return;

      if (!result.success || result.student == null) {
        if (result.requiresOfflinePreparation) {
          setState(() {
            _isLoading = false;
            _message = result.message;
            _isSuccessMessage = false;
          });
          return;
        }
        final message = result.message.toLowerCase();

        if (message.contains('jornada activa') ||
            message.contains('seccion') && message.contains('jornada')) {
          await LocalClassroomModeStorage.clear();
          await _loadClassroomMode();

          if (!mounted) return;

          setState(() {
            _isLoading = false;
            _message = result.message;
            _isSuccessMessage = false;
          });
          return;
        }

        final guardResult = await LocalPinAttemptGuard.registerFailure(
          mode.pinGuardContextKey,
        );

        await _loadAttemptState();

        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _message = guardResult.message;
          _isSuccessMessage = false;
        });
        return;
      }

      await LocalPinAttemptGuard.registerSuccess(mode.pinGuardContextKey);

      final student = result.student!;
      final studentDisplayName = '${student.nombres} ${student.apellidos}'
          .trim();

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TestSelectionScreen(
            estudianteId: student.id,
            studentDisplayName: studentDisplayName,
            nivelLectura: student.nivelLectura,
            nivelFonologia: student.nivelFonologia,
          ),
        ),
      );
    } catch (_) {
      final guardResult = await LocalPinAttemptGuard.registerFailure(
        mode.pinGuardContextKey,
      );

      await _loadAttemptState();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _message = guardResult.message;
        _isSuccessMessage = false;
      });
    }
  }

  Future<void> _showTeacherUnlockDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        var dialogLoading = false;
        String? dialogMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Desbloqueo por personal educativo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ingrese credenciales de docente o direccion para desbloquear el ingreso por PIN.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      enabled: !dialogLoading,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      enabled: !dialogLoading,
                      obscureText: true,
                      obscuringCharacter: '*',
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (dialogMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: dialogLoading
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);

                          setDialogState(() {
                            dialogLoading = true;
                            dialogMessage = null;
                          });

                          final result = await _studentService
                              .validateStaffCredentialsForPinUnlock(
                                email: emailController.text,
                                password: passwordController.text,
                              );

                          if (!mounted || !dialogContext.mounted) return;

                          if (!result.success) {
                            setDialogState(() {
                              dialogLoading = false;
                              dialogMessage = result.message;
                            });
                            return;
                          }

                          await LocalPinAttemptGuard.unlockByStaff(
                            _pinGuardContextKey,
                          );

                          if (!mounted || !dialogContext.mounted) return;

                          navigator.pop(true);
                        },
                  icon: dialogLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_outlined),
                  label: Text(dialogLoading ? 'Validando...' : 'Desbloquear'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    passwordController.dispose();

    if (unlocked == true) {
      await _loadAttemptState();

      if (!mounted) return;

      _pinController.clear();

      _setMessage(
        'Ingreso desbloqueado. El estudiante puede intentar nuevamente.',
        isSuccess: true,
      );
    }
  }

  void _openStaffLogin() {
    if (_isLoading) return;

    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const StaffLoginScreen()))
        .then((_) => _loadInitialState());
  }

  void _setMessage(String message, {required bool isSuccess}) {
    setState(() {
      _message = message;
      _isSuccessMessage = isSuccess;
    });
  }

  Color _messageColor(BuildContext context) {
    if (_isSuccessMessage) {
      return Colors.green;
    }

    return Theme.of(context).colorScheme.error;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  bool get _shouldShowSecurityStatus {
    final state = _currentAttemptState;

    return state.failedAttempts > 0 ||
        state.temporaryBlockCount > 0 ||
        state.requiresTeacherUnlock ||
        state.isTemporarilyBlocked;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 16),
                  _buildClassroomStatusCard(theme),
                  const SizedBox(height: 16),
                  _buildPinCard(theme),
                  const SizedBox(height: 14),
                  if (_message != null) _buildMessageCard(theme),
                  if (_shouldShowSecurityStatus) ...[
                    const SizedBox(height: 14),
                    _buildSecurityStatusCard(theme),
                  ],
                  const SizedBox(height: 18),
                  _buildStaffAccessCard(theme),
                  const SizedBox(height: 16),
                  _buildFooter(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.school_outlined,
            size: 44,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bienvenido a Disly',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingrese su PIN de 4 numeros.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildClassroomStatusCard(ThemeData theme) {
    final mode = _classroomMode;

    if (mode == null) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.event_busy_outlined, color: theme.colorScheme.error),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  _missingClassroomNotice,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.class_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Modo aula activo: ${mode.sectionDisplayName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinCard(ThemeData theme) {
    final locked = _isPinInputLocked;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pinController,
              enabled: !_isLoading && !locked,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: _obscurePin,
              obscuringCharacter: '*',
              enableSuggestions: false,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'PIN',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePin ? 'Mostrar PIN' : 'Ocultar PIN',
                  icon: Icon(
                    _obscurePin
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: locked
                      ? null
                      : () {
                          setState(() {
                            _obscurePin = !_obscurePin;
                          });
                        },
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submitPin(),
            ),
            const SizedBox(height: 16),
            _buildPinDots(theme),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isLoading || locked ? null : _submitPin,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : locked
                  ? const Icon(Icons.lock_outline)
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(
                _isLoading
                    ? 'Ingresando...'
                    : !_hasClassroomMode
                    ? 'Sin jornada activa'
                    : locked
                    ? 'Acceso bloqueado'
                    : 'Empezar',
              ),
            ),
            if (_currentAttemptState.requiresTeacherUnlock) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showTeacherUnlockDialog,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Desbloquear con personal educativo'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPinDots(ThemeData theme) {
    final length = _pinController.text.trim().length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < length;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: isFilled ? 14 : 11,
          height: isFilled ? 14 : 11,
          decoration: BoxDecoration(
            color: isFilled
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildMessageCard(ThemeData theme) {
    final color = _messageColor(context);

    return Card(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _isSuccessMessage
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityStatusCard(ThemeData theme) {
    final state = _currentAttemptState;
    final color = state.requiresTeacherUnlock || state.isTemporarilyBlocked
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    String text;

    if (state.requiresTeacherUnlock) {
      text =
          'Ingreso bloqueado. Se requiere desbloqueo por docente o direccion.';
    } else if (state.isTemporarilyBlocked) {
      text =
          'Bloqueo temporal activo. Tiempo restante: ${_formatDuration(state.remainingBlockDuration)}.';
    } else {
      text =
          'Intentos fallidos: ${state.failedAttempts}/5. Bloqueos temporales: ${state.temporaryBlockCount}/3.';
    }

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.security_outlined, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffAccessCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Acceso para personal educativo',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Opciones protegidas para docentes, psicologia o direccion.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _isLoading ? null : _openStaffLogin,
              icon: const Icon(Icons.login_outlined),
              label: const Text('Ingresar como personal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Text(
      'Tamizaje educativo temprano. No reemplaza una evaluación profesional.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.3,
      ),
    );
  }
}
