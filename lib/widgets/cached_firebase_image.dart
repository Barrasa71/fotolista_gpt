import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fotolista_gpt/services/cache_service.dart';

class CachedFirebaseImage extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool isCircle;

  const CachedFirebaseImage({
    super.key,
    required this.imageUrl,
    this.radius = 28,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.isCircle = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: AppCacheManager.instance.getSingleFile(imageUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _placeholder();
        } else if (snapshot.hasError || snapshot.data == null) {
          return _error();
        } else {
          final image = FileImage(snapshot.data!);
          if (isCircle) {
            return CircleAvatar(
              radius: radius,
              backgroundImage: image,
            );
          } else {
            return Image.file(
              snapshot.data!,
              fit: fit,
              width: width,
              height: height,
            );
          }
        }
      },
    );
  }

  Widget _placeholder() {
    return isCircle
        ? CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.photo, color: Colors.white),
          )
        : Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.photo, color: Colors.white),
          );
  }

  Widget _error() {
    return isCircle
        ? CircleAvatar(
            radius: radius,
            backgroundColor: Colors.red[100],
            child: const Icon(Icons.broken_image, color: Colors.red),
          )
        : Container(
            width: width,
            height: height,
            color: Colors.red[100],
            child: const Icon(Icons.broken_image, color: Colors.red),
          );
  }
}
