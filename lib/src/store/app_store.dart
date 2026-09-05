import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/sales_trend.dart';
import '../services/local_storage_service.dart';

class AppStore extends ChangeNotifier {
  AppStore({List<Product>? products, List<Customer>? customers, this.storage})
    : products = products ?? [],
      customers = customers ?? [];

  factory AppStore.forApp({LocalStorageService? storage}) {
    return AppStore(storage: storage);
  }

  static const _dataVersion = 2;

  final List<Product> products;
  final List<Customer> customers;
  final List<SaleRecord> sales = [];
  final Map<String, int> _cart = {};
  final LocalStorageService? storage;
  Future<void> _persistenceQueue = Future.value();

  String? currentUserName;
  String? storageError;
  bool isLoading = false;
  Map<String, dynamic>? _account;

  bool get isAuthenticated => currentUserName != null;
  bool get hasLocalAccount => _account != null;
  bool get isLocalStorageEnabled => storage != null;
  Future<void> get persistenceSettled => _persistenceQueue;

  List<Product> get activeProducts =>
      products.where((product) => !product.isArchived).toList();

  List<CartLine> get cartLines => _cart.entries
      .map(
        (entry) => CartLine(
          product: products.firstWhere((product) => product.id == entry.key),
          quantity: entry.value,
        ),
      )
      .toList();

  int get cartItemCount =>
      _cart.values.fold(0, (total, quantity) => total + quantity);

  double get cartTotal =>
      cartLines.fold(0, (total, line) => total + line.subtotal);

  double get totalOutstanding =>
      customers.fold(0, (total, customer) => total + customer.balance);

  Future<void> initialize() async {
    if (storage == null) return;
    isLoading = true;
    notifyListeners();
    try {
      final snapshot = await storage!.loadSnapshot();
      if (snapshot != null) {
        final migrated = _restoreSnapshot(snapshot);
        if (migrated) await storage!.saveSnapshot(_snapshot());
      }
      storageError = null;
    } catch (error) {
      storageError = 'Local data could not be loaded: $error';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String? validateOwnerName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) return 'Enter your name.';
    final account = _account;
    if (account != null &&
        '${account['name']}'.trim().toLowerCase() != normalized.toLowerCase()) {
      return 'That name does not match the owner registered on this phone.';
    }
    return null;
  }

  Future<String?> openSecureSession(String name) async {
    final validation = validateOwnerName(name);
    if (validation != null) return validation;
    final normalized = name.trim();
    _account ??= {'name': normalized};
    currentUserName = '${_account!['name']}';
    notifyListeners();
    return _saveNow();
  }

  Future<void> logout() async {
    currentUserName = null;
    _cart.clear();
    notifyListeners();
  }

  void addToCart(Product product) {
    if (product.isArchived || !products.contains(product)) return;
    final current = _cart[product.id] ?? 0;
    if (current >= product.stock) return;
    _cart[product.id] = current + 1;
    notifyListeners();
  }

  void removeOneFromCart(Product product) {
    final current = _cart[product.id] ?? 0;
    if (current <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = current - 1;
    }
    notifyListeners();
  }

  void removeFromCart(Product product) {
    _cart.remove(product.id);
    notifyListeners();
  }

  Product? findByBarcode(String barcode) {
    final normalized = barcode.trim();
    for (final product in activeProducts) {
      if (product.barcode == normalized) return product;
    }
    return null;
  }

  Product saveProduct({
    Product? existing,
    required String name,
    required String category,
    required double price,
    required int stock,
    double? costPrice,
    String? imagePath,
    required String barcode,
    required int lowStockThreshold,
  }) {
    late final Product savedProduct;
    if (existing == null) {
      savedProduct = Product(
        id: _nextId(products.map((product) => product.id)),
        name: name.trim(),
        category: category.trim(),
        price: price,
        stock: stock,
        costPrice: costPrice,
        imagePath: imagePath,
        barcode: barcode.trim(),
        lowStockThreshold: lowStockThreshold,
      );
      products.add(savedProduct);
    } else {
      existing
        ..name = name.trim()
        ..category = category.trim()
        ..price = price
        ..stock = stock
        ..costPrice = costPrice
        ..imagePath = imagePath
        ..barcode = barcode.trim()
        ..lowStockThreshold = lowStockThreshold;
      savedProduct = existing;
    }
    notifyListeners();
    _queueSave();
    return savedProduct;
  }

  void toggleArchive(Product product) {
    product.isArchived = !product.isArchived;
    _cart.remove(product.id);
    notifyListeners();
    _queueSave();
  }

  void deleteProduct(Product product) {
    _cart.remove(product.id);
    products.removeWhere((item) => item.id == product.id);
    // Sales and credit ledgers keep their own saved product details.
    notifyListeners();
    _queueSave();
  }

