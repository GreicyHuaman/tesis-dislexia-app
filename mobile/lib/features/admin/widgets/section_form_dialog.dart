import 'package:flutter/material.dart';

import '../../../core/models/admin_models.dart';

typedef SectionFormData = ({String nombre, String turno, bool activo});

class SectionFormDialog extends StatefulWidget {
  final AdminSection? section;

  const SectionFormDialog({super.key, this.section});

  @override
  State<SectionFormDialog> createState() => _SectionFormDialogState();
}

class _SectionFormDialogState extends State<SectionFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreController;
  String? _turno;
  late bool _activo;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(
      text: widget.section?.nombre ?? '',
    );
    _activo = widget.section?.activo ?? true;

    final storedTurno = widget.section?.turno?.trim().toUpperCase();
    if (storedTurno == 'MANANA' || storedTurno == 'MAÑANA') {
      _turno = 'MAÑANA';
    } else if (storedTurno == 'TARDE') {
      _turno = 'TARDE';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.section == null ? 'Nueva sección' : 'Editar sección'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: '3.º de primaria',
                readOnly: true,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Grado',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de sección',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa el nombre de la sección.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _turno,
                decoration: const InputDecoration(
                  labelText: 'Turno',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Selecciona un turno'),
                items: const [
                  DropdownMenuItem(value: 'MAÑANA', child: Text('Mañana')),
                  DropdownMenuItem(value: 'TARDE', child: Text('Tarde')),
                ],
                onChanged: (value) {
                  setState(() {
                    _turno = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecciona un turno.';
                  }
                  return null;
                },
              ),
              if (widget.section != null && _turno == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'El turno registrado está vacío o no es válido. '
                    'Selecciona Mañana o Tarde para guardar.',
                  ),
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _activo,
                title: const Text('Activa'),
                onChanged: (value) {
                  setState(() {
                    _activo = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop<SectionFormData>((
              nombre: _nombreController.text.trim(),
              turno: _turno!,
              activo: _activo,
            ));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
