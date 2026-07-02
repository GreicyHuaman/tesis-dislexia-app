import 'package:flutter/material.dart';

import '../services/auto_sync_service.dart';

class AutoSyncStatusBanner extends StatelessWidget {
  const AutoSyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AutoSyncSnapshot>(
      valueListenable: AutoSyncService.instance.status,
      builder: (context, snapshot, _) {
        final color = _colorForPhase(snapshot.phase);
        final icon = _iconForPhase(snapshot.phase);

        if (snapshot.pendingSessions <= 0) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 1,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.15),
              child: snapshot.isBusy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  : Icon(icon, color: color),
            ),
            title: Text(
              snapshot.message,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Text(
              'Pendientes: ${snapshot.pendingSessions} | Conexión: ${snapshot.connectionLabel}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              tooltip: 'Sincronizar ahora',
              onPressed: snapshot.isBusy
                  ? null
                  : () async {
                      await AutoSyncService.instance.syncNow();
                    },
              icon: const Icon(Icons.sync),
            ),
          ),
        );
      },
    );
  }

  Color _colorForPhase(AutoSyncPhase phase) {
    if (phase == AutoSyncPhase.synced) return Colors.green;
    if (phase == AutoSyncPhase.offline) return Colors.orange;
    if (phase == AutoSyncPhase.error) return Colors.red;
    if (phase == AutoSyncPhase.syncing) return Colors.indigo;

    return Colors.grey;
  }

  IconData _iconForPhase(AutoSyncPhase phase) {
    if (phase == AutoSyncPhase.synced) return Icons.cloud_done_outlined;
    if (phase == AutoSyncPhase.offline) return Icons.cloud_off_outlined;
    if (phase == AutoSyncPhase.error) return Icons.error_outline;
    if (phase == AutoSyncPhase.syncing) return Icons.cloud_sync_outlined;

    return Icons.sync;
  }
}
