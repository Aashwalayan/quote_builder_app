import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

enum TaxMode { inclusive, exclusive }
enum QuoteStatus { Draft, Sent, Accepted }

class Quote {
  String id;
  String clientName;
  String clientAddress;
  String clientReference;
  List<Map<String, dynamic>> items;
  double subtotalInINR;
  double totalInINR;
  QuoteStatus status;
  String createdAt;
  Quote({
    required this.id,
    required this.clientName,
    required this.clientAddress,
    required this.clientReference,
    required this.items,
    required this.subtotalInINR,
    required this.totalInINR,
    required this.status,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'clientName': clientName,
        'clientAddress': clientAddress,
        'clientReference': clientReference,
        'items': items,
        'subtotalInINR': subtotalInINR,
        'totalInINR': totalInINR,
        'status': status.index,
        'createdAt': createdAt,
      };
  static Quote fromJson(Map<String, dynamic> j) => Quote(
        id: j['id'],
        clientName: j['clientName'],
        clientAddress: j['clientAddress'],
        clientReference: j['clientReference'],
        items: List<Map<String, dynamic>>.from(j['items']),
        subtotalInINR: (j['subtotalInINR'] as num).toDouble(),
        totalInINR: (j['totalInINR'] as num).toDouble(),
        status: QuoteStatus.values[j['status']],
        createdAt: j['createdAt'],
      );
}

class PreviewPage extends StatefulWidget {
  final String clientName;
  final String clientAddress;
  final String clientReference;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double total;
  const PreviewPage({
    super.key,
    required this.clientName,
    required this.clientAddress,
    required this.clientReference,
    required this.items,
    required this.subtotal,
    required this.total,
  });
  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  TaxMode taxMode = TaxMode.exclusive;
  QuoteStatus currentStatus = QuoteStatus.Draft;
  final Map<String, String> currencyMap = {
    'INR (₹)': '₹',
    'USD (\$)': '\$',
    'EUR (€)': '€',
    'GBP (£)': '£',
  };
  final Map<String, String> currencyLocale = {
    'INR (₹)': 'en_IN',
    'USD (\$)': 'en_US',
    'EUR (€)': 'de_DE',
    'GBP (£)': 'en_GB',
  };
  final Map<String, double> conversionRateToINR = {
    'INR (₹)': 1.0,
    'USD (\$)': 83.0,
    'EUR (€)': 90.0,
    'GBP (£)': 104.0,
  };
  String selectedCurrencyLabel = 'INR (₹)';

  String get currencySymbol => currencyMap[selectedCurrencyLabel] ?? '₹';

  NumberFormat get currencyFormat => NumberFormat.currency(
        locale: currencyLocale[selectedCurrencyLabel],
        symbol: currencySymbol,
      );

  double convertFromINR(double inrAmount) {
    final rate = conversionRateToINR[selectedCurrencyLabel] ?? 1.0;
    return inrAmount / rate;
  }

  double computeItemTotalInINR(Map<String, dynamic> item) {
    final rate = (item['rate'] ?? 0.0) as double;
    final discount = (item['discount'] ?? 0.0) as double;
    final qty = (item['qty'] ?? 0.0) as double;
    final tax = (item['tax'] ?? 0.0) as double;
    final discountedPerUnit = rate * (1 - discount / 100);
    final base = discountedPerUnit * qty;
    if (taxMode == TaxMode.inclusive) {
      return base;
    } else {
      final taxValue = base * (tax / 100);
      return base + taxValue;
    }
  }

  double get computedSubtotalInINR =>
      widget.items.fold(0.0, (s, it) => s + computeItemTotalInINR(it));

  Future<void> saveQuoteLocally(Quote q) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList('quotes') ?? [];
    final idx = list.indexWhere((e) => jsonDecode(e)['id'] == q.id);
    if (idx >= 0)
      list[idx] = jsonEncode(q.toJson());
    else
      list.add(jsonEncode(q.toJson()));
    await sp.setStringList('quotes', list);
  }

