enum PaymentType { cash, utang }

enum LedgerEntryType { credit, payment }

enum ReportPeriod { today, week, month, year }

class Product {
  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.costPrice,
    this.imagePath,
    this.barcode = '',
    this.lowStockThreshold = 5,
    this.isArchived = false,
  });

  final String id;
  String name;
  String category;
  double price;
  int stock;
  double? costPrice;
  String? imagePath;
  String barcode;
  int lowStockThreshold;
  bool isArchived;

  bool get isLowStock => stock <= lowStockThreshold;
}

class CartLine {
  const CartLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;
}

class SaleItem {
  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.unitCost,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double? unitCost;

  double get subtotal => quantity * unitPrice;
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.total,
    required this.paymentType,
    required this.amountReceived,
    required this.change,
    this.customerId,
  });

  final String id;
  final DateTime createdAt;
  final List<SaleItem> items;
  final double total;
  final PaymentType paymentType;
  final double amountReceived;
  final double change;
  final String? customerId;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.createdAt,
    required this.type,
    required this.amount,
    required this.note,
    this.saleId,
  });

  final String id;
  final DateTime createdAt;
  final LedgerEntryType type;
  final double amount;
  final String note;
  final String? saleId;
}

class Customer {
  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    List<LedgerEntry>? ledger,
  }) : ledger = ledger ?? [];

  final String id;
  String name;
  String phone;
  final List<LedgerEntry> ledger;

  double get balance => ledger.fold(
    0,
    (total, entry) =>
        total +
        (entry.type == LedgerEntryType.credit ? entry.amount : -entry.amount),
  );
}
