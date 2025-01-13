import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:migrated/models/file_info.dart';
import 'package:migrated/depeninject/injection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
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
          final linksDir = Directory('${appDir.path}/FileLinks');

          // Create links directory if it doesn't exist
          if (!await linksDir.exists()) {
            await linksDir.create(recursive: true);
          }

          // Create a symlink instead of copying
          final fileName = path.basename(filePath);
          final linkPath = path.join(linksDir.path, fileName);

          // Remove existing symlink if it exists
          final linkFile = Link(linkPath);
          if (await linkFile.exists()) {
            await linkFile.delete();
          }

          // Create new symlink
          await linkFile.create(filePath);
          return filePath; // Return original file path
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
    final linksDir = Directory('${appDir.path}/FileLinks');
    if (!await linksDir.exists()) {
      await linksDir.create(recursive: true);
    }
    return linksDir.path;
  }

  static Future<List<String>> copyDefaultPDFs() async {
    print('Starting to link default PDFs...');
    final appDir = await getApplicationDocumentsDirectory();
    final linksDir = Directory('${appDir.path}/FileLinks');

    print('Links directory path: ${linksDir.path}');

    if (!await linksDir.exists()) {
      await linksDir.create(recursive: true);
      print('Created links directory');
    }

    final defaultPDFs = [
      'atomic_habits.pdf',
      'business_law.pdf',
      'app_development_flutter.pdf',
      'gietconchimnhan.pdf',
    ];

    List<String> linkedPaths = [];

    for (String pdfName in defaultPDFs) {
      try {
        print('Processing default PDF: $pdfName');
        final assetPath = 'assets/pdfs/$pdfName';

        // For default PDFs, we still need to extract them from assets
        // but we'll store them in a different location
        final defaultPdfsDir = Directory('${appDir.path}/DefaultPDFs');
        if (!await defaultPdfsDir.exists()) {
          await defaultPdfsDir.create(recursive: true);
        }

        final defaultPdfPath = path.join(defaultPdfsDir.path, pdfName);
        final defaultPdfFile = File(defaultPdfPath);

        if (!await defaultPdfFile.exists()) {
          final ByteData data = await rootBundle.load(assetPath);
          final bytes = data.buffer.asUint8List();
          await defaultPdfFile.writeAsBytes(bytes);
          print('Extracted default PDF to: $defaultPdfPath');
        }

        // Create symlink to the extracted default PDF
        final linkPath = path.join(linksDir.path, pdfName);
        final linkFile = Link(linkPath);
        if (await linkFile.exists()) {
          await linkFile.delete();
        }
        await linkFile.create(defaultPdfPath);
        print('Created symlink at: $linkPath');

        linkedPaths.add(defaultPdfPath);
      } catch (e) {
        print('Error processing default PDF $pdfName: $e');
      }
    }

    print(
        'Finished linking PDFs. Successfully linked: ${linkedPaths.length} files');
    return linkedPaths;
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
    print(jsonData);
    await _prefs.setString(_filesKey, jsonEncode(jsonData));
  }

  Future<List<FileInfo>> loadFiles() async {
    final data = _prefs.getString(_filesKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      print(jsonList.map((item) {
        return FileInfo(
          item['filePath'],
          item['fileSize'],
          isSelected: item['isSelected'] ?? false,
          isStarred: item['isStarred'] ?? false,
          wasRead: item['wasRead'] ?? false,
        );
      }).toList());
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
