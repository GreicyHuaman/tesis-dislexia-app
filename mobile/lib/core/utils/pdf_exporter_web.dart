// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<String> savePdfFile({
  required List<int> bytes,
  required String filename,
}) async {
  final blob = html.Blob(
    [bytes],
    'application/pdf',
  );

  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();

  html.Url.revokeObjectUrl(url);

  return filename;
}
