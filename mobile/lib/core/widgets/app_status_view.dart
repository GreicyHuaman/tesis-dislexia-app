import 'package:flutter/material.dart';

class AppStatusView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool showProgress;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.showProgress = false,
    this.onRetry,
    this.retryLabel = 'Reintentar',
  });

  const AppStatusView.loading({
    super.key,
    this.title = 'Cargando información',
    this.message = 'Espera un momento mientras se consulta la información.',
    this.retryLabel = 'Reintentar',
  }) : icon = Icons.hourglass_empty,
       showProgress = true,
       onRetry = null;

  const AppStatusView.empty({
    super.key,
    this.title = 'Sin información',
    this.message = 'No se encontraron datos para mostrar.',
    this.retryLabel = 'Reintentar',
  }) : icon = Icons.inbox_outlined,
       showProgress = false,
       onRetry = null;

  const AppStatusView.error({
    super.key,
    this.title = 'No se pudo cargar',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Reintentar',
  }) : icon = Icons.error_outline,
       showProgress = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = showProgress
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgress)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 52, color: color),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
