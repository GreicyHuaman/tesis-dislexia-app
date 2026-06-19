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
    text: 'maestra3a@demo.com',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: '123456',
  );

  bool _isLoading = false;
  bool _isCheckingSession = true;
  String? _message;

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
    final savedUser = AuthSessionStorage.getCurrentUserIfValid();

    if (savedUser == null || savedUser.accessToken == null) {
      if (!mounted) return;

      setState(() {
        _isCheckingSession = false;
      });
      return;
    }

    final verifiedUser = await _authService.fetchCurrentUser(
      accessToken: savedUser.accessToken!,
    );

    if (!mounted) return;

    if (verifiedUser == null) {
      await AuthSessionStorage.clearSession();

      if (!mounted) return;

      setState(() {
        _isCheckingSession = false;
      });
      return;
    }

    _openReports(verifiedUser);
  }

  Future<void> _login() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _message = 'Validando credenciales...';
    });

    final result = await _authService.login(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!result.success || result.user == null) {
      setState(() {
        _isLoading = false;
        _message = result.message;
      });
      return;
    }

    await AuthSessionStorage.saveSession(
      user: result.user!,
      expiresInMinutes: result.expiresInMinutes,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _message = result.message;
    });

    _openReports(result.user!);
  }

  void _openReports(AuthUser user) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReportesScreen(
          currentUser: user,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ingreso de personal'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingreso de personal'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 72,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Portal académico',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ingresa con una cuenta de maestra, psicóloga o directora para revisar reportes.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _login,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      _isLoading ? 'Validando...' : 'Ingresar',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message == 'Sesión iniciada correctamente.'
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Credenciales demo: maestra3a@demo.com / 123456',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
