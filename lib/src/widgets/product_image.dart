import 'dart:io';

import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.cover,
    this.placeholderSize = 54,
    this.cacheWidth,
  });

  final String? imagePath;
  final BoxFit fit;
  final double placeholderSize;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path == null || path.isEmpty) return _placeholder(context);
    return Image.file(
      File(path),
      fit: fit,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFF4F1),
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
