import 'package:flutter/material.dart';

import '../../../core/models/auth_user.dart';
import '../../../core/models/seguimiento_models.dart';
import '../../../core/services/connection_errors.dart';
import '../../../core/services/seguimiento_service.dart';
import '../widgets/observation_dialog.dart';

class SeguimientoScreen extends StatefulWidget {
  final AuthUser currentUser;

  const SeguimientoScreen({super.key, required this.currentUser});

  @override
  State<SeguimientoScreen> createState() => _SeguimientoScreenState();
}

class _SeguimientoScreenState extends State<SeguimientoScreen> {
  final SeguimientoService _seguimientoService = const SeguimientoService();

  bool _isLoading = true;
  String? _errorMessage;

  SeguimientoResumen? _resumen;
  List<SeguimientoItem> _items = [];

  String? _selectedPrioridad;
  String? _selectedEstadoSemanal;

  @override
  void initState() {
    super.initState();
    _loadSeguimiento();
  }

  Future<void> _loadSeguimiento() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resumen = await _seguimientoService.fetchResumen(
        authToken: widget.currentUser.accessToken,
      );

      final items = await _seguimientoService.fetchPriorizados(
        authToken: widget.currentUser.accessToken,
        prioridad: _selectedPrioridad,
        estadoSemanal: _selectedEstadoSemanal,
      );

      if (!mounted) return;

      setState(() {
        _resumen = resumen;
        _items = items;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      logRequestFailure('Cargar seguimiento', error, stackTrace);
      if (!mounted) return;

      setState(() {
        _errorMessage = requestErrorMessage(
          error,
          fallbackMessage:
              'No se pudo cargar el seguimiento. Vuelva a intentarlo.',
        );
        _isLoading = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedPrioridad = null;
      _selectedEstadoSemanal = null;
    });

    _loadSeguimiento();
  }

  Future<void> _openObservationDialog(SeguimientoItem item) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ObservationDialog(
        item: item,
        authToken: widget.currentUser.accessToken,
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observación guardada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadSeguimiento();
    }
  }

  void _openHistoryDialog(SeguimientoItem item) {
    final future = _seguimientoService.fetchHistorial(
      authToken: widget.currentUser.accessToken,
      estudianteId: item.estudianteId,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Historial longitudinal'),
          content: SizedBox(
            width: 560,
            child: FutureBuilder<SeguimientoHistorial>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  final error = snapshot.error!;
                  return Text(
                    requestErrorMessage(
                      error,
                      fallbackMessage:
                          'No se pudo cargar el historial. Vuelva a intentarlo.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }

                final historial = snapshot.data;

                if (historial == null) {
                  return const Text('No hay historial disponible.');
                }

                return _buildHistoryContent(historial);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryContent(SeguimientoHistorial historial) {
    final observaciones = historial.observaciones;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            historial.estudianteNombre,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Estado actual: ${historial.actual.estadoSemanalTexto}\n'
            'Prioridad: ${historial.actual.prioridad}\n'
            'Tendencia: ${historial.actual.tendenciaTexto}\n'
            'Próxima evaluación: ${historial.actual.proximaEvaluacion ?? 'Pendiente'}',
            style: const TextStyle(height: 1.35),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Observaciones registradas',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (observaciones.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Todavía no hay observaciones docentes registradas.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...observaciones.map(_buildHistoryEntry),
        ],
      ),
    );
  }

  Widget _buildHistoryEntry(SeguimientoObservacion observacion) {
    final categorias = observacion.categorias;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_shortDate(observacion.fechaSeguimiento)} | ${observacion.estado}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Responsable: ${observacion.responsableNombre ?? 'N/D'}\n'
              'Semáforo: ${observacion.semaforo ?? 'N/D'} | '
              'Prioridad: ${observacion.prioridad ?? 'N/D'} | '
              'Tendencia: ${observacion.tendencia ?? 'N/D'}',
              style: const TextStyle(height: 1.3),
            ),
            if (observacion.observacionDocente != null &&
                observacion.observacionDocente!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                observacion.observacionDocente!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            if (categorias.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: categorias
                    .map(
                      (category) => Chip(
                        label: Text(category),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shortDate(String raw) {
    if (raw.length >= 10) {
      return raw.substring(0, 10);
    }

    return raw.isEmpty ? 'N/D' : raw;
  }

  @override
  Widget build(BuildContext context) {
    final resumen = _resumen;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento semanal'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadSeguimiento,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar seguimiento',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSeguimiento,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _HeaderCard(user: widget.currentUser),
              const SizedBox(height: 14),
              if (_isLoading && resumen == null)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_errorMessage != null) _buildErrorCard(),
                if (resumen != null) _ResumenSeguimientoCard(resumen: resumen),
                const SizedBox(height: 14),
                _buildFilterCard(),
                const SizedBox(height: 14),
                if (_isLoading) const LinearProgressIndicator(),
                const SizedBox(height: 14),
                _buildListHeader(),
                const SizedBox(height: 10),
                if (_items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No hay estudiantes con los filtros seleccionados.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SeguimientoItemCard(
                        item: item,
                        onRegisterObservation: () =>
                            _openObservationDialog(item),
                        onOpenHistory: () => _openHistoryDialog(item),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.55),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filtros de seguimiento',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedPrioridad,
              decoration: const InputDecoration(
                labelText: 'Prioridad',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(value: null, child: Text('Todas')),
                DropdownMenuItem<String>(value: 'ALTA', child: Text('Alta')),
                DropdownMenuItem<String>(value: 'MEDIA', child: Text('Media')),
                DropdownMenuItem<String>(value: 'BAJA', child: Text('Baja')),
              ],
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedPrioridad = value;
                      });
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedEstadoSemanal,
              decoration: const InputDecoration(
                labelText: 'Estado semanal',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(value: null, child: Text('Todos')),
                DropdownMenuItem<String>(
                  value: 'SIN_EVALUACION',
                  child: Text('Sin evaluación'),
                ),
                DropdownMenuItem<String>(
                  value: 'AL_DIA',
                  child: Text('Al día'),
                ),
                DropdownMenuItem<String>(
                  value: 'VENCE_HOY',
                  child: Text('Vence hoy'),
                ),
                DropdownMenuItem<String>(
                  value: 'VENCIDA',
                  child: Text('Vencida'),
                ),
              ],
              onChanged: _isLoading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedEstadoSemanal = value;
                      });
                    },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                ),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _loadSeguimiento,
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: const Text('Aplicar filtros'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Estudiantes priorizados',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '${_items.length} resultado(s)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AuthUser user;

  const _HeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.30),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.event_note_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 34,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seguimiento semanal longitudinal',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${user.nombreCompleto}\n${user.rolTexto}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tamizaje educativo. No constituye diagnóstico clínico.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenSeguimientoCard extends StatelessWidget {
  final SeguimientoResumen resumen;