  Customer addCustomer(String name, String phone) {
    final customer = Customer(
      id: _nextId(customers.map((customer) => customer.id)),
      name: name.trim(),
      phone: phone.trim(),
    );
    customers.add(customer);
    notifyListeners();
    _queueSave();
    return customer;
  }

  Future<String?> importProductImage(
    String? sourcePath, {
    String? previousPath,
  }) async {
    if (sourcePath == null || sourcePath.isEmpty) {
      await storage?.deleteProductImage(previousPath);
      return null;
    }
    if (sourcePath == previousPath || storage == null) return sourcePath;
    final imported = await storage!.importProductImage(sourcePath);
    await storage!.deleteProductImage(previousPath);
    return imported;
  }

  String? recordPayment(Customer customer, double amount) {
    if (amount <= 0) return 'Enter a payment greater than zero.';
    if (amount > customer.balance) {
      return 'Payment cannot be greater than the outstanding balance.';
    }
    customer.ledger.insert(
      0,
      LedgerEntry(
        id: _nextId(customer.ledger.map((entry) => entry.id)),
        createdAt: DateTime.now(),
        type: LedgerEntryType.payment,
        amount: amount,
        note: 'Customer payment',
      ),
    );
    notifyListeners();
    _queueSave();
    return null;
  }

  SaleRecord completeSale({
    required PaymentType paymentType,
    double amountReceived = 0,
    Customer? customer,
  }) {
    if (_cart.isEmpty) throw StateError('The cart is empty.');
    if (paymentType == PaymentType.cash && amountReceived < cartTotal) {
      throw StateError('The cash amount is insufficient.');
    }
    if (paymentType == PaymentType.utang && customer == null) {
      throw StateError('Select a customer for an utang sale.');
    }

    final total = cartTotal;
    final now = DateTime.now();
    final sale = SaleRecord(
      id: _nextId(sales.map((sale) => sale.id)),
      createdAt: now,
      items: cartLines
          .map(
            (line) => SaleItem(
              productId: line.product.id,
              productName: line.product.name,
              quantity: line.quantity,
              unitPrice: line.product.price,
              unitCost: line.product.costPrice,
            ),
          )
          .toList(),
      total: total,
      paymentType: paymentType,
      amountReceived: paymentType == PaymentType.cash ? amountReceived : 0,
      change: paymentType == PaymentType.cash ? amountReceived - total : 0,
      customerId: customer?.id,
    );

    for (final line in cartLines) {
      line.product.stock -= line.quantity;
    }
    sales.insert(0, sale);

    if (customer != null) {
      customer.ledger.insert(
        0,
        LedgerEntry(
          id: _nextId(customer.ledger.map((entry) => entry.id)),
          createdAt: now,
          type: LedgerEntryType.credit,
          amount: total,
          note: 'Utang sale ${sale.id}',
          saleId: sale.id,
        ),
      );
    }

    _cart.clear();
    notifyListeners();
    _queueSave();
    return sale;
  }

  List<SaleRecord> salesFor(ReportPeriod period, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final start = reportStart(period, reference);
    return sales
        .where(
          (sale) =>
              !sale.createdAt.isBefore(start) &&
              !sale.createdAt.isAfter(reference),
        )
        .toList();
  }

  bool _restoreSnapshot(Map<String, dynamic> snapshot) {
    final version = (snapshot['version'] as num?)?.toInt() ?? 0;
    if (version < 1 || version > _dataVersion) {
      throw FormatException('Unsupported local data version: $version');
    }

    final account = snapshot['account'];
    if (account is Map && '${account['name']}'.trim().isNotEmpty) {
      _account = {'name': '${account['name']}'.trim()};
    } else {
      _account = null;
    }

    products
      ..clear()
      ..addAll(_mapRows(snapshot['products']).map(_productFromRow));
    customers
      ..clear()
      ..addAll(_mapRows(snapshot['customers']).map(_customerFromRow));
    sales
      ..clear()
      ..addAll(_mapRows(snapshot['sales']).map(_saleFromRow));

    // Authentication is intentionally session-only. Every fresh app launch
    // must pass the phone's system security prompt again.
    currentUserName = null;
    return version < _dataVersion;
  }

