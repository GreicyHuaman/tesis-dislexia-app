import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/repositories/auth_session_storage.dart';
import 'core/repositories/local_evaluation_storage.dart';
import 'core/repositories/local_student_cache.dart';
import 'core/services/auto_sync_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/pin_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await LocalEvaluationStorage.init();
  await LocalStudentCache.init();
  await AuthSessionStorage.init();

  await AutoSyncService.instance.start();

  runApp(const DyslexiaScreeningApp());
}

class DyslexiaScreeningApp extends StatelessWidget {
  const DyslexiaScreeningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tamizaje de riesgo de dislexia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const PinLoginScreen(),
    );
  }
}
