import 'dart:math';

const String kAdaptiveWordBankVersion = 'v1';

class AdaptiveSessionMetadata {
  final int nivelDificultadAplicado;
  final int totalBaja;
  final int totalMedia;
  final int totalAlta;
  final String versionBancoPalabras;

  const AdaptiveSessionMetadata({
    required this.nivelDificultadAplicado,
    required this.totalBaja,
    required this.totalMedia,
    required this.totalAlta,
    this.versionBancoPalabras = kAdaptiveWordBankVersion,
  });
}

class AdaptiveSelection<T> {
  final List<T> items;
  final AdaptiveSessionMetadata metadata;

  const AdaptiveSelection({required this.items, required this.metadata});
}

class AdaptiveWordBankSelector {
  static const int sessionSize = 10;
  static const int minLevel = 1;
  static const int maxLevel = 3;

  const AdaptiveWordBankSelector._();

  static AdaptiveSelection<T> select<T>({
    required List<T> items,
    required int level,
    required String Function(T item) difficultyOf,
    required Random random,
  }) {
    final appliedLevel = clampLevel(level);
    final distribution = _distributionForLevel(appliedLevel);
    final grouped = <String, List<T>>{
      'BAJA': <T>[],
      'MEDIA': <T>[],
      'ALTA': <T>[],
    };

    for (final item in items) {
      final normalized = normalizeDifficulty(difficultyOf(item));

      if (grouped.containsKey(normalized)) {
        grouped[normalized]!.add(item);
      }
    }

    final selected = <T>[];

    for (final entry in distribution.entries) {
      final source = List<T>.from(grouped[entry.key] ?? <T>[])
        ..shuffle(random);

      if (source.length < entry.value) {
        throw StateError(
          'Banco adaptativo insuficiente para nivel $appliedLevel: '
          'faltan ${entry.key}.',
        );
      }

      selected.addAll(source.take(entry.value));
    }

    selected.shuffle(random);

    return AdaptiveSelection<T>(
      items: selected,
      metadata: AdaptiveSessionMetadata(
        nivelDificultadAplicado: appliedLevel,
        totalBaja: distribution['BAJA'] ?? 0,
        totalMedia: distribution['MEDIA'] ?? 0,
        totalAlta: distribution['ALTA'] ?? 0,
      ),
    );
  }

  static int clampLevel(int level) {
    return max(minLevel, min(maxLevel, level));
  }

  static String normalizeDifficulty(String rawValue) {
    final normalized = rawValue.trim().toUpperCase();

    if (normalized == 'BAJA' || normalized == 'FACIL') {
      return 'BAJA';
    }

    if (normalized == 'MEDIA') {
      return 'MEDIA';
    }

    if (normalized == 'ALTA' || normalized == 'DIFICIL') {
      return 'ALTA';
    }

    return normalized;
  }

  static Map<String, int> _distributionForLevel(int level) {
    switch (clampLevel(level)) {
      case 1:
        return const {'BAJA': 10, 'MEDIA': 0, 'ALTA': 0};
      case 2:
        return const {'BAJA': 6, 'MEDIA': 4, 'ALTA': 0};
      case 3:
        return const {'BAJA': 4, 'MEDIA': 4, 'ALTA': 2};
      default:
        return const {'BAJA': 10, 'MEDIA': 0, 'ALTA': 0};
    }
  }
}
