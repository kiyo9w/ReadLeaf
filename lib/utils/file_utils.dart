import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:migrated/models/file_info.dart';
import 'package:migrated/depeninject/injection.dart';

class FileUtils {
  static Future<String?> picker() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath != null && File(filePath).existsSync()) {
          return filePath;
        }
      }
      return null;
    } catch (e) {
      print("Error during file picking: $e");
      return null;
    }
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
