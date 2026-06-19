import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<String> savePdfFile({
  required List<int> bytes,
  required String filename,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final reportsDirectory = Directory(
    '${directory.path}${Platform.pathSeparator}reportes',
  );

  if (!reportsDirectory.existsSync()) {
    reportsDirectory.createSync(recursive: true);
  }

  final file = File(
    '${reportsDirectory.path}${Platform.pathSeparator}$filename',
  );

  await file.writeAsBytes(bytes, flush: true);

  await OpenFilex.open(file.path);

  return file.path;
}
