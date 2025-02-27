import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ImageService {
  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();

  Future<File?> pickAndCropImage({
    ImageSource source = ImageSource.gallery,
    double? maxWidth,
    double? maxHeight,
    double? aspectRatio,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );

      if (image == null) return null;

      final CroppedFile? croppedFile = await _cropper.cropImage(
        sourcePath: image.path,
        aspectRatio: aspectRatio != null
            ? CropAspectRatio(ratioX: aspectRatio, ratioY: 1)
            : null,
        compressQuality: 70,
        maxWidth: (maxWidth ?? 1080).toInt(),
        maxHeight: (maxHeight ?? 1080).toInt(),
        compressFormat: ImageCompressFormat.jpg,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: const Color(0xFF6750A4),
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: aspectRatio != null,
            hideBottomControls: aspectRatio != null,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: aspectRatio != null,
            aspectRatioPickerButtonHidden: aspectRatio != null,
            resetAspectRatioEnabled: aspectRatio == null,
          ),
        ],
      );

      if (croppedFile == null) return null;

      return File(croppedFile.path);
    } catch (e) {
      debugPrint('Error picking/cropping image: $e');
      return null;
    }
  }
}