  List<Map<String, dynamic>> _mapRows(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Map<String, dynamic> _snapshot() => {
    'version': _dataVersion,
    'account': _account,
    'products': products.map(_productToRow).toList(),
    'customers': customers.map(_customerToRow).toList(),
    'sales': sales.map(_saleToRow).toList(),
  };

  Product _productFromRow(Map<String, dynamic> row) {
    return Product(
      id: '${row['id']}',
      name: '${row['name']}',
      category: '${row['category']}',
      price: (row['price'] as num).toDouble(),
      stock: (row['stock'] as num).toInt(),
      costPrice: (row['cost_price'] as num?)?.toDouble(),
      imagePath: row['image_path']?.toString(),
      barcode: row['barcode']?.toString() ?? '',
      lowStockThreshold: (row['low_stock_threshold'] as num?)?.toInt() ?? 5,
      isArchived: row['is_archived'] == true,
    );
  }

  Customer _customerFromRow(Map<String, dynamic> row) {
    return Customer(
      id: '${row['id']}',
      name: '${row['name']}',
      phone: row['phone']?.toString() ?? '',
      ledger: _mapRows(row['ledger']).map(_ledgerFromRow).toList(),
    );
  }

  SaleRecord _saleFromRow(Map<String, dynamic> row) {
    return SaleRecord(
      id: '${row['id']}',
      createdAt: DateTime.parse('${row['created_at']}'),
      items: _mapRows(row['items']).map(_saleItemFromRow).toList(),
      total: (row['total'] as num).toDouble(),
      paymentType: row['payment_type'] == 'utang'
          ? PaymentType.utang
          : PaymentType.cash,
      amountReceived: (row['amount_received'] as num).toDouble(),
      change: (row['change_amount'] as num).toDouble(),
      customerId: row['customer_id']?.toString(),
    );
  }

  SaleItem _saleItemFromRow(Map<String, dynamic> row) {
    return SaleItem(
      productId: '${row['product_id']}',
      productName: '${row['product_name']}',
      quantity: (row['quantity'] as num).toInt(),
      unitPrice: (row['unit_price'] as num).toDouble(),
      unitCost: (row['unit_cost'] as num?)?.toDouble(),
    );
  }

  LedgerEntry _ledgerFromRow(Map<String, dynamic> row) {
    return LedgerEntry(
      id: '${row['id']}',
      createdAt: DateTime.parse('${row['created_at']}'),
      type: row['entry_type'] == 'payment'
          ? LedgerEntryType.payment
          : LedgerEntryType.credit,
      amount: (row['amount'] as num).toDouble(),
      note: '${row['note']}',
      saleId: row['sale_id']?.toString(),
    );
  }

  Map<String, dynamic> _productToRow(Product product) => {
    'id': product.id,
    'name': product.name,
    'category': product.category,
    'price': product.price,
    'stock': product.stock,
    'cost_price': product.costPrice,
    'image_path': product.imagePath,
    'barcode': product.barcode,
    'low_stock_threshold': product.lowStockThreshold,
    'is_archived': product.isArchived,
  };

  Map<String, dynamic> _customerToRow(Customer customer) => {
    'id': customer.id,
    'name': customer.name,
    'phone': customer.phone,
    'ledger': customer.ledger.map(_ledgerToRow).toList(),
  };

  Map<String, dynamic> _ledgerToRow(LedgerEntry entry) => {
    'id': entry.id,
    'created_at': entry.createdAt.toIso8601String(),
    'entry_type': entry.type == LedgerEntryType.payment ? 'payment' : 'credit',
    'amount': entry.amount,
    'note': entry.note,
    'sale_id': entry.saleId,
  };

  Map<String, dynamic> _saleToRow(SaleRecord sale) => {
    'id': sale.id,
    'created_at': sale.createdAt.toIso8601String(),
    'items': sale.items.map(_saleItemToRow).toList(),
    'total': sale.total,
    'payment_type': sale.paymentType == PaymentType.utang ? 'utang' : 'cash',
    'amount_received': sale.amountReceived,
    'change_amount': sale.change,
    'customer_id': sale.customerId,
  };

  Map<String, dynamic> _saleItemToRow(SaleItem item) => {
    'product_id': item.productId,
    'product_name': item.productName,
    'quantity': item.quantity,
    'unit_price': item.unitPrice,
    'unit_cost': item.unitCost,
  };

  void _queueSave() {
    if (storage == null) return;
    _persistenceQueue = _persistenceQueue.then((_) async {
      try {
        await storage!.saveSnapshot(_snapshot());
        storageError = null;
      } catch (error) {
        storageError = 'Local data could not be saved: $error';
      }
      notifyListeners();
    });
    unawaited(_persistenceQueue);
  }

  Future<String?> _saveNow() async {
    if (storage == null) return null;
    _queueSave();
    await _persistenceQueue;
    return storageError;
  }

  String _nextId(Iterable<String> ids) {
    var greatest = DateTime.now().microsecondsSinceEpoch - 1;
    for (final id in ids) {
      final number = int.tryParse(id) ?? 0;
      if (number > greatest) greatest = number;
    }
    return '${greatest + 1}';
  }
}
