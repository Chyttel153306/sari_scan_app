import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../utils/formatters.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import '../widgets/price_text.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.sale});

  final SaleRecord sale;

  Future<Uint8List> _buildReceiptPdf(PdfPageFormat format) async {
    final document = pw.Document(
      title: 'SariScan ${receiptNumber(sale.id)}',
      author: 'SariScan',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'SariScan - Tindahan POS',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 14),
          _pdfRow('Receipt', receiptNumber(sale.id)),
          _pdfRow('Date', shortDateTime(sale.createdAt)),
          _pdfRow(
            'Payment',
            sale.paymentType == PaymentType.cash ? 'Cash' : 'Utang',
          ),
          pw.Divider(),
          ...sale.items.map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '${item.quantity} x ${item.productName}\n'
                      'PHP ${item.unitPrice.toStringAsFixed(2)} each',
                    ),
                  ),
                  pw.Text('PHP ${item.subtotal.toStringAsFixed(2)}'),
                ],
              ),
            ),
          ),
          pw.Divider(),
          _pdfRow('Total', 'PHP ${sale.total.toStringAsFixed(2)}', bold: true),
          if (sale.paymentType == PaymentType.cash) ...[
            _pdfRow(
              'Cash received',
              'PHP ${sale.amountReceived.toStringAsFixed(2)}',
            ),
            _pdfRow(
              'Change',
              'PHP ${sale.change.toStringAsFixed(2)}',
              bold: true,
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Center(child: pw.Text('Thank you!')),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _pdfRow(String label, String value, {bool bold = false}) {
    final style = bold ? pw.TextStyle(fontWeight: pw.FontWeight.bold) : null;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          pw.SizedBox(width: 12),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  Future<void> _print(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        name: 'SariScan-${receiptNumber(sale.id)}',
        onLayout: _buildReceiptPdf,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open printing: $error')),
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    try {
      final bytes = await _buildReceiptPdf(PdfPageFormat.a4);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'SariScan-${receiptNumber(sale.id)}.pdf',
        subject: 'SariScan receipt ${receiptNumber(sale.id)}',
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share the receipt: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCash = sale.paymentType == PaymentType.cash;
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Complete')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _print(context),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _share(context),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Send'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.add_circle_outline, size: 19),
                label: const Text('New Transaction'),
              ),
            ],
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeading(
                        isCash ? 'Payment & change' : 'Utang recorded',
                        trailing: StatusPill(
                          isCash ? 'Paid in cash' : 'Store credit',
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Amount received',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 4),
                      PriceText(
                        money(sale.amountReceived),
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Divider(height: 28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total due',
                                  style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 11,
                                  ),
                                ),
                                PriceText(
                                  money(sale.total),
                                  style: const TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isCash ? 'Change due' : 'Added to ledger',
                                  style: const TextStyle(
                                    color: AppTheme.emerald,
                                    fontSize: 11,
                                  ),
                                ),
                                PriceText(
                                  money(isCash ? sale.change : sale.total),
                                  style: const TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    color: AppTheme.emerald,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              PhysicalShape(
                clipper: _ReceiptClipper(),
                color: Colors.white,
                shadowColor: const Color(0x160F172A),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 36,
                        color: AppTheme.ink,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tindahan POS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SariScan digital receipt',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 16),
                      _ReceiptRow(
                        label: 'Receipt',
                        value: receiptNumber(sale.id),
                      ),
                      _ReceiptRow(
                        label: 'Date',
                        value: shortDateTime(sale.createdAt),
                      ),
                      _ReceiptRow(
                        label: 'Payment',
                        value: isCash ? 'Cash' : 'Utang',
                      ),
                      const Divider(height: 28),
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'ITEM DESCRIPTION',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.muted,
                                letterSpacing: .8,
                              ),
                            ),
                          ),
                          Text(
                            'SUBTOTAL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.muted,
                              letterSpacing: .8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...sale.items.map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.quantity} × ${money(item.unitPrice)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: PriceText(
                                    money(item.subtotal),
                                    style: const TextStyle(
                                      fontFamily: 'SpaceGrotesk',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 28),
                      _ReceiptRow(
                        label: 'Total bill',
                        value: money(sale.total),
                        emphasize: true,
                      ),
                      if (isCash) ...[
                        _ReceiptRow(
                          label: 'Cash tendered',
                          value: money(sale.amountReceived),
                        ),
                        _ReceiptRow(
                          label: 'Change returned',
                          value: money(sale.change),
                        ),
                      ],
                      const Divider(height: 28),
                      const Text(
                        'Salamat sa inyong pagtangkilik!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: AppTheme.emerald,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(18, 0)
      ..lineTo(size.width - 18, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 18)
      ..lineTo(size.width, size.height - 8);
    final teeth = (size.width / 14).round();
    final width = size.width / teeth;
    for (var i = teeth; i > 0; i--) {
      path
        ..lineTo((i - .5) * width, size.height)
        ..lineTo((i - 1) * width, size.height - 8);
    }
    return path
      ..lineTo(0, 18)
      ..quadraticBezierTo(0, 0, 18, 0)
      ..close();
  }

  @override
  bool shouldReclip(_ReceiptClipper oldClipper) => false;
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(value, textAlign: TextAlign.right, style: style),
            ),
          ),
        ],
      ),
    );
  }
}
