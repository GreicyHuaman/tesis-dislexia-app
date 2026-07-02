import 'package:flutter/material.dart';

class StudentTestCompletedScreen extends StatelessWidget {
  final String testName;
  final String syncMessage;
  final bool syncSuccess;

  const StudentTestCompletedScreen({
    super.key,
    required this.testName,
    required this.syncMessage,
    required this.syncSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedTestName = testName.trim().toLowerCase();

    final title = normalizedTestName.contains('fono')
        ? 'Test de fonología completado'
        : 'Test de lectura completado';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Prueba completada'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 96,
                    color: syncSuccess ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tus respuestas fueron guardadas correctamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tu docente podrá revisar el avance desde su panel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            syncSuccess ? Icons.cloud_done : Icons.cloud_queue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              syncMessage,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final navigator = Navigator.of(context);

                        if (navigator.canPop()) {
                          navigator.pop();
                          return;
                        }

                        navigator.pushNamedAndRemoveUntil(
                          '/',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Volver a pruebas'),
                    ),
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
