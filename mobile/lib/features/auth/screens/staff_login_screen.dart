import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../reportes/screens/reportes_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final TextEditingController _emailController = TextEditingController(
    text: 'maestra3a@demo.com',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: '123456',
  );

  final AuthService _authService = const AuthService();

  bool _isLoading = false;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReportesScreen(
          currentUser: result.user!,
        ),
      ),
    );
  }

  void _useDemoCredential(String email) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = '123456';
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso del personal'),
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
                  const SizedBox(height: 18),
                  Text(
                    'Ingreso a reportes',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'El acceso se filtra según el rol del usuario.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: true,
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
                      _isLoading ? 'Ingresando...' : 'Ingresar',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Credenciales demo',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _useDemoCredential(
                                  'maestra3a@demo.com',
                                ),
                        child: const Text('Maestra 3A'),
                      ),
                      OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _useDemoCredential(
                                  'psicologa@demo.com',
                                ),
                        child: const Text('Psicóloga'),
                      ),
                      OutlinedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _useDemoCredential(
                                  'directora@demo.com',
                                ),
                        child: const Text('Directora'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Contraseña demo para todos: 123456',
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
