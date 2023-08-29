import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

String getBasename(String path) {
  return basename(path);
}

Future<File> genTemporaryFile(String proj) async {
  Directory dir;
  String ts = new DateTime.now().toIso8601String();

  try {
    dir = await getApplicationDocumentsDirectory();
  } catch (e) {
    return Future.error(e);
  }

  return File(join(dir.path, 'TagTags_${proj}_export_$ts.txt'));
}

File genExportFile(Directory dir, String proj) {
  String ts = new DateTime.now().toIso8601String();
  return File(join(dir.path, 'TagTags_${proj}_export_$ts.txt'));
}