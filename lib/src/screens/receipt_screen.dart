import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import '../utils/formatters.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isCash) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Amount Received'),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        money(sale.amountReceived),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Due'),
                            Text(
                              money(sale.total),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Change',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              money(sale.change),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.storefront_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tindahan POS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ReceiptRow(label: 'Receipt', value: receiptNumber(sale.id)),
                  _ReceiptRow(
                    label: 'Date',
                    value: shortDateTime(sale.createdAt),
                  ),
                  _ReceiptRow(
                    label: 'Payment',
                    value: isCash ? 'Cash' : 'Utang',
                  ),
                  const Divider(height: 28),
                  ...sale.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity} × ${item.productName}\n'
                              '${money(item.unitPrice)} each',
                            ),
                          ),
                          Text(money(item.subtotal)),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 28),
                  _ReceiptRow(
                    label: 'Total',
                    value: money(sale.total),
                    emphasize: true,
                  ),
                  if (isCash) ...[
                    _ReceiptRow(
                      label: 'Cash received',
                      value: money(sale.amountReceived),
                    ),
                    _ReceiptRow(
                      label: 'Change',
                      value: money(sale.change),
                      emphasize: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _print(context),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Send'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('New Transaction'),
          ),
        ],
      ),
    );
  }
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
            child: Text(value, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
  }
}
