import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/stimulus.dart';

class StimuliRepository {
  Future<List<Stimulus>> loadLecturaStimuli() async {
    final jsonString = await rootBundle.loadString(
      'assets/stimuli/lectura_stimuli.json',
    );

    final Map<String, dynamic> decoded = json.decode(jsonString);
    final List<dynamic> rawStimuli = decoded['stimuli'] as List<dynamic>;

    return rawStimuli
        .map((item) => Stimulus.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
