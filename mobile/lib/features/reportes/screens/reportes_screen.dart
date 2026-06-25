import 'package:flutter/material.dart';

import '../../../core/services/student_service.dart';
import 'package:flutter/services.dart';

import '../../../core/models/auth_user.dart';
import '../../../core/repositories/auth_session_storage.dart';
import '../../../core/models/report_models.dart';
import '../../../core/services/report_service.dart';
import '../../../core/services/pdf_report_builder.dart';
import '../../auth/screens/pin_login_screen.dart';
import '../../auth/widgets/offline_cache_setup_dialog.dart';
import '../../admin/screens/admin_panel_screen.dart';
import '../../../core/utils/csv_exporter.dart';
import '../../../core/utils/pdf_exporter.dart';
import 'student_risk_profile_screen.dart';

class ReportesScreen extends StatefulWidget {
  final AuthUser currentUser;

  const ReportesScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {

  Future<void> _prepareOfflineModeFromPortal() async {
    await showOfflineCacheSetupDialog(
      context: context,
      studentService: StudentService(),
    );
  }
  final ReportService _reportService = const ReportService();
  final PdfReportBuilder _pdfReportBuilder = const PdfReportBuilder();
  final TextEditingController _studentIdController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  String? _selectedTipoPrueba;
  String? _selectedSemaforo;

  ReportSummary? _summary;
  List<EvaluationReportItem> _evaluaciones = [];

  @override
  void initState() {
    super.initState();
    _loadReportes();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  ReportFilters get _currentFilters {
    final studentText = _studentIdController.text.trim();
    final studentId = int.tryParse(studentText);

    return ReportFilters(
      tipoPrueba: _selectedTipoPrueba,
      semaforo: _selectedSemaforo,
      estudianteId: studentId,
    );
  }

  Future<void> _loadReportes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final filters = _currentFilters;

      final summary = await _reportService.fetchResumenSemaforo(
        authToken: widget.currentUser.accessToken,
        filters: filters,
      );

      final evaluaciones = await _reportService.fetchEvaluaciones(
        authToken: widget.currentUser.accessToken,
        filters: filters,
      );

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _evaluaciones = evaluaciones;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      final errorText = error.toString();

      if (errorText.contains('401')) {
        await AuthSessionStorage.clearSession();
      }

      setState(() {
        _errorMessage = errorText.contains('401')
            ? 'Sesión vencida o no autorizada. Cierra sesión e ingresa nuevamente.'
            : errorText;
        _isLoading = false;
      });
    }
  }

