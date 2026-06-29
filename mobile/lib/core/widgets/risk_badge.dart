import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final Object? value;
  final bool compact;

  const RiskBadge({super.key, required this.value, this.compact = false});

  String get _label {
    final text = value?.toString().trim().toUpperCase();

    if (text == null || text.isEmpty) {
      return 'SIN DATO';
    }

    return text;
  }

  Color _color(BuildContext context) {
    switch (_label) {
      case 'ROJO':
        return Colors.red;
      case 'AMARILLO':
        return Colors.orange;
      case 'VERDE':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData get _icon {
    switch (_label) {
      case 'ROJO':
        return Icons.warning_amber_rounded;
      case 'AMARILLO':
        return Icons.error_outline;
      case 'VERDE':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    final textStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: color,
      fontWeight: FontWeight.w800,
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: compact ? 15 : 17, color: color),
          const SizedBox(width: 6),
          Text(_label, style: textStyle),
        ],
      ),
    );
  }
}
