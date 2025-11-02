import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager {
  static final instance = CacheManager(
    Config(
      "fotolistaCache",
      stalePeriod: const Duration(days: 99999), // ← casi "permanente"
      maxNrOfCacheObjects: 1000, // o más si lo deseas
    ),
  );
}
