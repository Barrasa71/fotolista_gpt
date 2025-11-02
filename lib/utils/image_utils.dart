import 'dart:io';
import 'package:image/image.dart' as img;

class ImageUtils {
  /// 📏 Crea una miniatura reducida (por ejemplo 300 px de ancho)
  static Future<File> generateThumbnail(File originalFile, {int maxWidth = 300}) async {
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
}
