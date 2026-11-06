import 'package:flutter/material.dart';

import '../../../core/models/report_models.dart';

class InstitutionalSummaryCard extends StatelessWidget {
  final InstitutionalSummary? summary;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  const InstitutionalSummaryCard({
    super.key,
    required this.summary,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final data = summary;
    final coverage = data?.porcentajeCobertura;
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumen institucional',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            const Text(
              'Todos los registros del alcance autorizado, incluidos los inactivos.',
            ),
            if (isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
              if (data != null)
                const Text(
                  'Se conserva el último resumen cargado; podría no estar actualizado.',
                ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar resumen institucional'),
                ),
              ),
            ],
            if (data != null) ...[
              const SizedBox(height: 14),
              _InstitutionalMetric(
                label: 'Total de secciones',
                value: data.totalSecciones,
                valueKey: const ValueKey('institutional-sections-total'),
                detail:
                    'Activas: ${data.seccionesActivas} | Inactivas: ${data.seccionesInactivas}',
              ),
              _InstitutionalMetric(
                label: 'Total de estudiantes',
                value: data.totalEstudiantes,
                valueKey: const ValueKey('institutional-students-total'),
                detail:
                    'Activos: ${data.estudiantesActivos} | Inactivos: ${data.estudiantesInactivos}',
              ),
              _InstitutionalMetric(
                label: 'Total de evaluaciones',
                value: data.totalEvaluaciones,
                valueKey: const ValueKey('institutional-evaluations-total'),
                detail: 'Registradas en el servidor',
              ),
              const Divider(),
              Text(
                'Avance de evaluación',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Con al menos una evaluación: ${data.estudiantesConEvaluaciones}',
              ),
              Text('Sin evaluaciones: ${data.estudiantesSinEvaluaciones}'),
              if (coverage != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: coverage / 100),
                const SizedBox(height: 4),
                Text(
                  'Cobertura: ${coverage.toStringAsFixed(1)}% de estudiantes registrados',
                ),
              ] else
                const Text('No hay estudiantes registrados.'),
              const SizedBox(height: 12),
              const Text(
                'Este resumen apoya el tamizaje educativo y el seguimiento pedagógico; no constituye diagnóstico clínico.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InstitutionalMetric extends StatelessWidget {
  final String label;
  final int value;
  final Key valueKey;
  final String detail;

  const _InstitutionalMetric({
    required this.label,
    required this.value,
    required this.valueKey,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(detail, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$value',
          key: valueKey,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );
}
