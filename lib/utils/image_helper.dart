import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ImageHelper {
  // Private constructor to prevent instantiation
  ImageHelper._();

  /// Safely picks and crops an image, returning null if any step fails
  static Future<File?> pickAndCropImage({
    required bool square,
    ImageSource source = ImageSource.gallery,
    String? title,
  }) async {
    try {
      // First, pick the image
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);

      if (pickedFile == null) {
        return null;
      }

      // Then crop the image in a separate try block
      final File imageFile = File(pickedFile.path);
      return await cropImage(
        imageFile: imageFile,
        square: square,
        title: title,
      );
    } catch (e) {
      debugPrint('Error in pickAndCropImage: $e');
      return null;
    }
  }

  /// Only crops an existing image file, returning null if cropping fails
  static Future<File?> cropImage({
    required File imageFile,
    required bool square,
    String? title,
  }) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio:
            square ? const CropAspectRatio(ratioX: 1, ratioY: 1) : null,
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: title ?? 'Crop Image',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            initAspectRatio:
                square
                    ? CropAspectRatioPreset.square
                    : CropAspectRatioPreset.original,
            lockAspectRatio: square,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: title ?? 'Crop Image',
            aspectRatioLockEnabled: square,
            resetAspectRatioEnabled: !square,
            minimumAspectRatio: 1.0,
          ),
        ],
      );

      if (croppedFile == null) {
        return null;
      }

      return File(croppedFile.path);
    } catch (e) {
      debugPrint('Error in cropImage: $e');
      return null;
    }
  }
}
