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
    this.onArchive,
    this.onDelete,
  });
  final Product product;
  final bool inventory;
  final VoidCallback? onAdd;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final unavailable = product.isArchived || product.stock == 0;
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border),
      ),
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
                      color: AppTheme.canvas,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 30, 8, 6),
                        child: ProductImage(
                          imagePath: product.imagePath,
                          fit: BoxFit.contain,
                          placeholderSize: 34,
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
                            : AppTheme.emerald,
                        background: unavailable
                            ? colors.errorContainer
                            : product.isLowStock
                            ? const Color(0xFFFFFBEB)
                            : AppTheme.mint,
                      ),
                    ),
                  ),
                  if (inventory)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: const Color(0xFF047857),
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
                            if (value == 'archive') onArchive?.call();
                            if (value == 'delete') onDelete?.call();
                          },
                          itemBuilder: (_) => [
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
            color: unavailable ? AppTheme.muted : AppTheme.ink,
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
                  color: unavailable ? AppTheme.muted : const Color(0xFF047857),
                ),
              ),
            ),
            const SizedBox(width: 2),
            if (inventory)
              IconButton.filledTonal(
                tooltip: 'Edit product',
                onPressed: product.isArchived ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 19),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.mint,
                  foregroundColor: const Color(0xFF047857),
                  shape: const CircleBorder(),
                ),
              )
            else
              IconButton.filled(
                tooltip: 'Add to cart',
                onPressed: onAdd,
                icon: Icon(onAdd == null ? Icons.block : Icons.add, size: 23),
                style: IconButton.styleFrom(shape: const CircleBorder()),
              ),
          ],
        ),
      ],
    ),
  );
}