  void _openStudentProfile(EvaluationReportItem evaluacion) {
    final estudianteId = evaluacion.estudianteId;

    if (estudianteId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta evaluación no tiene estudiante asociado.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentRiskProfileScreen(
          estudianteId: estudianteId,
          usuarioId: widget.currentUser.id,
          authToken: widget.currentUser.accessToken,
        ),
      ),
    );
  }

  void _openAdminPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminPanelScreen(
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _logoutStaff() async {
    await AuthSessionStorage.clearSession();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const PinLoginScreen(),
      ),
      (route) => false,
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedTipoPrueba = null;
      _selectedSemaforo = null;
      _studentIdController.clear();
    });

    _loadReportes();
  }

  Future<void> _exportPdf() async {
    if (_isLoading) return;

    if (_summary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero carga los reportes antes de exportar PDF.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await _pdfReportBuilder.buildEvaluationsReport(
        currentUser: widget.currentUser,
        summary: _summary,
        evaluations: _evaluaciones,
      );

      final savedPath = await savePdfFile(
        bytes: result.bytes,
        filename: result.filename,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generado: $savedPath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exportando PDF: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportCsv() async {
    try {
      final result = await _reportService.downloadEvaluacionesCsv(
        authToken: widget.currentUser.accessToken,
        filters: _currentFilters,
      );

      final savedPath = await saveCsvFile(
        bytes: result.bytes,
        filename: result.filename,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exportado: $savedPath'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo exportar CSV: $error'),
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final summary = _summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte docente'),
        actions: [
          IconButton(
            onPressed: _prepareOfflineModeFromPortal,
            icon: const Icon(Icons.offline_pin_outlined),
            tooltip: 'Preparar modo offline',
          ),

          IconButton(
            onPressed: _isLoading ? null : _loadReportes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: _isLoading ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
          ),
          if (widget.currentUser.rol.toUpperCase() == 'DIRECTORA')
            IconButton(
              onPressed: _openAdminPanel,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Panel administrativo',
            ),
          IconButton(
            onPressed: _logoutStaff,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(summary),
      ),
    );
  }

  Widget _buildBody(ReportSummary? summary) {
    if (_isLoading && summary == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null && summary == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 56,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadReportes,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (summary == null) {
      return const Center(
        child: Text('No hay datos de reporte.'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReportes,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UserScopeCard(user: widget.currentUser),
          const SizedBox(height: 14),
          _FilterCard(
            selectedTipoPrueba: _selectedTipoPrueba,
            selectedSemaforo: _selectedSemaforo,
            studentIdController: _studentIdController,
            isLoading: _isLoading,
            onTipoChanged: (value) {
              setState(() {
                _selectedTipoPrueba = value;
              });
            },
            onSemaforoChanged: (value) {
              setState(() {
                _selectedSemaforo = value;
              });
            },
            onApply: _loadReportes,
            onClear: _clearFilters,
            onExport: _exportCsv,
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const LinearProgressIndicator(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 14),
          _SummaryCard(summary: summary),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Historial de evaluaciones',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${_evaluaciones.length} resultado(s)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_evaluaciones.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'No hay evaluaciones visibles con los filtros seleccionados.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ..._evaluaciones.map(
              (evaluacion) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EvaluationCard(
                  evaluacion: evaluacion,
                  onOpenProfile: () => _openStudentProfile(evaluacion),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  final String? selectedTipoPrueba;
  final String? selectedSemaforo;
  final TextEditingController studentIdController;
  final bool isLoading;
  final ValueChanged<String?> onTipoChanged;
  final ValueChanged<String?> onSemaforoChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;
  final VoidCallback onExport;

  const _FilterCard({
    required this.selectedTipoPrueba,
    required this.selectedSemaforo,
    required this.studentIdController,
    required this.isLoading,
    required this.onTipoChanged,
    required this.onSemaforoChanged,
    required this.onApply,
    required this.onClear,
    required this.onExport,
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filtros',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedTipoPrueba,
              decoration: const InputDecoration(
                labelText: 'Tipo de prueba',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todas'),
                ),
                DropdownMenuItem<String>(
                  value: 'LECTURA',
                  child: Text('Lectura'),
                ),
                DropdownMenuItem<String>(
                  value: 'FONOLOGIA',
                  child: Text('Conciencia fonológica'),
                ),
              ],
              onChanged: isLoading ? null : onTipoChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedSemaforo,
              decoration: const InputDecoration(
                labelText: 'Semáforo',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos'),
                ),
                DropdownMenuItem<String>(
                  value: 'VERDE',
                  child: Text('Verde'),
                ),
                DropdownMenuItem<String>(
                  value: 'AMARILLO',
                  child: Text('Amarillo'),
                ),
                DropdownMenuItem<String>(
                  value: 'ROJO',
                  child: Text('Rojo'),
                ),
              ],
              onChanged: isLoading ? null : onSemaforoChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: studentIdController,
              enabled: !isLoading,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Estudiante ID opcional',
                border: OutlineInputBorder(),
                helperText: 'Déjalo vacío para ver todos los estudiantes permitidos.',
              ),
              onSubmitted: (_) => onApply(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onClear,
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                ),
                OutlinedButton.icon(
                  onPressed: isLoading ? null : onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Exportar CSV'),
                ),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : onApply,
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
}

class _UserScopeCard extends StatelessWidget {
  final AuthUser user;

  const _UserScopeCard({
    required this.user,
  });
  @override
  Widget build(BuildContext context) {
    final gradeText = user.gradoScope == null
        ? 'Sin restricción de grado'
        : 'Grado ${user.gradoScope}';

    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.person_outline),
        ),
        title: Text(
          user.nombreCompleto,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${user.rolTexto} | $gradeText\n${user.email}',
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ReportSummary summary;

  const _SummaryCard({
    required this.summary,
  });
  @override
  Widget build(BuildContext context) {
    final promedio = summary.porcentajePromedioRiesgo;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Resumen filtrado',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            _MetricRow(
              label: 'Total de evaluaciones',
              value: '${summary.totalEvaluaciones}',
            ),
            _MetricRow(
              label: 'Promedio de riesgo',
              value: promedio == null
                  ? 'Sin resultado'
                  : '${promedio.toStringAsFixed(2)}%',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SemaforoChip(
                  label: 'Verde',
                  total: summary.totalBySemaforo('VERDE'),
                  color: Colors.green,
                ),
                _SemaforoChip(
                  label: 'Amarillo',
                  total: summary.totalBySemaforo('AMARILLO'),
                  color: Colors.orange,
                ),
                _SemaforoChip(
                  label: 'Rojo',
                  total: summary.totalBySemaforo('ROJO'),
                  color: Colors.red,
                ),
                _SemaforoChip(
                  label: 'Sin resultado',
                  total: summary.totalBySemaforo('SIN_RESULTADO'),
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Los resultados son indicadores de riesgo para tamizaje educativo. No representan diagnóstico clínico.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  final EvaluationReportItem evaluacion;
  final VoidCallback? onOpenProfile;

  const _EvaluationCard({
    required this.evaluacion,
    this.onOpenProfile,
  });
  @override
  Widget build(BuildContext context) {
    final semaforo = evaluacion.semaforo?.toUpperCase() ?? 'SIN_RESULTADO';
    final color = _colorForSemaforo(semaforo);
    final riesgo = evaluacion.porcentajeRiesgo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          onTap: onOpenProfile,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(
              _iconForSemaforo(semaforo),
              color: color,
            ),
          ),
          title: Text(
            evaluacion.estudianteTexto,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Fecha: ${evaluacion.fechaTexto}\n'
              'Estudiante ID: ${evaluacion.estudianteId ?? 'N/D'} | '
              'Sección ID: ${evaluacion.seccionId ?? 'N/D'}\n'
              'Prueba: ${evaluacion.tipoPrueba ?? 'N/D'}\n'
              'Ítems: ${evaluacion.totalItems ?? 0} | '
              'Aciertos: ${evaluacion.aciertosPrimerIntento ?? 0} | '
              'Errores: ${evaluacion.tapsErroneosTotales ?? 0}\n'
              'Tiempo promedio: ${evaluacion.tiempoPromedioMs ?? 0} ms\n'
              '${evaluacion.fuenteTexto}\n'
              '${evaluacion.modeloTexto}\n'
              '${evaluacion.probabilidadesTexto}\n'
              'Toca para ver perfil comparativo del estudiante.',
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                riesgo == null ? 'N/D' : '${riesgo.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                semaforo,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForSemaforo(String semaforo) {
    if (semaforo == 'ROJO') return Colors.red;
    if (semaforo == 'AMARILLO') return Colors.orange;
    if (semaforo == 'VERDE') return Colors.green;

    return Colors.grey;
  }

  IconData _iconForSemaforo(String semaforo) {
    if (semaforo == 'ROJO') return Icons.warning_amber_rounded;
    if (semaforo == 'AMARILLO') return Icons.info_outline;
    if (semaforo == 'VERDE') return Icons.check_circle_outline;

    return Icons.help_outline;
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetricRow({
    required this.label,
    required this.value,
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
            style: const TextStyle(fontWeight: FontWeight.bold),
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