  const _ResumenSeguimientoCard({required this.resumen});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumen semanal',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricChip(
                  label: 'Total',
                  value: resumen.totalEstudiantes,
                  icon: Icons.groups_outlined,
                ),
                _MetricChip(
                  label: 'Sin evaluación',
                  value: resumen.sinEvaluacion,
                  icon: Icons.help_outline,
                ),
                _MetricChip(
                  label: 'Al día',
                  value: resumen.alDia,
                  icon: Icons.check_circle_outline,
                ),
                _MetricChip(
                  label: 'Vence hoy',
                  value: resumen.venceHoy,
                  icon: Icons.today_outlined,
                ),
                _MetricChip(
                  label: 'Vencida',
                  value: resumen.vencida,
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _PriorityChip(label: 'Alta', value: resumen.prioridadAlta),
                _PriorityChip(label: 'Media', value: resumen.prioridadMedia),
                _PriorityChip(label: 'Baja', value: resumen.prioridadBaja),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text('$label: $value'));
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final int value;

  const _PriorityChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        child: Text('$value', style: const TextStyle(fontSize: 12)),
      ),
      label: Text('Prioridad $label'),
    );
  }
}

class _SeguimientoItemCard extends StatelessWidget {
  final SeguimientoItem item;
  final VoidCallback onRegisterObservation;
  final VoidCallback onOpenHistory;

  const _SeguimientoItemCard({
    required this.item,
    required this.onRegisterObservation,
    required this.onOpenHistory,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(item.prioridad);
    final statusText = item.estadoSemanalTexto;
    final trendText = item.tendenciaTexto;
    final riskText = item.porcentajeRiesgo == null
        ? 'Sin riesgo calculado'
        : '${item.porcentajeRiesgo!.toStringAsFixed(1)}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            ListTile(
              onTap: onOpenHistory,
              leading: CircleAvatar(
                backgroundColor: priorityColor.withValues(alpha: 0.16),
                child: Icon(
                  _priorityIcon(item.prioridad),
                  color: priorityColor,
                ),
              ),
              title: Text(
                item.estudianteNombre,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Prioridad: ${item.prioridad}\n'
                  'Estado semanal: $statusText\n'
                  'Tendencia: $trendText\n'
                  'Riesgo: $riskText | Semáforo: ${item.semaforo ?? 'N/D'}\n'
                  'Próxima evaluación: ${item.proximaEvaluacion ?? 'Pendiente'}\n'
                  'Acción sugerida: ${item.accionSugerida}',
                  style: const TextStyle(height: 1.32),
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_estadoIcon(item.estadoSemanal), color: priorityColor),
                  const SizedBox(height: 4),
                  Text(
                    item.diasDesdeUltimaEvaluacion == null
                        ? 'N/D'
                        : '${item.diasDesdeUltimaEvaluacion} d',
                    style: TextStyle(
                      color: priorityColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (item.observacionDocente != null &&
                item.observacionDocente!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Última observación: ${item.observacionDocente}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: onOpenHistory,
                    icon: const Icon(Icons.history_outlined),
                    label: const Text('Ver historial'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onRegisterObservation,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Registrar observación'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(String prioridad) {
    final normalized = prioridad.toUpperCase();

    if (normalized == 'ALTA') return Colors.red;
    if (normalized == 'MEDIA') return Colors.orange;

    return Colors.green;
  }

  IconData _priorityIcon(String prioridad) {
    final normalized = prioridad.toUpperCase();

    if (normalized == 'ALTA') return Icons.priority_high_rounded;
    if (normalized == 'MEDIA') return Icons.info_outline;

    return Icons.check_circle_outline;
  }

  IconData _estadoIcon(String estado) {
    final normalized = estado.toUpperCase();

    if (normalized == 'VENCIDA') return Icons.warning_amber_rounded;
    if (normalized == 'VENCE_HOY') return Icons.today_outlined;
    if (normalized == 'AL_DIA') return Icons.check_circle_outline;

    return Icons.help_outline;
  }
}
