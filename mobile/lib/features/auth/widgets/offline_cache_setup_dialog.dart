import 'package:flutter/material.dart';

import '../../../core/services/student_service.dart';

class OfflineCacheCredentials {
  final String email;
  final String password;

  const OfflineCacheCredentials({
    required this.email,
    required this.password,
  });
}

Future<void> showOfflineCacheSetupDialog({
  required BuildContext context,
  required StudentService studentService,
}) async {
  final credentials = await showDialog<OfflineCacheCredentials>(
    context: context,
    builder: (dialogContext) {
      final emailController = TextEditingController(
        text: 'maestra3a@demo.com',
      );
      final passwordController = TextEditingController(
        text: '123456',
      );

      return AlertDialog(
        title: const Text('Preparar modo offline'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa credenciales del personal académico para descargar el padrón autorizado en este dispositivo.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo académico',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop(
                OfflineCacheCredentials(
                  email: emailController.text.trim(),
                  password: passwordController.text,
                ),
              );
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar'),
          ),
        ],
      );
    },
  );

  if (credentials == null) {
    return;
  }

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Descargando padrón offline autorizado...'),
    ),
  );

  final result = await studentService.refreshOfflineCache(
    staffEmail: credentials.email,
    staffPassword: credentials.password,
  );

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.message),
      backgroundColor: result.success ? Colors.green : Colors.red,
    ),
  );
}
