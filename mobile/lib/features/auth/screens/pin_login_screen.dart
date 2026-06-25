import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/student_service.dart';
import '../../home/screens/test_selection_screen.dart';
import 'staff_login_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final StudentService _studentService = StudentService();

  bool _isLoading = false;
  bool _obscurePin = true;
  String? _message;
  bool _isSuccessMessage = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submitPin() async {
    if (_isLoading) return;

    final pin = _pinController.text.trim();

    if (pin.length != 4) {
      _setMessage(
        'Ingrese los 4 números de su PIN.',
        isSuccess: false,
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await _studentService.findByPin(pin);

      if (!mounted) return;

      if (!result.success || result.student == null) {
        setState(() {
          _isLoading = false;
          _message = result.message.isNotEmpty
              ? result.message
              : 'No encontramos ese PIN. Revise los números o pida ayuda a su docente.';
          _isSuccessMessage = false;
        });
        return;
      }

      final student = result.student!;
      final studentDisplayName =
          '${student.nombres} ${student.apellidos}'.trim();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TestSelectionScreen(
            estudianteId: student.id,
            studentDisplayName: studentDisplayName,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _message =
            'No se pudo ingresar. Revise el PIN o pida ayuda a su docente.';
        _isSuccessMessage = false;
      });
    }
  }

  void _openStaffLogin() {
    if (_isLoading) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StaffLoginScreen(),
      ),
    );
  }

  void _setMessage(
    String message, {
    required bool isSuccess,
  }) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 18,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(theme),
                  const SizedBox(height: 24),
                  _buildPinCard(theme),
                  const SizedBox(height: 14),
                  if (_message != null) _buildMessageCard(theme),
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
          'Ingrese su PIN de 4 números.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildPinCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _pinController,
              enabled: !_isLoading,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: _obscurePin,
              obscuringCharacter: '•',
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
                  onPressed: () {
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
              onPressed: _isLoading ? null : _submitPin,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(_isLoading ? 'Ingresando...' : 'Empezar'),
            ),
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
              'Opciones protegidas para docentes, psicología o dirección.',
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
