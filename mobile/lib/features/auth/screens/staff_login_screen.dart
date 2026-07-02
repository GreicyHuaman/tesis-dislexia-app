import 'package:flutter/material.dart';

import '../../../core/models/auth_user.dart';
import '../../../core/repositories/auth_session_storage.dart';
import '../../../core/services/auth_service.dart';
import '../../reportes/screens/reportes_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final AuthService _authService = const AuthService();

  final TextEditingController _emailController = TextEditingController(
    text: '',
  );
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingSession = true;
  bool _obscurePassword = true;
  String? _message;
  AuthUser? _cachedUser;

  @override
  void initState() {
    super.initState();
    _tryResumeSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryResumeSession() async {
    try {
      final cachedUser = AuthSessionStorage.getCurrentUserIfValid();
      final token = AuthSessionStorage.getAccessTokenIfValid();

      if (!mounted) return;

      if (cachedUser == null || token == null) {
        setState(() {
          _cachedUser = null;
          _isCheckingSession = false;
        });
        return;
      }

      final verifiedUser = await _authService.fetchCurrentUser(
        accessToken: token,
      );

      if (!mounted) return;

      setState(() {
        _cachedUser = verifiedUser ?? cachedUser;
        _isCheckingSession = false;
      });
    } catch (_) {
      await AuthSessionStorage.clearSession();

      if (!mounted) return;

      setState(() {
        _cachedUser = null;
        _isCheckingSession = false;
      });
    }
  }

  Future<void> _switchAccount() async {
    await AuthSessionStorage.clearSession();

    if (!mounted) return;

    setState(() {
      _cachedUser = null;
      _message = null;
      _emailController.clear();
      _passwordController.clear();
    });
  }

  void _continueCachedSession() {
    final user = _cachedUser;

    if (user == null) return;

    _openStaffHome(user);
  }

  Future<void> _login() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Ingrese su correo y contraseña.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final result = await _authService.login(email: email, password: password);

      if (!mounted) return;

      if (!result.success || result.user == null) {
        setState(() {
          _isLoading = false;
          _message = result.message.isNotEmpty
              ? result.message
              : 'No se pudo iniciar sesión. Verifique sus credenciales.';
        });
        return;
      }

      await AuthSessionStorage.saveSession(
        user: result.user!,
        expiresInMinutes: result.expiresInMinutes,
      );

      if (!mounted) return;

      _openStaffHome(result.user!);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _message =
            'No se pudo conectar con el servidor. Intente nuevamente cuando el servicio esté disponible.';
      });
    }
  }

  void _openStaffHome(AuthUser user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReportesScreen(currentUser: user)),
    );
  }

  String _roleLabel(AuthUser user) {
    final role = user.rol.toUpperCase();

    if (role == 'DIRECTORA') return 'Director';
    if (role == 'MAESTRO') return 'Maestro';
    if (role == 'PSICOLOGA') return 'Psicología';

    return user.rol;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isCheckingSession) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    'Verificando sesión...',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Espere un momento.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Personal educativo')),
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
                  const SizedBox(height: 24),
                  if (_cachedUser != null)
                    _buildCachedSessionCard(theme)
                  else
                    _buildLoginCard(theme),
                  const SizedBox(height: 14),
                  if (_message != null) _buildMessageCard(theme),
                  const SizedBox(height: 18),
                  _buildInfoCard(theme),
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
            Icons.admin_panel_settings_outlined,
            size: 44,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ingreso del personal educativo',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Acceda con sus credenciales para revisar reportes, activar modo aula o actualizar el padrón offline.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildCachedSessionCard(ThemeData theme) {
    final user = _cachedUser!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 42,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Sesión guardada',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${user.nombreCompleto}\n${user.email}\nRol: ${_roleLabel(user)}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.35,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _continueCachedSession,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continuar con esta sesión'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _switchAccount,
              icon: const Icon(Icons.switch_account_outlined),
              label: const Text('Cambiar usuario'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Correo institucional',
                hintText: 'usuario@colegio.com',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              obscuringCharacter: '*',
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              onSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _isLoading ? null : _login,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(_isLoading ? 'Ingresando...' : 'Ingresar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageCard(ThemeData theme) {
    final color = theme.colorScheme.error;

    return Card(
      color: color.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: color),
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

  Widget _buildInfoCard(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.verified_user_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Director: administración completa. Docente: modo aula y estudiantes asignados. Psicología: reportes y seguimiento.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
