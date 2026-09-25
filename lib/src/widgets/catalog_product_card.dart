import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'design_system.dart';
import 'price_text.dart';
import 'product_grid.dart';
import 'product_image.dart';

class CatalogProductCard extends StatelessWidget {
  const CatalogProductCard({
    super.key,
    required this.product,
    this.inventory = false,
    this.onAdd,
    this.onEdit,
    this.onAddStock,
    this.onArchive,
    this.onDelete,
  });
  final Product product;
  final bool inventory;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onAddStock;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final unavailable = product.isArchived || product.stock == 0;
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: inventory ? (product.isArchived ? null : onEdit) : onAdd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 132,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppTheme.of(context).canvas,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 30, 8, 6),
                        child: LayoutBuilder(
                          builder: (context, constraints) => ProductImage(
                            imagePath: product.imagePath,
                            fit: BoxFit.contain,
                            placeholderSize: 34,
                            cacheWidth:
                                (constraints.maxWidth *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .ceil(),
                            cacheHeight:
                                (constraints.maxHeight *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .ceil(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: inventory ? 60 : 8,
                    top: 10,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: StatusPill(
                        product.isArchived
                            ? 'Archived'
                            : product.stock == 0
                            ? 'Out of stock'
                            : product.isLowStock
                            ? 'LOW: ${product.stock}'
                            : 'IN STOCK: ${product.stock}',
                        color: unavailable
                            ? colors.error
                            : product.isLowStock
                            ? colors.tertiary
                            : AppTheme.of(context).emerald,
                        background: unavailable
                            ? colors.errorContainer
                            : product.isLowStock
                            ? AppTheme.of(context).warnBg
                            : AppTheme.of(context).mint,
                      ),
                    ),
                  ),
                  if (inventory)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: AppTheme.of(context).emeraldDeep,
                        elevation: 3,
                        shadowColor: AppTheme.of(context).baseDark,
                        shape: const CircleBorder(),
                        child: PopupMenuButton<String>(
                          tooltip: 'Product options',
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            size: 32,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') onEdit?.call();
                            if (value == 'addStock') onAddStock?.call();
                            if (value == 'archive') onArchive?.call();
                            if (value == 'delete') onDelete?.call();
                          },
                          itemBuilder: (_) => [
                            if (!product.isArchived)
                              const PopupMenuItem(
                                value: 'addStock',
                                child: Text('Add stock'),
                              ),
                            if (!product.isArchived)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit product'),
                              ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text(
                                product.isArchived
                                    ? 'Restore product'
                                    : 'Archive product',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete product'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Small photo-sync status badge — inventory view only,
                  // since it's a management/debug affordance rather than
                  // something a cashier needs to see at checkout.
                  if (inventory && product.imagePath != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Tooltip(
                        message: product.imageUrl != null
                            ? 'Photo will sync to other phones'
                            : 'Photo is local to this phone only',
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.of(
                              context,
                            ).baseSunken.withValues(alpha: .92),
                            shape: BoxShape.circle,
                            boxShadow: AppTheme.of(context).softShadows(),
                          ),
                          child: Icon(
                            product.imageUrl != null
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                            size: 14,
                            color: product.imageUrl != null
                                ? AppTheme.of(context).emerald
                                : AppTheme.of(context).muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _details(context, unavailable)),
          ],
        ),
      ),
    );
  }

  Widget _details(BuildContext context, bool unavailable) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          product.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: unavailable
                ? AppTheme.of(context).muted
                : AppTheme.of(context).ink,
            decoration: product.isArchived ? TextDecoration.lineThrough : null,
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: PriceText(
                money(product.price).replaceFirst(RegExp(r'\.00$'), ''),
                scaleDown: false,
                style: productPriceStyle(context).copyWith(
                  color: unavailable
                      ? AppTheme.of(context).muted
                      : AppTheme.of(context).emeraldDeep,
                ),
              ),
            ),
            if (inventory) const SizedBox(width: 2),
            if (inventory)
              IconButton.filledTonal(
                tooltip: 'Add stock',
                onPressed: product.isArchived ? null : onAddStock,
                icon: const Icon(Icons.add_box_outlined, size: 19),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.of(context).mint,
                  foregroundColor: AppTheme.of(context).emeraldDeep,
                  shape: const CircleBorder(),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}
