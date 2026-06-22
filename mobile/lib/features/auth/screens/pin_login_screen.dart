import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/repositories/local_student_cache.dart';
import '../../../core/services/student_service.dart';
import '../../../core/widgets/auto_sync_status_banner.dart';
import '../../../core/widgets/notice_card.dart';
import '../../home/screens/test_selection_screen.dart';
import '../widgets/offline_cache_setup_dialog.dart';
import 'staff_login_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final StudentService _studentService = const StudentService();

  bool _isLoading = false;
  bool _isCachingStudents = false;
  String? _message;
  bool _isSuccessMessage = false;
  int _cachedStudents = 0;

  @override
  void initState() {
    super.initState();
    _refreshCacheCount();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _refreshCacheCount() {
    _cachedStudents = LocalStudentCache.countCachedStudents();
  }

  Future<void> _prepareOfflineMode() async {
    if (_isLoading || _isCachingStudents) return;

    setState(() {
      _isCachingStudents = true;
      _message = null;
      _isSuccessMessage = false;
    });

    await showOfflineCacheSetupDialog(
      context: context,
      studentService: _studentService,
    );

    if (!mounted) return;

    setState(() {
      _isCachingStudents = false;
      _refreshCacheCount();
    });
  }

  Future<void> _searchStudent() async {
    if (_isLoading || _isCachingStudents) return;

    final pin = _pinController.text.trim();

    setState(() {
      _isLoading = true;
      _message = 'Buscando estudiante...';
      _isSuccessMessage = false;
    });

    final result = await _studentService.findByPin(pin);

    if (!mounted) return;

    if (!result.success || result.student == null) {
      setState(() {
        _isLoading = false;
        _message = result.message;
        _isSuccessMessage = false;
        _refreshCacheCount();
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _message = result.message;
      _isSuccessMessage = true;
      _refreshCacheCount();
    });

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TestSelectionScreen(
          estudianteId: result.student!.id,
          studentDisplayName: result.student!.nombreCompleto,
        ),
      ),
    );
  }

  void _openStaffLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const StaffLoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cacheText = _cachedStudents == 1
        ? '1 estudiante guardado para uso offline'
        : '$_cachedStudents estudiantes guardados para uso offline';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingreso de estudiante'),
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
                    Icons.lock_outline,
                    size: 72,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Ingresa tu PIN',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'El PIN tiene 4 dígitos y permite asociar la evaluación al estudiante correcto.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const NoticeCard(
                    icon: Icons.info_outline,
                    title: 'Tamizaje educativo',
                    message:
                        'La app estima riesgo de forma orientativa. No reemplaza una evaluación profesional ni emite diagnóstico clínico.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    cacheText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AutoSyncStatusBanner(),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _pinController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    enabled: !_isLoading && !_isCachingStudents,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: const TextStyle(
                      fontSize: 30,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _searchStudent(),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: (_isLoading || _isCachingStudents)
                        ? null
                        : _searchStudent,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      _isLoading ? 'Validando...' : 'Iniciar evaluación',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: (_isLoading || _isCachingStudents)
                        ? null
                        : _prepareOfflineMode,
                    icon: _isCachingStudents
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_for_offline_outlined),
                    label: Text(
                      _isCachingStudents
                          ? 'Preparando...'
                          : 'Preparar modo offline',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: (_isLoading || _isCachingStudents)
                        ? null
                        : _openStaffLogin,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Ingresar como personal'),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isSuccessMessage ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Modo offline-first: antes de trabajar sin internet, presiona "Preparar modo offline" con backend activo. Luego los estudiantes podrán iniciar evaluación usando solo la caché local.',
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
