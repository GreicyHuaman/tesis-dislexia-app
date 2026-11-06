import 'package:flutter/material.dart';

import '../../../core/widgets/auto_sync_status_banner.dart';
import '../../../core/models/local_assessment_progress.dart';
import '../../../core/repositories/local_evaluation_storage.dart';
import '../../../core/services/connection_errors.dart';
import '../../auth/screens/pin_login_screen.dart';
import '../../fonologia/screens/fonologia_assessment_screen.dart';
import '../../lectura/screens/lectura_assessment_screen.dart';

class TestSelectionScreen extends StatefulWidget {
  final int estudianteId;
  final String studentDisplayName;
  final int nivelLectura;
  final int nivelFonologia;

  const TestSelectionScreen({
    super.key,
    required this.estudianteId,
    required this.studentDisplayName,
    required this.nivelLectura,
    required this.nivelFonologia,
  });

  @override
  State<TestSelectionScreen> createState() => _TestSelectionScreenState();
}

class _TestSelectionScreenState extends State<TestSelectionScreen> {
  LocalAssessmentProgress? _lectura;
  LocalAssessmentProgress? _fonologia;
  int _legacyLectura = 0;
  int _legacyFonologia = 0;
  bool _isOpening = false;
  String? _progressError;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  @override
  void didUpdateWidget(covariant TestSelectionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.estudianteId != oldWidget.estudianteId) _loadProgress();
  }

  void _loadProgress() {
    try {
      _lectura = LocalEvaluationStorage.getIncompleteAssessment(
        estudianteId: widget.estudianteId,
        tipoPrueba: 'LECTURA',
      );
      _fonologia = LocalEvaluationStorage.getIncompleteAssessment(
        estudianteId: widget.estudianteId,
        tipoPrueba: 'FONOLOGIA',
      );
      _legacyLectura = LocalEvaluationStorage.countLegacyIncomplete(
        estudianteId: widget.estudianteId,
        tipoPrueba: 'LECTURA',
      );
      _legacyFonologia = LocalEvaluationStorage.countLegacyIncomplete(
        estudianteId: widget.estudianteId,
        tipoPrueba: 'FONOLOGIA',
      );
      _progressError = null;
    } catch (error, stackTrace) {
      logRequestFailure('Consultar pruebas guardadas', error, stackTrace);
      _progressError =
          'No se pudo abrir la prueba guardada. Pide ayuda a tu docente.';
    }
  }

  void _changeStudent(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openTest({required bool lectura}) async {
    if (_isOpening || _progressError != null) return;
    setState(() => _isOpening = true);
    try {
      final progress = lectura ? _lectura : _fonologia;
      final legacyCount = lectura ? _legacyLectura : _legacyFonologia;
      if (progress == null && legacyCount > 0) {
        final startNew = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Prueba anterior guardada'),
            content: const Text(
              'No se puede continuar esa prueba anterior. '
              'Sus respuestas se conservarán. Pide ayuda a tu docente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Volver'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Empezar otra'),
              ),
            ],
          ),
        );
        if (startNew != true || !mounted) return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => lectura
              ? LecturaAssessmentScreen(
                  estudianteId: widget.estudianteId,
                  studentDisplayName: widget.studentDisplayName,
                  nivelLectura: widget.nivelLectura,
                )
              : FonologiaAssessmentScreen(
                  estudianteId: widget.estudianteId,
                  studentDisplayName: widget.studentDisplayName,
                  nivelFonologia: widget.nivelFonologia,
                ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpening = false;
          _loadProgress();
        });
      }
    }
  }

  String _progressText(LocalAssessmentProgress? progress, int legacyCount) {
    if (progress != null) {
      return 'Respuestas guardadas: ${progress.answeredItems} de '
          '${progress.totalItems}. Faltan ${progress.remainingItems}.';
    }
    return legacyCount > 0
        ? 'Hay una prueba anterior guardada. Pide ayuda a tu docente.'
        : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar prueba'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => _changeStudent(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.assignment_outlined, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    widget.studentDisplayName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Elige la prueba que realizará el estudiante.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const AutoSyncStatusBanner(),
                  if (_progressError != null) ...[
                    Text(_progressError!),
                    OutlinedButton(
                      onPressed: () => setState(_loadProgress),
                      child: const Text('Reintentar'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _TestOptionCard(
                    title: 'Prueba de lectura',
                    subtitle:
                        'Reconocimiento visual de palabras con respuesta por toque.',
                    icon: Icons.menu_book_outlined,
                    actionLabel: _lectura == null
                        ? 'Empezar lectura'
                        : 'Continuar lectura',
                    progressText: _progressText(_lectura, _legacyLectura),
                    onTap: _isOpening || _progressError != null
                        ? null
                        : () => _openTest(lectura: true),
                  ),
                  const SizedBox(height: 14),
                  _TestOptionCard(
                    title: 'Conciencia fonológica',
                    subtitle:
                        'Identificación de sílaba inicial mediante arrastrar y soltar.',
                    icon: Icons.drag_indicator,
                    actionLabel: _fonologia == null
                        ? 'Empezar fonología'
                        : 'Continuar fonología',
                    progressText: _progressText(_fonologia, _legacyFonologia),
                    onTap: _isOpening || _progressError != null
                        ? null
                        : () => _openTest(lectura: false),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => _changeStudent(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
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

class _TestOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String actionLabel;
  final String progressText;

  const _TestOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    required this.actionLabel,
    required this.progressText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            if (progressText.isNotEmpty) Text(progressText),
            Text(
              actionLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
