import 'package:flutter/material.dart';

import '../../../core/models/stimulus.dart';
import '../../../core/repositories/stimuli_repository.dart';

class LecturaPreviewScreen extends StatefulWidget {
  const LecturaPreviewScreen({super.key});

  @override
  State<LecturaPreviewScreen> createState() => _LecturaPreviewScreenState();
}

class _LecturaPreviewScreenState extends State<LecturaPreviewScreen> {
  final StimuliRepository _repository = StimuliRepository();

  late final Future<List<Stimulus>> _stimuliFuture;

  @override
  void initState() {
    super.initState();
    _stimuliFuture = _repository.loadLecturaStimuli();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba lectora - Assets locales')),
      body: FutureBuilder<List<Stimulus>>(
        future: _stimuliFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error cargando estimulos:\n${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final stimuli = snapshot.data ?? [];

          if (stimuli.isEmpty) {
            return const Center(child: Text('No se encontraron estimulos.'));
          }

          return ListView.separated(
            itemCount: stimuli.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final stimulus = stimuli[index];

              return ListTile(
                title: Text(
                  stimulus.texto,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Silabas: ${stimulus.saNumSyll ?? "-"} | '
                  'Letras: ${stimulus.numLetters ?? "-"} | '
                  'Complejidad: ${stimulus.complejidadEstimulo}',
                ),
                trailing: Text('#${stimulus.orden}'),
              );
            },
          );
        },
      ),
    );
  }
}
