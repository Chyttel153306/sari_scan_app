import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// A modal coach mark over the real app. The barrier prevents accidental sales.
class GuidedTutorial extends StatefulWidget {
  const GuidedTutorial({
    super.key,
    required this.targets,
    required this.onStepChanged,
  });

  final List<GlobalKey> targets;
  final ValueChanged<int> onStepChanged;

  @override
  State<GuidedTutorial> createState() => _GuidedTutorialState();
}

class _GuidedTutorialState extends State<GuidedTutorial> {
  int _step = 0;
  Rect? _target;
  bool _scheduled = false;
  final _cardScroll = ScrollController();

  @override
  void dispose() {
    _cardScroll.dispose();
    super.dispose();
  }

  static const _steps = [
    (
      'Your products live here',
      'Products',
      'Add the items you sell and keep an eye on prices and stock.',
      Icons.inventory_2_outlined,
    ),
    (
      'Start with your first item',
      '+ Add product',
      'This button opens a new product. Enter its name, selling price, and stock, then save. Photos and barcodes are optional.',
      Icons.add_circle_outline,
    ),
    (
      'Ready to sell?',
      'POS',
      'Tap a product to add it to the cart. Tap again for another piece, or search by name.',
      Icons.point_of_sale_outlined,
    ),
    (
      'Scan to find it faster',
      'Scan barcode',
      'Use this button to scan a saved product barcode. You can also enter the barcode manually.',
      Icons.qr_code_scanner_rounded,
    ),
    (
      'Check the cart, then charge',
      'POS checkout',
      'After adding items, View cart lets you adjust quantities. Tap Charge, choose Cash or Utang, then Complete sale. Cash payments show the change.',
      Icons.payments_outlined,
    ),
    (
      'Keep track of utang',
      'Utang',
      'See what each customer owes. When they repay, open their name, tap Pay Utang, and save the amount received.',
      Icons.menu_book_outlined,
    ),
    (
      'See how your store is doing',
      'Reports',
      'Review sales for today, the week, month, or year. Tap a past transaction to reopen its receipt.',
      Icons.bar_chart_outlined,
    ),
    (
      'Make it your store',
      'Store account',
      'Open Settings here to change your store name, appearance, markup, or sync. You can replay this tour anytime with the ? button.',
      Icons.settings_outlined,
    ),
  ];

  /// Measures the active widget target after layout to position the tutorial spotlight.
  void _measure() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final render = widget.targets[_step].currentContext?.findRenderObject();
      final overlay = context.findRenderObject();
      Rect? rect;
      if (render is RenderBox &&
          render.attached &&
          render.hasSize &&
          overlay is RenderBox) {
        rect =
            render.localToGlobal(Offset.zero, ancestor: overlay) & render.size;
      }
      if (_target != rect) setState(() => _target = rect);
    });
  }

  /// Changes the tour step and tells the parent which app tab to show.
  void _go(int step) {
    if (_cardScroll.hasClients) _cardScroll.jumpTo(0);
    widget.onStepChanged(step);
    setState(() {
      _step = step;
      _target = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final data = _steps[_step];
    final last = _step == _steps.length - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        _measure();
        final padding = MediaQuery.paddingOf(context);
        final hole = _target
            ?.inflate(6)
            .intersect(Offset.zero & constraints.biggest);
        final cardAbove =
            hole == null || hole.center.dy > constraints.maxHeight / 2;
        final top = padding.top + 16;
        final bottom = padding.bottom + 16;
        final available = cardAbove
            ? (hole?.top ?? constraints.maxHeight - bottom) - top - 20
            : constraints.maxHeight - bottom - hole.bottom - 20;
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _SpotlightPainter(hole)),
            ),
            Positioned(
              left: 16,
              right: 16,
              top: cardAbove ? top : null,
              bottom: cardAbove ? null : bottom,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: available.clamp(
                      120,
                      constraints.maxHeight - top - bottom,
                    ),
                  ),
                  child: Material(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    elevation: 16,
                    child: SingleChildScrollView(
                      controller: _cardScroll,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.topCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      context.tr(
                                        "QUICK TOUR  {0} / {1}",
                                        args: [_step + 1, _steps.length],
                                      ),
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: colors.primary,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1,
                                          ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(context.tr("Skip tutorial")),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  for (var i = 0; i < _steps.length; i++)
                                    Expanded(
                                      child: Container(
                                        height: 4,
                                        margin: const EdgeInsets.only(right: 4),
                                        decoration: BoxDecoration(
                                          color: i <= _step
                                              ? colors.primary
                                              : colors.outlineVariant,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  data.$4,
                                  color: colors.onPrimaryContainer,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Semantics(
                                header: true,
                                liveRegion: true,
                                child: Text(
                                  context.tr(data.$1),
                                  key: ValueKey(_step),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                context.tr(data.$3),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                context.tr(
                                  "Highlighted: {0}",
                                  args: [context.tr(data.$2)],
                                ),
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  if (_step > 0)
                                    OutlinedButton(
                                      onPressed: () => _go(_step - 1),
                                      child: Text(context.tr("Back")),
                                    ),
                                  FilledButton.icon(
                                    onPressed: last
                                        ? () => Navigator.pop(context)
                                        : () => _go(_step + 1),
                                    iconAlignment: IconAlignment.end,
                                    icon: Icon(
                                      last
                                          ? Icons.check_rounded
                                          : Icons.arrow_forward_rounded,
                                    ),
                                    label: Text(
                                      last
                                          ? context.tr("Start using SariScan")
                                          : context.tr("Next"),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.target);
  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    final rect = target;
    if (rect != null) {
      path.addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    }
    canvas.drawPath(path, Paint()..color = const Color(0xBD071A15));
    if (rect != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(16)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}
