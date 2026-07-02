from pathlib import Path

ROOT = Path(r"C:\Users\Greic\tesis-dislexia-app")

completed_screen = ROOT / "mobile/lib/features/home/screens/student_test_completed_screen.dart"
completed_screen.parent.mkdir(parents=True, exist_ok=True)

completed_screen.write_text("""import 'package:flutter/material.dart';

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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Volver al inicio'),
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
""", encoding="utf-8")


def replace_block(text: str, signature: str, replacement: str) -> str:
    start = text.find(signature)
    if start == -1:
        raise RuntimeError(f"No se encontró: {signature}")

    brace_start = text.find("{", start)
    if brace_start == -1:
        raise RuntimeError(f"No se encontró llave inicial: {signature}")

    depth = 0
    end = None

    for index in range(brace_start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                end = index + 1
                break

    if end is None:
        raise RuntimeError(f"No se encontró llave final: {signature}")

    return text[:start] + replacement + text[end:]


def remove_block_if_exists(text: str, signature: str) -> str:
    start = text.find(signature)
    if start == -1:
        return text

    brace_start = text.find("{", start)
    if brace_start == -1:
        return text

    depth = 0
    end = None

    for index in range(brace_start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                end = index + 1
                break

    if end is None:
        return text

    return text[:start].rstrip() + "\n\n" + text[end:].lstrip()


targets = [
    (
        ROOT / "mobile/lib/features/lectura/screens/lectura_assessment_screen.dart",
        "lectura",
    ),
    (
        ROOT / "mobile/lib/features/fonologia/screens/fonologia_assessment_screen.dart",
        "fonología",
    ),
]

import_line = "import '../../home/screens/student_test_completed_screen.dart';"

for path, test_name in targets:
    text = path.read_text(encoding="utf-8")

    if import_line not in text:
        text = import_line + "\n" + text

    text = text.replace("Sincronizando con el backend...", "Sincronizando con el servidor...")

    summary_method = f"""  Widget _buildSummaryScreen() {{
    final normalizedSyncMessage = (_syncMessage ?? '').toLowerCase();

    final syncSuccess = (!_isSyncing && _pendingLocalSessions == 0) ||
        normalizedSyncMessage.contains('exitosa') ||
        normalizedSyncMessage.contains('completada') ||
        normalizedSyncMessage.contains('no hay evaluaciones');

    final message = _isSyncing
        ? 'Sincronizando con el servidor...'
        : syncSuccess
            ? 'Sincronización completada.'
            : 'Se sincronizará automáticamente cuando haya conexión.';

    return StudentTestCompletedScreen(
      testName: '{test_name}',
      syncSuccess: syncSuccess,
      syncMessage: message,
    );
  }}"""

    text = replace_block(
        text,
        "  Widget _buildSummaryScreen() {",
        summary_method,
    )

    text = text.replace("  String? _lastSemaforo;\n", "")
    text = text.replace("  double? _lastPorcentajeRiesgo;\n", "")

    text = text.replace("        _lastPorcentajeRiesgo = null;\n", "")
    text = text.replace("        _lastSemaforo = null;\n", "")

    text = text.replace(
"""      if (result.success && result.porcentajeRiesgo != null) {
        _lastPorcentajeRiesgo = result.porcentajeRiesgo;
        _lastSemaforo = result.semaforo;
      }

""",
        "",
    )

    text = remove_block_if_exists(text, "  Future<void> _restartSession() async")
    text = remove_block_if_exists(text, "class _SummaryTile")
    text = remove_block_if_exists(text, "class _RiskResultCard")

    path.write_text(text, encoding="utf-8")
    print(path.relative_to(ROOT))

print(completed_screen.relative_to(ROOT))
