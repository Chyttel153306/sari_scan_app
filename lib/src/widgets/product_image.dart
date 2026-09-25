import 'dart:io';

import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.placeholderSize = 54,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String? imagePath;
  final BoxFit fit;
  final double placeholderSize;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path == null || path.isEmpty) return _placeholder(context);
    final provider = FileImage(File(path));
    return Image(
      image: cacheWidth == null && cacheHeight == null
          ? provider
          : ResizeImage(
              provider,
              width: cacheWidth,
              height: cacheHeight,
              policy: ResizeImagePolicy.fit,
            ),
      fit: fit,
      errorBuilder: (_, _, _) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: placeholderSize,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}
