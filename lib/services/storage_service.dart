import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fotolista_gpt/services/cache_service.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CacheManager _cache = AppCacheManager.instance;

  /// 🔹 Comprime la imagen antes de subirla
  Future<File> _compressImage(
    File file, {
    int maxWidth = 1024,
    int quality = 80,
  }) async {
    final targetPath =
        "${file.parent.path}/temp_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}";

    final xfile = await FlutterImageCompress.compressAndGetFile(
      file.path,
      targetPath,
      quality: quality,
      minWidth: maxWidth,
    );

    return xfile != null ? File(xfile.path) : file;
  }

  /// 🖼 Genera una miniatura a 300 px de ancho
  Future<File> _generateThumbnail(File originalFile, {int maxWidth = 300}) async {
    try {
      final bytes = await originalFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception("No se pudo decodificar la imagen");

      final thumbnail = img.copyResize(image, width: maxWidth);
      final thumbBytes = img.encodeJpg(thumbnail, quality: 80);

      final thumbPath = "${originalFile.path}_thumb.jpg";
      final thumbFile = File(thumbPath)..writeAsBytesSync(thumbBytes);

      return thumbFile;
    } catch (e) {
      print("⚠️ Error generando miniatura: $e");
      return originalFile;
    }
  }

  /// 📦 Subir imagen de ITEM y guardarla en caché
  Future<String> uploadImage(File file, String familyId) async {
    // 🔸 1. Comprimir imagen principal
    final compressed = await _compressImage(file, maxWidth: 1024, quality: 80);

    // 🔸 2. Crear miniatura
    final thumbFile = await _generateThumbnail(compressed);

    // 🔸 3. Nombres únicos
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = p.extension(file.path);
    final fileName = '$timestamp$ext';
    final thumbName = '${timestamp}_thumb$ext';

    // 🔸 4. Subir miniatura primero
    final thumbRef =
        _storage.ref().child('families/$familyId/items/$thumbName');
    await thumbRef.putFile(thumbFile);
    final thumbUrl = await thumbRef.getDownloadURL();

    // 🔸 5. Subir imagen completa (opcional)
    final ref = _storage.ref().child('families/$familyId/items/$fileName');
    await ref.putFile(compressed);
    final fullUrl = await ref.getDownloadURL();

    // 🔸 6. Guardar ambas en caché local
    final bytes = await compressed.readAsBytes();
    await _cache.putFile(
      fullUrl,
      bytes,
      maxAge: const Duration(days: 365),
      fileExtension: ext.replaceFirst('.', ''),
    );

    final thumbBytes = await thumbFile.readAsBytes();
    await _cache.putFile(
      thumbUrl,
      thumbBytes,
      maxAge: const Duration(days: 365),
      fileExtension: 'jpg',
    );

    // 🔸 7. Devolver URL de la miniatura (la que se muestra en listas)
    return thumbUrl;
  }

  /// 📦 Subir imagen de FAMILIA (con miniatura)
  Future<String> uploadFamilyImage(File file, String familyId) async {
    final compressed = await _compressImage(file, maxWidth: 800, quality: 80);
    final thumbFile = await _generateThumbnail(compressed);

    // 🔹 Subir miniatura
    final thumbRef = _storage.ref().child('families/$familyId/family_thumb.jpg');
    await thumbRef.putFile(thumbFile);
    final thumbUrl = await thumbRef.getDownloadURL();

    // 🔹 Subir imagen completa
    final ref = _storage.ref().child('families/$familyId/family_photo.jpg');
    await ref.putFile(compressed);
    final url = await ref.getDownloadURL();

    // 🔹 Cachear ambas
    final bytes = await compressed.readAsBytes();
    await _cache.putFile(url, bytes,
        maxAge: const Duration(days: 365),
        fileExtension: p.extension(compressed.path).replaceFirst('.', ''));

    final thumbBytes = await thumbFile.readAsBytes();
    await _cache.putFile(thumbUrl, thumbBytes,
        maxAge: const Duration(days: 365), fileExtension: 'jpg');

    return thumbUrl; // 👉 devuelve la miniatura
  }

  /// ❌ Borrar foto de familia
  Future<void> deleteFamilyImage(String familyId) async {
    final ref = _storage.ref().child('families/$familyId/family_photo.jpg');
    final thumbRef = _storage.ref().child('families/$familyId/family_thumb.jpg');
    try {
      final url = await ref.getDownloadURL();
      await ref.delete();
      await _cache.removeFile(url);
    } catch (_) {}
    try {
      final thumbUrl = await thumbRef.getDownloadURL();
      await thumbRef.delete();
      await _cache.removeFile(thumbUrl);
    } catch (_) {}
  }

  /// ❌ Borrar foto de ITEM
  Future<void> deleteItemImage(String familyId, String fileName) async {
    final ref = _storage.ref().child('families/$familyId/items/$fileName');
    final thumbRef = _storage.ref().child('families/$familyId/items/${fileName}_thumb');
    try {
      final url = await ref.getDownloadURL();
      await ref.delete();
      await _cache.removeFile(url);
    } catch (_) {}
    try {
      final thumbUrl = await thumbRef.getDownloadURL();
      await thumbRef.delete();
      await _cache.removeFile(thumbUrl);
    } catch (_) {}
  }
}
