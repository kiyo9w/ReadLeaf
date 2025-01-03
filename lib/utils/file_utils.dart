import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:migrated/models/file_info.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
// import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

class FileUtils {
  static Future<String?> picker() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final pickedFile = result.files.single;
        final filePath = pickedFile.path;

        if (filePath != null && File(filePath).existsSync()) {
          // Get the app's documents directory
          final appDir = await getApplicationDocumentsDirectory();
          final downloadsDir = Directory('${appDir.path}/Downloads');

          // Create Downloads directory if it doesn't exist
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }

          // Copy the file to app's Downloads directory
          final fileName = path.basename(filePath);
          final destinationPath = path.join(downloadsDir.path, fileName);

          // Copy the file
          await File(filePath).copy(destinationPath);

          return destinationPath;
          // Lmao I'm stupid af
          // await File(filePath).copy(destinationPath);

          // return destinationPath;
        }
      }
      return null;
    } catch (e) {
      print("Error during file picking: $e");
      return null;
    }
  }

  static Future<String> getDownloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/Downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir.path;
  }
}

class FileRepository {
  static const _filesKey = 'saved_files';
  late SharedPreferences _prefs;
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveFiles(List<FileInfo> files) async {
    final jsonData = files
        .map((f) => {
              'filePath': f.filePath,
              'fileSize': f.fileSize,
              'isSelected': f.isSelected,
              'isStarred': f.isStarred,
              'wasRead': f.wasRead,
            })
        .toList();
    await _prefs.setString(_filesKey, jsonEncode(jsonData));
  }

  Future<List<FileInfo>> loadFiles() async {
    final data = _prefs.getString(_filesKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((item) {
        return FileInfo(
          item['filePath'],
          item['fileSize'],
          isSelected: item['isSelected'] ?? false,
          isStarred: item['isStarred'] ?? false,
          wasRead: item['wasRead'] ?? false,
        );
      }).toList();
    } else {
      return [];
    }
  }
}
