import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/phonology_stimulus.dart';

class PhonologyRepository {
  Future<List<PhonologyStimulus>> loadPhonologyStimuli() async {
    final rawJson = await rootBundle.loadString(
      'assets/stimuli/fonologia_stimuli.json',
    );

    final decoded = jsonDecode(rawJson);

    if (decoded is! List) {
      throw Exception(
        'El archivo fonologia_stimuli.json no contiene una lista.',
      );
    }

    final stimuli = <PhonologyStimulus>[];

    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }

      final stimulus = PhonologyStimulus.fromJson(
        Map<String, dynamic>.from(item),
      );

      if (stimulus.id.isEmpty ||
          stimulus.palabra.isEmpty ||
          stimulus.silabaObjetivo.isEmpty ||
          stimulus.opciones.length < 3) {
        continue;
      }

      stimuli.add(stimulus);
    }

    return stimuli;
  }
}
