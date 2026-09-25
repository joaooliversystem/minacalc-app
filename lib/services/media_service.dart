import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class MediaService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  Future<String?> capturePhoto() async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 100);
    if (image == null) return null;
    return _persistOptimized(image.path);
  }

  Future<List<String>> selectPhotos({int remaining = 8}) async {
    final images = await _picker.pickMultiImage(limit: remaining, imageQuality: 100);
    final out = <String>[];
    for (final image in images.take(remaining)) {
      out.add(await _persistOptimized(image.path));
    }
    return out;
  }

  Future<String> saveSignature(Uint8List bytes) async {
    final dir = await _mediaDir();
    final file = File(p.join(dir.path, 'signature_${_uuid.v4()}.png'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> _persistOptimized(String sourcePath) async {
    final dir = await _mediaDir();
    final target = p.join(dir.path, 'photo_${_uuid.v4()}.jpg');
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      target,
      quality: 78,
      minWidth: 1600,
      minHeight: 1200,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (result == null) {
      await File(sourcePath).copy(target);
    }
    return target;
  }

  Future<Directory> _mediaDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'minacalc_media'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
