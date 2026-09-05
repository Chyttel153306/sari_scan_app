import 'dart:math' as math;

import 'package:flutter/material.dart';

TextStyle productPriceStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleLarge!.copyWith(
      fontFamily: 'SpaceGrotesk',
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w700,
    );

/// Both catalogs keep uniform cards; long amounts scroll within the price field.
SliverGridDelegate productGridDelegate(
  BuildContext context, {
  required double availableWidth,
}) {
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: math.max(1, ((availableWidth + 10) / 146).floor()),
    mainAxisExtent: 204 + MediaQuery.textScalerOf(context).scale(36),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
  );
}
