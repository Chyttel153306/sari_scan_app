import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/sales_trend.dart';
import '../utils/formatters.dart';

class SalesTrendChart extends StatefulWidget {
  const SalesTrendChart({super.key, required this.points});

  final List<SalesTrendPoint> points;

  @override
  State<SalesTrendChart> createState() => _SalesTrendChartState();
}

class _SalesTrendChartState extends State<SalesTrendChart> {
  final _scrollController = ScrollController();
  int? _selected;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final maximum = points.fold<double>(
      0,
      (value, point) => math.max(value, point.value),
    );
    // Round the axis up to four equal, readable steps, always starting at zero.
    final rawStep = maximum <= 0 ? 1.0 : math.max(0.01, maximum / 4);
    final magnitude = math
        .pow(10, (math.log(rawStep) / math.ln10).floor())
        .toDouble();
    final step = (rawStep / magnitude).ceil() * magnitude;
    final axisMax = step * 4;
    final colors = Theme.of(context).colorScheme;
    final selected = _selected == null ? null : points[_selected!];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sales (PHP) • Cash + Utang'),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            double textWidth(String text) {
              final painter = TextPainter(
                text: TextSpan(
                  text: text,
                  style: DefaultTextStyle.of(
                    context,
                  ).style.merge(const TextStyle(fontSize: 11)),
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              )..layout();
              final width = painter.width;
              painter.dispose();
              return width;
            }

            final axisWidth =
                List.generate(
                  5,
                  (index) => compactAmount(axisMax - index * step),
                ).fold<double>(
                  58,
                  (width, label) => math.max(width, textWidth(label) + 12),
                );
            final bucketWidth = points
                .expand(
                  (point) => [
                    ...point.label.replaceAll('–', '–\n').split('\n'),
                    compactAmount(point.value),
                  ],
                )
                .fold<double>(
                  42,
                  (width, label) => math.max(width, textWidth(label) + 12),
                );
            const plotHeight = 160.0;
            final topPadding = MediaQuery.textScalerOf(context).scale(18) + 8;
            final chartHeight =
                topPadding +
                plotHeight +
                MediaQuery.textScalerOf(context).scale(36) +
                20;
            final width = math.max(
              constraints.maxWidth - axisWidth,
              points.length * bucketWidth,
            );
            return SizedBox(
              height: chartHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: axisWidth,
                    height: topPadding + plotHeight + 10,
                    child: Stack(
                      children: List.generate(
                        5,
                        (index) => Positioned(
                          top: topPadding + index * plotHeight / 4 - 8,
                          left: 0,
                          right: 8,
                          child: Text(
                            compactAmount(axisMax - index * step),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: width,
                          height: chartHeight - 12,
                          child: Stack(
                            children: [
                              ...List.generate(
                                5,
                                (index) => Positioned(
                                  top: topPadding + index * plotHeight / 4,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 1,
                                    color: colors.outlineVariant,
                                  ),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(points.length, (index) {
                                  final point = points[index];
                                  final height =
                                      plotHeight * point.value / axisMax;
                                  return Expanded(
                                    child: Semantics(
                                      label:
                                          '${point.label.replaceAll('\n', ' ')}: ${money(point.value)}',
                                      button: true,
                                      selected: _selected == index,
                                      child: InkWell(
                                        onTap: () =>
                                            setState(() => _selected = index),
                                        child: Tooltip(
                                          message: money(point.value),
                                          child: Column(
                                            children: [
                                              SizedBox(
                                                height: topPadding + plotHeight,
                                                child: Stack(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  children: [
                                                    Positioned(
                                                      bottom: height + 4,
                                                      child: Text(
                                                        compactAmount(
                                                          point.value,
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      key: ValueKey(
                                                        'sales-bar-$index',
                                                      ),
                                                      width: 28,
                                                      height: height,
                                                      decoration: BoxDecoration(
                                                        gradient:
                                                            point.value > 0 &&
                                                                (_selected ==
                                                                        index ||
                                                                    point.value ==
                                                                        maximum)
                                                            ? const LinearGradient(
                                                                begin: Alignment
                                                                    .bottomCenter,
                                                                end: Alignment
                                                                    .topCenter,
                                                                colors: [
                                                                  Color(
                                                                    0xFF059669,
                                                                  ),
                                                                  Color(
                                                                    0xFF34D399,
                                                                  ),
                                                                ],
                                                              )
                                                            : null,
                                                        color:
                                                            point.value > 0 &&
                                                                (_selected ==
                                                                        index ||
                                                                    point.value ==
                                                                        maximum)
                                                            ? null
                                                            : const Color(
                                                                0xFFCBD5E1,
                                                              ),
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    5,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                point.label.replaceAll(
                                                  '–',
                                                  '–\n',
                                                ),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Text(
          selected == null
              ? 'Swipe to see all periods. Tap a bar for the exact amount.'
              : '${selected.label.replaceAll('\n', ' ')}: ${money(selected.value)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

String compactAmount(double value) {
  if (value.abs() >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(1)}B';
  }
  if (value.abs() >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
}
