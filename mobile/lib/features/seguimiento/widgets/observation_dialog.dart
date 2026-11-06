import 'package:flutter/material.dart';

import '../../../core/models/seguimiento_models.dart';
import '../../../core/services/connection_errors.dart';
import '../../../core/services/seguimiento_service.dart';

class ObservationDialog extends StatefulWidget {
  final SeguimientoItem item;
  final String? authToken;

  const ObservationDialog({
    super.key,
    required this.item,
    required this.authToken,
  });

  @override
  State<ObservationDialog> createState() => _ObservationDialogState();
}

class _ObservationDialogState extends State<ObservationDialog> {
  static const _states = {
    'ABIERTO': 'Abierto',
    'REFORZAMIENTO': 'Reforzamiento',
    'DERIVACION_SUGERIDA': 'Derivación sugerida',
    'CERRADO': 'Cerrado',
  };
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  late final Set<String> _selectedCategories;
  late final bool _hasLegacyCategories;
  String? _selectedEstado;
  String? _categoryError;
  String? _saveError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.item.observacionDocente ?? '',
    );
    _selectedCategories = widget.item.categorias
        .where(seguimientoObservationCategories.contains)
        .toSet();
    _hasLegacyCategories = widget.item.categorias.any(
      (category) => !seguimientoObservationCategories.contains(category),
    );
    final estado = widget.item.estado ?? 'ABIERTO';
    _selectedEstado = _states.containsKey(estado) ? estado : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _observationRequired =>
      (widget.item.semaforo ?? '').toUpperCase() == 'ROJO' ||
      widget.item.estadoSemanal.toUpperCase() == 'VENCIDA' ||
      {
        'DERIVACION_SUGERIDA',
        'CERRADO',
        'CAMBIO_MANUAL',
      }.contains(_selectedEstado);

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _saveError = null;
      _categoryError = _selectedCategories.isEmpty
          ? 'Selecciona al menos una categoría válida.'
          : null;
    });
    final validForm = _formKey.currentState!.validate();
    final estado = _selectedEstado;
    if (!validForm || _categoryError != null || estado == null) return;

    setState(() {
      _isSaving = true;
    });
    try {
      await const SeguimientoService().createObservacion(
        authToken: widget.authToken,
        estudianteId: widget.item.estudianteId,
        evaluacionId: widget.item.evaluacionId,
        observacionDocente: _controller.text.trim(),
        categorias: seguimientoObservationCategories
            .where(_selectedCategories.contains)
            .toList(),
        estado: estado,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error, stackTrace) {
      logRequestFailure('Guardar observación', error, stackTrace);
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = requestErrorMessage(
          error,
          fallbackMessage:
              'No se pudo guardar la observación. Vuelva a intentarlo.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isSaving,
    child: AlertDialog(
      title: const Text('Registrar observación'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.item.estudianteNombre,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Prioridad: ${widget.item.prioridad}\n'
                  'Estado semanal: ${widget.item.estadoSemanalTexto}\n'
                  'Semáforo: ${widget.item.semaforo ?? 'N/D'}\n'
                  'Tendencia: ${widget.item.tendenciaTexto}',
                  style: const TextStyle(height: 1.35),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEstado,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Estado del seguimiento',
                    border: OutlineInputBorder(),
                  ),
                  items: _states.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (value) => value == null
                      ? 'Selecciona un estado del seguimiento.'
                      : null,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _selectedEstado = value;
                          });
                        },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _controller,
                  enabled: !_isSaving,
                  minLines: 3,
                  maxLines: 5,
                  validator: (value) =>
                      _observationRequired && (value ?? '').trim().isEmpty
                      ? 'La observación es obligatoria para este caso.'
                      : null,
                  decoration: InputDecoration(
                    labelText: _observationRequired
                        ? 'Observación docente obligatoria'
                        : 'Observación docente opcional',
                    border: const OutlineInputBorder(),
                    helperMaxLines: 3,
                    errorMaxLines: 3,
                    helperText: _observationRequired
                        ? 'Requerida por riesgo alto, evaluación vencida o cambio de estado.'
                        : 'Recomendada para casos amarillos o seguimiento pedagógico.',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Categorías de seguimiento',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Text('Selecciona al menos una categoría.'),
                if (_hasLegacyCategories) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'La observación anterior tiene categorías fuera del catálogo actual. Elige una categoría vigente; el historial se conserva.',
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: seguimientoObservationCategories
                      .map(
                        (category) => FilterChip(
                          label: Text(category),
                          selected: _selectedCategories.contains(category),
                          onSelected: _isSaving
                              ? null
                              : (checked) {
                                  setState(() {
                                    if (checked) {
                                      _selectedCategories.add(category);
                                      _categoryError = null;
                                    } else {
                                      _selectedCategories.remove(category);
                                    }
                                  });
                                },
                        ),
                      )
                      .toList(),
                ),
                if (_categoryError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _categoryError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_saveError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
        ),
      ],
    ),
  );
}
