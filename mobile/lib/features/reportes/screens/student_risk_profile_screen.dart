import 'package:flutter/material.dart';

import '../../../core/services/report_service.dart';
import '../../../core/services/connection_errors.dart';
import '../../../core/services/student_pdf_report_builder.dart';
import '../../../core/utils/pdf_exporter.dart';
import '../../../core/widgets/app_status_view.dart';
import '../../../core/widgets/risk_badge.dart';

class StudentRiskProfileScreen extends StatefulWidget {
  final int estudianteId;
  final int? usuarioId;
  final String? authToken;

  const StudentRiskProfileScreen({
    super.key,
    required this.estudianteId,
    this.usuarioId,
    this.authToken,
  });

  @override
  State<StudentRiskProfileScreen> createState() =>
      _StudentRiskProfileScreenState();
}

class _StudentRiskProfileScreenState extends State<StudentRiskProfileScreen> {
  final ReportService _reportService = const ReportService();
  final StudentPdfReportBuilder _pdfReportBuilder =
      const StudentPdfReportBuilder();

  bool _isLoading = true;
  String? _errorMessage;
  dynamic _profile;

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
    } catch (error, stackTrace) {
      logRequestFailure('Cargar perfil', error, stackTrace);
      if (!mounted) return;

      setState(() {
        _errorMessage = requestErrorMessage(
          error,
          fallbackMessage: 'No se pudo cargar el perfil. Vuelva a intentarlo.',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_isLoading) return;

    if (_profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero carga el perfil antes de exportar PDF.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await _pdfReportBuilder.buildStudentRiskReport(
        profile: _profile,
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

  Object? _readValue(dynamic source, String key) {
    if (source == null) return null;

    if (source is Map) {
      return source[key];
    }

    try {
      switch (key) {
        case 'estudianteId':
          return source.estudianteId;
        case 'estudiante_id':
          return source.estudiante_id;
        case 'estudianteNombre':
          return source.estudianteNombre;
        case 'estudiante_nombre':
          return source.estudiante_nombre;
        case 'seccionId':
          return source.seccionId;
        case 'seccion_id':
          return source.seccion_id;
        case 'totalEvaluaciones':
          return source.totalEvaluaciones;
        case 'total_evaluaciones':
          return source.total_evaluaciones;
        case 'porcentajePromedioGeneral':
          return source.porcentajePromedioGeneral;
        case 'porcentaje_promedio_general':
          return source.porcentaje_promedio_general;
        case 'ultimoPorcentajeRiesgoGeneral':
          return source.ultimoPorcentajeRiesgoGeneral;
        case 'ultimo_porcentaje_riesgo_general':
          return source.ultimo_porcentaje_riesgo_general;
        case 'ultimoSemaforoGeneral':
          return source.ultimoSemaforoGeneral;
        case 'ultimo_semaforo_general':
          return source.ultimo_semaforo_general;
        case 'ultimaFechaGeneral':
          return source.ultimaFechaGeneral;
        case 'ultima_fecha_general':
          return source.ultima_fecha_general;
        case 'pruebas':
          return source.pruebas;
        case 'tipoPrueba':
          return source.tipoPrueba;
        case 'tipo_prueba':
          return source.tipo_prueba;
        case 'totalEvaluacionesPrueba':
          return source.totalEvaluaciones;
        case 'porcentajePromedioRiesgo':
          return source.porcentajePromedioRiesgo;
        case 'porcentaje_promedio_riesgo':
          return source.porcentaje_promedio_riesgo;
        case 'ultimoPorcentajeRiesgo':
          return source.ultimoPorcentajeRiesgo;
        case 'ultimo_porcentaje_riesgo':
          return source.ultimo_porcentaje_riesgo;
        case 'ultimoSemaforo':
          return source.ultimoSemaforo;
        case 'ultimo_semaforo':
          return source.ultimo_semaforo;
        case 'ultimaFecha':
          return source.ultimaFecha;
        case 'ultima_fecha':
          return source.ultima_fecha;
        case 'promedioTiempoMs':
          return source.promedioTiempoMs;
        case 'promedio_tiempo_ms':
          return source.promedio_tiempo_ms;
        case 'promedioErrores':
          return source.promedioErrores;
        case 'promedio_errores':
          return source.promedio_errores;
        case 'totalVerde':
          return source.totalVerde;
        case 'total_verde':
          return source.total_verde;
        case 'totalAmarillo':
          return source.totalAmarillo;
        case 'total_amarillo':
          return source.total_amarillo;
        case 'totalRojo':
          return source.totalRojo;
        case 'total_rojo':
          return source.total_rojo;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  List<dynamic> _readList(Object? value) {
    if (value is List) {
      return value;
    }

    return [];
  }

  String _formatPercent(Object? value) {
    if (value == null) return '-';

    final parsed = double.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    return '${parsed.toStringAsFixed(2)}%';
  }

  String _formatNumber(Object? value) {
    if (value == null) return '-';

    final parsed = double.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    return parsed.toStringAsFixed(2);
  }

  String _formatDate(Object? value) {
    if (value == null) return '-';

    final parsed = value is DateTime
        ? value
        : DateTime.tryParse(value.toString());

    if (parsed == null) {
      return value.toString();
    }

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(parsed.day)}/${twoDigits(parsed.month)}/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = _profile == null
        ? 'Perfil de riesgo'
        : (_readValue(_profile, 'estudianteNombre') ??
                  _readValue(_profile, 'estudiante_nombre') ??
                  'Perfil de riesgo')
              .toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: _isLoading ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF individual',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppStatusView.loading(
        title: 'Cargando perfil',
        message: 'Consultando información del estudiante...',
      );
    }

    if (_errorMessage != null) {
      return AppStatusView.error(
        message: _errorMessage!,
        onRetry: _loadProfile,
      );
    }

    if (_profile == null) {
      return const AppStatusView.empty(
        title: 'Perfil no encontrado',
        message: 'No se encontró información de riesgo para este estudiante.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGeneralCard(),
          const SizedBox(height: 14),
          _buildDisclaimerCard(),
          const SizedBox(height: 14),
          _buildTestsSection(),
        ],
      ),
    );
  }

  Widget _buildGeneralCard() {
    final estudianteNombre =
        _readValue(_profile, 'estudianteNombre') ??
        _readValue(_profile, 'estudiante_nombre') ??
        'Estudiante';

    final estudianteId =
        _readValue(_profile, 'estudianteId') ??
        _readValue(_profile, 'estudiante_id') ??
        widget.estudianteId;

    final seccionId =
        _readValue(_profile, 'seccionId') ??
        _readValue(_profile, 'seccion_id') ??
        '-';

    final totalEvaluaciones =
        _readValue(_profile, 'totalEvaluaciones') ??
        _readValue(_profile, 'total_evaluaciones') ??
        '0';

    final promedioGeneral =
        _readValue(_profile, 'porcentajePromedioGeneral') ??
        _readValue(_profile, 'porcentaje_promedio_general') ??
        '-';

    final ultimoRiesgo =
        _readValue(_profile, 'ultimoPorcentajeRiesgoGeneral') ??
        _readValue(_profile, 'ultimo_porcentaje_riesgo_general') ??
        '-';

    final ultimoSemaforo =
        _readValue(_profile, 'ultimoSemaforoGeneral') ??
        _readValue(_profile, 'ultimo_semaforo_general') ??
        '-';

    final ultimaFecha =
        _readValue(_profile, 'ultimaFechaGeneral') ??
        _readValue(_profile, 'ultima_fecha_general');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estudianteNombre.toString(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text('ID estudiante: $estudianteId'),
            Text('Sección: $seccionId'),
            const Divider(height: 24),
            _InfoRow(
              label: 'Total de evaluaciones',
              value: totalEvaluaciones.toString(),
            ),
            _InfoRow(
              label: 'Promedio general de riesgo',
              value: _formatPercent(promedioGeneral),
            ),
            _InfoRow(
              label: 'Último riesgo registrado',
              value: _formatPercent(ultimoRiesgo),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Último semáforo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                RiskBadge(value: ultimoSemaforo),
              ],
            ),
            _InfoRow(label: 'Última fecha', value: _formatDate(ultimaFecha)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Card(
      color: Colors.amber.withValues(alpha: 0.12),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'Nota: Este resultado corresponde a un tamizaje educativo temprano. '
          'No constituye diagnóstico clínico de dislexia.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTestsSection() {
    final pruebas = _readList(_readValue(_profile, 'pruebas'));

    if (pruebas.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'No existen evaluaciones por tipo de prueba para este estudiante.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparativo por tipo de prueba',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        ...pruebas.map(_buildTestCard),
      ],
    );
  }

  Widget _buildTestCard(dynamic item) {
    final tipoPrueba =
        _readValue(item, 'tipoPrueba') ??
        _readValue(item, 'tipo_prueba') ??
        '-';

    final totalEvaluaciones =
        _readValue(item, 'totalEvaluaciones') ??
        _readValue(item, 'total_evaluaciones') ??
        '0';

    final promedioRiesgo =
        _readValue(item, 'porcentajePromedioRiesgo') ??
        _readValue(item, 'porcentaje_promedio_riesgo') ??
        '-';

    final ultimoRiesgo =
        _readValue(item, 'ultimoPorcentajeRiesgo') ??
        _readValue(item, 'ultimo_porcentaje_riesgo') ??
        '-';

    final ultimoSemaforo =
        _readValue(item, 'ultimoSemaforo') ??
        _readValue(item, 'ultimo_semaforo') ??
        '-';

    final ultimaFecha =
        _readValue(item, 'ultimaFecha') ?? _readValue(item, 'ultima_fecha');

    final promedioTiempo =
        _readValue(item, 'promedioTiempoMs') ??
        _readValue(item, 'promedio_tiempo_ms') ??
        '-';

    final promedioErrores =
        _readValue(item, 'promedioErrores') ??
        _readValue(item, 'promedio_errores') ??
        '-';

    final totalVerde =
        _readValue(item, 'totalVerde') ??
        _readValue(item, 'total_verde') ??
        '0';

    final totalAmarillo =
        _readValue(item, 'totalAmarillo') ??
        _readValue(item, 'total_amarillo') ??
        '0';

    final totalRojo =
        _readValue(item, 'totalRojo') ?? _readValue(item, 'total_rojo') ?? '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tipoPrueba.toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Evaluaciones',
              value: totalEvaluaciones.toString(),
            ),
            _InfoRow(
              label: 'Promedio de riesgo',
              value: _formatPercent(promedioRiesgo),
            ),
            _InfoRow(
              label: 'Último riesgo',
              value: _formatPercent(ultimoRiesgo),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Último semáforo',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                RiskBadge(value: ultimoSemaforo),
              ],
            ),
            _InfoRow(label: 'Última fecha', value: _formatDate(ultimaFecha)),
            _InfoRow(
              label: 'Promedio tiempo',
              value: '${_formatNumber(promedioTiempo)} ms',
            ),
            _InfoRow(
              label: 'Promedio errores',
              value: _formatNumber(promedioErrores),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text('Verde: $totalVerde')),
                Chip(label: Text('Amarillo: $totalAmarillo')),
                Chip(label: Text('Rojo: $totalRojo')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
