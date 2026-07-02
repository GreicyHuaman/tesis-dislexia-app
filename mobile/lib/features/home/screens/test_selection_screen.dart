import 'package:flutter/material.dart';

import '../../../core/widgets/auto_sync_status_banner.dart';
import '../../auth/screens/pin_login_screen.dart';
import '../../fonologia/screens/fonologia_assessment_screen.dart';
import '../../lectura/screens/lectura_assessment_screen.dart';

class TestSelectionScreen extends StatelessWidget {
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

  void _changeStudent(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PinLoginScreen()),
      (route) => false,
    );
  }

  void _openLectura(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LecturaAssessmentScreen(
          estudianteId: estudianteId,
          studentDisplayName: studentDisplayName,
          nivelLectura: nivelLectura,
        ),
      ),
    );
  }

  void _openFonologia(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FonologiaAssessmentScreen(
          estudianteId: estudianteId,
          studentDisplayName: studentDisplayName,
          nivelFonologia: nivelFonologia,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar prueba'),
        actions: [
          IconButton(
            tooltip: 'Cambiar estudiante',
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
                    studentDisplayName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Elige la prueba que realizarÃ¡ el estudiante.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const AutoSyncStatusBanner(),
                  const SizedBox(height: 24),
                  _TestOptionCard(
                    title: 'Prueba de lectura',
                    subtitle:
                        'Reconocimiento visual de palabras con respuesta por toque.',
                    icon: Icons.menu_book_outlined,
                    onTap: () => _openLectura(context),
                  ),
                  const SizedBox(height: 14),
                  _TestOptionCard(
                    title: 'Conciencia fonolÃ³gica',
                    subtitle:
                        'IdentificaciÃ³n de sÃ­laba inicial mediante arrastrar y soltar.',
                    icon: Icons.drag_indicator,
                    onTap: () => _openFonologia(context),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => _changeStudent(context),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cambiar estudiante'),
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
  final VoidCallback onTap;

  const _TestOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
