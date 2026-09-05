import 'package:flutter/material.dart';

/// Keeps the complete amount on one line inside the available space.
class PriceText extends StatelessWidget {
  const PriceText(this.text, {super.key, this.style, this.scaleDown = true});

  final String text;
  final TextStyle? style;
  final bool scaleDown;

  @override
  Widget build(BuildContext context) => scaleDown
      ? FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(text, maxLines: 1, softWrap: false, style: style),
        )
      : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Text(text, maxLines: 1, softWrap: false, style: style),
        );
}
