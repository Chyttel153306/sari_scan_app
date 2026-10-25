/// Validate the complete snapshot before touching live store state.
/// Historical sales may reference products that have since been deleted.
void validateStoreSnapshot(Map<String, dynamic> snapshot) {
  final version = snapshot['version'];
  if (version is! int || version < 1 || version > 3) {
    throw FormatException('Unsupported store data version: $version');
  }

  Never invalid(String field) =>
      throw FormatException('Invalid store data: $field');
  String text(Map row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) invalid(key);
    return value;
  }

  double number(Map row, String key, {bool optional = false}) {
    final value = row[key];
    if (optional && value == null) return 0;
    if (value is! num || !value.toDouble().isFinite || value < 0) invalid(key);
    return value.toDouble();
  }

  void integer(
    Map row,
    String key, {
    bool positive = false,
    bool optional = false,
  }) {
    final value = row[key];
    if (optional && value == null) return;
    if (value is! int || value < (positive ? 1 : 0)) invalid(key);
  }

  void date(Map row, String key) {
    final value = row[key];
    if (value is! String || DateTime.tryParse(value) == null) invalid(key);
  }

  List<Map<String, dynamic>> rows(
    Map row,
    String key, {
    bool optional = false,
  }) {
    final value = row[key];
    if (optional && value == null) return [];
    if (value is! List ||
        value.any((entry) => entry is! Map<String, dynamic>)) {
      invalid(key);
    }
    return value.cast<Map<String, dynamic>>();
  }

  void unique(List<Map<String, dynamic>> values, String field) {
    final ids = <String>{};
    for (final row in values) {
      if (!ids.add(text(row, 'id'))) invalid('duplicate $field ID');
    }
  }

  final products = rows(snapshot, 'products');
  final customers = rows(snapshot, 'customers');
  final sales = rows(snapshot, 'sales');
  final additions = rows(snapshot, 'stock_additions', optional: true);
  unique(products, 'product');
  unique(customers, 'customer');
  unique(sales, 'sale');
  unique(additions, 'stock addition');
  number(snapshot, 'markup_percent', optional: true);
  final account = snapshot['account'];
  if (account != null) {
    if (account is! Map) invalid('account');
    text(account, 'name');
  }
  for (final row in products) {
    text(row, 'name');
    text(row, 'category');
    number(row, 'price');
    number(row, 'cost_price', optional: true);
    integer(row, 'stock');
    integer(row, 'low_stock_threshold', optional: true);
    if (row['is_archived'] != null && row['is_archived'] is! bool) {
      invalid('is_archived');
    }
  }
  for (final row in customers) {
    text(row, 'name');
    final ledger = rows(row, 'ledger', optional: true);
    unique(ledger, 'ledger entry');
    for (final entry in ledger) {
      date(entry, 'created_at');
      number(entry, 'amount');
      if (!['credit', 'payment'].contains(entry['entry_type'])) {
        invalid('entry_type');
      }
    }
  }
  for (final row in sales) {
    date(row, 'created_at');
    final total = number(row, 'total');
    final received = number(row, 'amount_received');
    final change = number(row, 'change_amount');
    final items = rows(row, 'items');
    if (items.isEmpty) invalid('empty sale');
    var itemsTotal = 0.0;
    for (final item in items) {
      text(item, 'product_id');
      text(item, 'product_name');
      integer(item, 'quantity', positive: true);
      final price = number(item, 'unit_price');
      number(item, 'unit_cost', optional: true);
      itemsTotal += price * (item['quantity'] as int);
    }
    if (!itemsTotal.isFinite || (itemsTotal - total).abs() > .010001) {
      invalid('sale total');
    }
    switch (row['payment_type']) {
      case 'cash':
        if (received + .000001 < total ||
            (received - total - change).abs() > .010001) {
          invalid('cash totals');
        }
      case 'utang':
        text(row, 'customer_id');
        if (received != 0 || change != 0) invalid('utang totals');
      default:
        invalid('payment_type');
    }
  }
  for (final row in additions) {
    text(row, 'product_id');
    text(row, 'product_name');
    date(row, 'created_at');
    integer(row, 'quantity', positive: true);
  }
}
