import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PdfStorage {
  static Future<String> appDocumentsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static Future<String> saveCopyToLibrary(
    String sourcePath,
    String fileName,
  ) async {
    final docs = await appDocumentsDir();
    final targetDir = Directory('$docs/pdfs');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final targetPath = '${targetDir.path}/$fileName';
    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.copy(targetPath);
    }
    return targetPath;
  }
}