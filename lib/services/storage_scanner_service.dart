import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:external_path/external_path.dart';
import 'package:path/path.dart' as path;
import 'package:read_leaf/models/file_info.dart';

class StorageScannerService {
  static const List<String> supportedFormats = ['pdf', 'epub', 'mobi'];
  static const List<String> excludedDirs = [
    'Android',
    'Windows',
    '.gradle',
    'cache',
    'Cache',
    'tmp',
    'temp'
  ];

  Future<List<FileInfo>> scanStorage() async {
    List<FileInfo> discoveredFiles = [];

    try {
      if (!await _checkAndRequestPermissions()) {
        throw Exception('Storage permission denied');
      }

      // Get all storage paths
      List<String> storagePaths = await _getStoragePaths();

      for (String storagePath in storagePaths) {
        await _scanDirectory(Directory(storagePath), discoveredFiles);
      }
    } catch (e) {
      print('Error scanning storage: $e');
    }

    return discoveredFiles;
  }

  Future<void> _scanDirectory(
      Directory directory, List<FileInfo> results) async {
    try {
      List<FileSystemEntity> entities = await directory.list().toList();

      for (FileSystemEntity entity in entities) {
        if (entity is File) {
          String extension =
              path.extension(entity.path).toLowerCase().replaceAll('.', '');
          if (supportedFormats.contains(extension)) {
            int fileSize = await entity.length();
            results.add(FileInfo(entity.path, fileSize));
          }
        } else if (entity is Directory) {
          String dirName = path.basename(entity.path);
          if (!excludedDirs.contains(dirName) && !dirName.startsWith('.')) {
            await _scanDirectory(entity, results);
          }
        }
      }
    } catch (e) {
      print('Error scanning directory ${directory.path}: $e');
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt <= 32) {
        final status = await Permission.storage.request();
        return status.isGranted;
      } else {
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        return photos.isGranted && videos.isGranted;
      }
    }
    return true; // iOS has different permission model
  }

  Future<List<String>> _getStoragePaths() async {
    List<String> paths = [];

    if (Platform.isAndroid) {
      try {
        String documentsPath =
            await ExternalPath.getExternalStoragePublicDirectory(
                ExternalPath.DIRECTORY_DOCUMENTS);
        paths.add(documentsPath);

        String? downloadsPath =
            await ExternalPath.getExternalStoragePublicDirectory(
                ExternalPath.DIRECTORY_DOWNLOADS);
        paths.add(downloadsPath);
            } catch (e) {
        print('Error getting storage paths: $e');
      }
    } else {
      final directory = await getApplicationDocumentsDirectory();
      paths.add(directory.path);
    }

    return paths.toSet().toList();
  }
}
