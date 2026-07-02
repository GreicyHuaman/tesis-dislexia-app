from pathlib import Path

path = Path(r"C:\Users\Greic\tesis-dislexia-app\mobile\lib\features\home\screens\student_test_completed_screen.dart")
text = path.read_text(encoding="utf-8")

old = """                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Volver a pruebas'),"""

new = """                      onPressed: () {
                        final navigator = Navigator.of(context);

                        if (navigator.canPop()) {
                          navigator.pop();
                          return;
                        }

                        navigator.pushNamedAndRemoveUntil('/', (route) => false);
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Volver a pruebas'),"""

if old not in text:
    old = """                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Volver al inicio'),"""

if old not in text:
    raise RuntimeError("No se encontró el botón de volver en student_test_completed_screen.dart")

text = text.replace(old, new)

path.write_text(text, encoding="utf-8")
print("Botón de retorno corregido.")
