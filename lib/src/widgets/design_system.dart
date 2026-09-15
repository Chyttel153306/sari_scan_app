import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'price_text.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: AppTheme.brandGradient,
      borderRadius: BorderRadius.circular(size * .3),
      boxShadow: [
        BoxShadow(
          color: AppTheme.emeraldDeep.withValues(alpha: .35),
          blurRadius: 18,
          offset: const Offset(0, 7),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: .6),
          blurRadius: 10,
          offset: const Offset(-3, -3),
        ),
      ],
    ),
    child: Icon(
      Icons.storefront_outlined,
      color: Colors.white,
      size: size * .55,
    ),
  );
}

/// A soft rounded pill, gently lifted off the page with a matching-tint
/// shadow instead of a hard outline.
class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.color = AppTheme.emerald,
    this.background = AppTheme.mint,
    this.icon,
  });
  final String text;
  final Color color;
  final Color background;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(99),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: .18),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

/// The headline metric card. Kept as a deep, glassy accent block (its own
/// dark-green gradient) rather than the pale neumorphic base, but its
/// shadow is now a soft double-cast — a warm dark shadow below and a faint
/// highlight above — so it still reads as "raised" off the lighter page.
class MetricHero extends StatelessWidget {
  const MetricHero({
    super.key,
    required this.label,
    required this.amount,
    required this.footer,
    this.icon = Icons.account_balance_wallet_outlined,
  });
  final String label;
  final String amount;
  final Widget footer;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.emeraldDeep, Color(0xFF215C40), AppTheme.ink],
      ),
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: AppTheme.baseDark,
          blurRadius: 20,
          offset: const Offset(6, 8),
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: .7),
          blurRadius: 16,
          offset: const Offset(-5, -5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF8FE3B9), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFC3F0D8),
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PriceText(
          amount,
          style: const TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
        const Divider(color: Color(0x26FFFFFF), height: 30),
        DefaultTextStyle(
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 11,
            color: Color(0xFFDCF5E6),
          ),
          child: footer,
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inventory_2_outlined,
  });
  final String title;
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 38),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A gently sunken circular badge — a diagonal gradient stands in
        // for an inner shadow, giving the icon a "pressed into the page"
        // feel that pairs with the raised cards around it.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppTheme.insetGradient,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.emeraldDeep, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}