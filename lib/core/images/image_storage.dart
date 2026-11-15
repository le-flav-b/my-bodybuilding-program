import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:my_bodybuilding_program/core/utils/ids.dart';
import 'package:my_bodybuilding_program/features/catalogue/domain/catalogue.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'image_storage.g.dart';

/// The user's own exercise photos, kept in private app storage (never in
/// the phone gallery). Synced to the cloud from v1.1.
class ImageStorage {
  new(this.directory, {this._newId = newId});

  /// Opens the storage folder inside the app's private documents.
  static Future<ImageStorage> open() async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, folderName));
    await directory.create(recursive: true);
    return ImageStorage(directory);
  }

  static const String folderName = 'images';

  final Directory directory;
  final IdGenerator _newId;

  /// The file of a stored photo.
  File fileOf(UserImage image) => File(p.join(directory.path, image.file));

  /// Copies the picked file at [sourcePath] into the storage.
  Future<UserImage> import(String sourcePath) async {
    final extension = p.extension(sourcePath).toLowerCase();
    final name = '${_newId()}${extension.isEmpty ? '.jpg' : extension}';
    await directory.create(recursive: true);
    await File(sourcePath).copy(p.join(directory.path, name));
    return UserImage(name);
  }

  /// Removes a photo that is no longer referenced.
  Future<void> delete(UserImage image) async {
    final file = fileOf(image);
    if (file.existsSync()) await file.delete();
  }
}

/// Takes or picks a photo, compressed to at most 1080 px.
class PhotoPicker {
  new([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  static const double maxSize = 1080;
  static const int jpegQuality = 85;

  final ImagePicker _picker;

  /// The path of the picked photo, or null when the user cancelled.
  Future<String?> pick({required bool fromCamera}) async {
    final file = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxSize,
      maxHeight: maxSize,
      imageQuality: jpegQuality,
    );
    return file?.path;
  }
}

/// Opened during the app bootstrap; tests override it with a temp folder.
@Riverpod(keepAlive: true)
Future<ImageStorage> imageStorage(Ref ref) => ImageStorage.open();

@Riverpod(keepAlive: true)
PhotoPicker photoPicker(Ref ref) => PhotoPicker();