  Future<void> updateQuoteStatusAndSave(String id, QuoteStatus status) async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList('quotes') ?? [];
    for (var i = 0; i < list.length; i++) {
      final m = jsonDecode(list[i]);
      if (m['id'] == id) {
        m['status'] = status.index;
        list[i] = jsonEncode(m);
        break;
      }
    }
    await sp.setStringList('quotes', list);
  }

  Future<void> saveCurrentQuote() async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Save as PDF?'),
        content: const Text('Do you want to save the quote as a PDF file as well?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Yes')),
        ],
      ),
    );
    if (choice == true) {
      final q = Quote(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        clientName: widget.clientName,
        clientAddress: widget.clientAddress,
        clientReference: widget.clientReference,
        items: widget.items.map((it) {
          final map = Map<String, dynamic>.from(it);
          map['totalInINR'] = computeItemTotalInINR(it);
          return map;
        }).toList(),
        subtotalInINR: computedSubtotalInINR,
        totalInINR: computedSubtotalInINR,
        status: currentStatus,
        createdAt: DateTime.now().toIso8601String(),
      );
      await saveQuoteAndPdfAndShare(q, currencySymbol: currencyMap[selectedCurrencyLabel] ?? '₹', context: context);
      return;
    }
    final q = Quote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      clientName: widget.clientName,
      clientAddress: widget.clientAddress,
      clientReference: widget.clientReference,
      items: widget.items,
      subtotalInINR: computedSubtotalInINR,
      totalInINR: computedSubtotalInINR,
      status: currentStatus,
      createdAt: DateTime.now().toIso8601String(),
    );
    await saveQuoteLocally(q);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote saved locally!')));
  }

  Future<void> sendCurrentQuote() async {
    setState(() => currentStatus = QuoteStatus.Sent);
    final q = Quote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      clientName: widget.clientName,
      clientAddress: widget.clientAddress,
      clientReference: widget.clientReference,
      items: widget.items.map((it) {
        final map = Map<String, dynamic>.from(it);
        map['totalInINR'] = computeItemTotalInINR(it);
        return map;
      }).toList(),
      subtotalInINR: computedSubtotalInINR,
      totalInINR: computedSubtotalInINR,
      status: currentStatus,
      createdAt: DateTime.now().toIso8601String(),
    );
    await saveQuoteLocally(q);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote Sent!')));
  }

  Future<void> acceptCurrentQuote() async {
    setState(() => currentStatus = QuoteStatus.Accepted);
    final q = Quote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      clientName: widget.clientName,
      clientAddress: widget.clientAddress,
      clientReference: widget.clientReference,
      items: widget.items.map((it) {
        final map = Map<String, dynamic>.from(it);
        map['totalInINR'] = computeItemTotalInINR(it);
        return map;
      }).toList(),
      subtotalInINR: computedSubtotalInINR,
      totalInINR: computedSubtotalInINR,
      status: currentStatus,
      createdAt: DateTime.now().toIso8601String(),
    );
    await saveQuoteLocally(q);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quote Accepted!')));
  }

  Future<Uint8List> buildQuotePdfBytes(Quote q, String currencySymbol) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text('Quote', style: pw.TextStyle(fontSize: 24))),
          pw.SizedBox(height: 6),
          pw.Text('Client: ${q.clientName}'),
          pw.Text('Address: ${q.clientAddress}'),
          pw.Text('Reference: ${q.clientReference}'),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Item', 'Qty', 'Rate', 'Discount %', 'Tax %', 'Total'],
            data: q.items.map((it) {
              final name = it['name'].toString();
              final qty = (it['qty'] ?? 0).toString();
              final rate = (it['rate'] ?? 0).toString();
              final disc = (it['discount'] ?? 0).toString();
              final tax = (it['tax'] ?? 0).toString();
              final total = (it['totalInINR'] ?? '').toString();
              return [name, qty, '$currencySymbol$rate', disc, tax, '$currencySymbol${total}'];
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Subtotal: $currencySymbol${q.subtotalInINR.toStringAsFixed(2)}'),
              pw.Text('Grand Total: $currencySymbol${q.totalInINR.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ]),
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Status: ${q.status.toString().split('.').last}'),
          pw.SizedBox(height: 6),
          pw.Text('Created: ${q.createdAt}'),
        ],
      ),
    );
    return pdf.save();
  }

  Future<String> savePdfFile(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> saveQuoteAndPdfAndShare(Quote q, {required String currencySymbol, required BuildContext context}) async {
    await saveQuoteLocally(q);
    final bytes = await buildQuotePdfBytes(q, currencySymbol);
    final filename = 'quote_${q.id}.pdf';
    final path = await savePdfFile(bytes, filename);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF created at: $path')));
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: DropdownButton<TaxMode>(
              value: taxMode,
              underline: const SizedBox(),
              onChanged: (v) => setState(() => taxMode = v!),
              items: const [
                DropdownMenuItem(value: TaxMode.exclusive, child: Text('Tax-exclusive')),
                DropdownMenuItem(value: TaxMode.inclusive, child: Text('Tax-inclusive')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: selectedCurrencyLabel,
              underline: const SizedBox(),
              onChanged: (v) => setState(() => selectedCurrencyLabel = v!),
              items: currencyMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Quote for ${widget.clientName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.clientAddress),
            const SizedBox(height: 4),
            Text('Reference: ${widget.clientReference}'),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<QuoteStatus>(
                value: currentStatus,
                onChanged: (v) => setState(() => currentStatus = v!),
                items: QuoteStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.toString().split('.').last))).toList(),
              ),
            ]),
            const SizedBox(height: 16),
            Table(
              border: TableBorder.all(color: Colors.grey),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1.4),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(0.8),
                5: FlexColumnWidth(1.7),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Colors.indigoAccent),
                  children: [
                    Padding(padding: EdgeInsets.all(8), child: Text('Item', style: TextStyle(color: Colors.white))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Qty', style: TextStyle(color: Colors.white))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Rate', style: TextStyle(color: Colors.white))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Discount %', style: TextStyle(color: Colors.white))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Tax %', style: TextStyle(color: Colors.white))),
                    Padding(padding: EdgeInsets.all(8), child: Text('Total', style: TextStyle(color: Colors.white))),
                  ],
                ),
                ...items.map((item) {
                  var rate = item['rate'] ?? 0.0;
                  var discount = item['discount'] ?? 0.0;
                  var qty = item['qty'] ?? 0.0;
                  var tax = item['tax'] ?? 0.0;
                  var totalInINR = computeItemTotalInINR(item);
                  return TableRow(children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(item['name'], softWrap: true, overflow: TextOverflow.visible)),
                    Padding(padding: const EdgeInsets.all(8), child: Text(qty.toStringAsFixed(0), softWrap: true, overflow: TextOverflow.visible)),
                    Padding(padding: const EdgeInsets.all(8), child: Text(currencyFormat.format(convertFromINR(rate)), softWrap: true, overflow: TextOverflow.visible)),
                    Padding(padding: const EdgeInsets.all(8), child: Text('${(discount as double).toStringAsFixed(1)}', softWrap: true, overflow: TextOverflow.visible)),
                    Padding(padding: const EdgeInsets.all(8), child: Text((tax as double).toStringAsFixed(1), softWrap: true, overflow: TextOverflow.visible)),
                    Padding(padding: const EdgeInsets.all(8), child: Text(currencyFormat.format(convertFromINR(totalInINR)), softWrap: true, overflow: TextOverflow.visible)),
                  ]);
                }),
              ],
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Subtotal: ${currencyFormat.format(convertFromINR(computedSubtotalInINR))}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Grand Total: ${currencyFormat.format(convertFromINR(computedSubtotalInINR))}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 80),
          ]),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          ElevatedButton(onPressed: saveCurrentQuote, child: const Text('Save')),
          ElevatedButton(onPressed: sendCurrentQuote, child: const Text('Send')),
          ElevatedButton(onPressed: acceptCurrentQuote, child: const Text('Accept')),
        ]),
      ),
    );
  }
}
