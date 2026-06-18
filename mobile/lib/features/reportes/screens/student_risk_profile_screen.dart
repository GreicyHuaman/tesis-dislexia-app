import 'package:flutter/material.dart';

import '../../../core/models/report_models.dart';
import '../../../core/services/report_service.dart';

class StudentRiskProfileScreen extends StatefulWidget {
  final int estudianteId;
  final int? usuarioId;
  final String? authToken;

  const StudentRiskProfileScreen({
    super.key,
    required this.estudianteId,
    required this.usuarioId,
    required this.authToken,
  });

  @override
  State<StudentRiskProfileScreen> createState() =>
      _StudentRiskProfileScreenState();
}

class _StudentRiskProfileScreenState extends State<StudentRiskProfileScreen> {
  final ReportService _reportService = const ReportService();

  bool _isLoading = true;
  String? _errorMessage;
  StudentRiskProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _reportService.fetchStudentRiskProfile(
        estudianteId: widget.estudianteId,
        authToken: widget.authToken,
      );

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil del estudiante'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(profile),
      ),
    );
  }

  Widget _buildBody(StudentRiskProfile? profile) {
    if (_isLoading && profile == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && profile == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadProfile,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (profile == null) {
      return const Center(
        child: Text('No hay perfil disponible.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          _GeneralProfileCard(profile: profile),
          const SizedBox(height: 16),
          Text(
            'Comparativo por prueba',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          if (profile.pruebas.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'Este estudiante todavía no tiene evaluaciones registradas.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...profile.pruebas.map(
              (testProfile) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TestProfileCard(profile: testProfile),
              ),
            ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Interpretación: este perfil compara el desempeño del estudiante entre pruebas. Es un indicador de tamizaje educativo y no representa diagnóstico clínico.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralProfileCard extends StatelessWidget {
  final StudentRiskProfile profile;

  const _GeneralProfileCard({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final semaforo = profile.ultimoSemaforoGeneral ?? 'SIN_RESULTADO';
    final color = _colorForSemaforo(semaforo);

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 56,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              profile.estudianteTexto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Estudiante ID: ${profile.estudianteId} | Sección ID: ${profile.seccionId ?? 'N/D'}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _MetricRow(
              label: 'Total de evaluaciones',
              value: '${profile.totalEvaluaciones}',
            ),
            _MetricRow(
              label: 'Promedio general de riesgo',
              value: _formatPercent(profile.porcentajePromedioGeneral),
            ),
            _MetricRow(
              label: 'Último riesgo general',
              value: _formatPercent(profile.ultimoPorcentajeRiesgoGeneral),
            ),
            _MetricRow(
              label: 'Último semáforo',
              value: semaforo,
              valueColor: color,
            ),
            _MetricRow(
              label: 'Última evaluación',
              value: profile.ultimaFechaGeneralTexto,
            ),
          ],
        ),
      ),
    );
  }
}

class _TestProfileCard extends StatelessWidget {
  final StudentTestProfile profile;

  const _TestProfileCard({
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final semaforo = profile.ultimoSemaforo ?? 'SIN_RESULTADO';
    final color = _colorForSemaforo(semaforo);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(
                    _iconForTest(profile.tipoPrueba),
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    profile.tipoPruebaTexto,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Text(
                  semaforo,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MetricRow(
              label: 'Evaluaciones',
              value: '${profile.totalEvaluaciones}',
            ),
            _MetricRow(
              label: 'Promedio de riesgo',
              value: _formatPercent(profile.porcentajePromedioRiesgo),
            ),
            _MetricRow(
              label: 'Último riesgo',
              value: _formatPercent(profile.ultimoPorcentajeRiesgo),
            ),
            _MetricRow(
              label: 'Promedio de tiempo',
              value: profile.promedioTiempoMs == null
                  ? 'N/D'
                  : '${profile.promedioTiempoMs!.toStringAsFixed(0)} ms',
            ),
            _MetricRow(
              label: 'Promedio de errores',
              value: profile.promedioErrores == null
                  ? 'N/D'
                  : profile.promedioErrores!.toStringAsFixed(2),
            ),
            _MetricRow(
              label: 'Última fecha',
              value: profile.ultimaFechaTexto,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SemaforoChip(
                  label: 'Verde',
                  total: profile.totalVerde,
                  color: Colors.green,
                ),
                _SemaforoChip(
                  label: 'Amarillo',
                  total: profile.totalAmarillo,
                  color: Colors.orange,
                ),
                _SemaforoChip(
                  label: 'Rojo',
                  total: profile.totalRojo,
                  color: Colors.red,
                ),
                _SemaforoChip(
                  label: 'Sin resultado',
                  total: profile.totalSinResultado,
                  color: Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SemaforoChip extends StatelessWidget {
  final String label;
  final int total;
  final Color color;

  const _SemaforoChip({
    required this.label,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ),
      label: Text(label),
    );
  }
}

String _formatPercent(double? value) {
  if (value == null) return 'N/D';

  return '${value.toStringAsFixed(2)}%';
}

Color _colorForSemaforo(String semaforo) {
  final normalized = semaforo.toUpperCase();

  if (normalized == 'ROJO') return Colors.red;
  if (normalized == 'AMARILLO') return Colors.orange;
  if (normalized == 'VERDE') return Colors.green;

  return Colors.grey;
}

IconData _iconForTest(String tipoPrueba) {
  final normalized = tipoPrueba.toUpperCase();

  if (normalized == 'FONOLOGIA') return Icons.drag_indicator;
  if (normalized == 'LECTURA') return Icons.menu_book_outlined;

  return Icons.assignment_outlined;
}

