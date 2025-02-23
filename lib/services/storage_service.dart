import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:injectable/injectable.dart';

@lazySingleton
class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _bucketName = 'avatars';

  Future<String?> uploadProfilePicture(File file, String userId) async {
    try {
      // Validate file size (max 5MB)
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('File size must be less than 5MB');
      }

      final fileExt = path.extension(file.path);
      // Create path with userId as folder
      final filePath = '$userId/avatar$fileExt';

      // Delete existing avatar if any
      try {
        final List<FileObject> existingFiles =
            await _supabase.storage.from(_bucketName).list(path: userId);

        for (var file in existingFiles) {
          await _supabase.storage
              .from(_bucketName)
              .remove(['$userId/${file.name}']);
        }
      } catch (e) {
        // Ignore error if no existing file found
      }

      // Upload the new avatar
      await _supabase.storage
          .from(_bucketName)
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      // Get the public URL with cache busting
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imageUrl =
          '${_supabase.storage.from(_bucketName).getPublicUrl(filePath)}?v=$timestamp';

      return imageUrl;
    } on StorageException catch (e) {
      throw Exception('Storage error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  Future<bool> deleteProfilePicture(String userId) async {
    try {
      final List<FileObject> files =
          await _supabase.storage.from(_bucketName).list(path: userId);

      for (var file in files) {
        await _supabase.storage
            .from(_bucketName)
            .remove(['$userId/${file.name}']);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
