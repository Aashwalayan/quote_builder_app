import 'package:flutter/material.dart';
import 'preview_page.dart';

class QuoteFormPage extends StatefulWidget {
  const QuoteFormPage({super.key});

  @override
  State<QuoteFormPage> createState() => _QuoteFormPageState();
}

class _QuoteFormPageState extends State<QuoteFormPage> {
  final clientName = TextEditingController();
  final clientAddress = TextEditingController();
  final clientReference = TextEditingController();

  List<Map<String, dynamic>> items = [];
  double subtotal = 0, total = 0;

  void addItem() {
    setState(() {
      items.add({'name': '', 'qty': 1.0, 'rate': 0.0, 'discount': 0.0, 'tax': 0.0});
    });
  }

  void removeItem(int index) {
    setState(() {
      items.removeAt(index);
      calculateTotals();
    });
  }

  void calculateTotals() {
    double newSubtotal = 0;
    for (var item in items) {
      double qty = item['qty'] ?? 0;
      double rate = item['rate'] ?? 0;
      double discount = item['discount'] ?? 0;
      double tax = item['tax'] ?? 0;

      if (qty <= 0 || rate <= 0) continue;

      double discounted = rate * (1 - discount / 100);
      double base = discounted * qty;
      double taxValue = base * (tax / 100);
      newSubtotal += base + taxValue;
    }
    setState(() {
      subtotal = newSubtotal;
      total = newSubtotal;
    });
  }

  void openPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreviewPage(
          clientName: clientName.text,
          clientAddress: clientAddress.text,
          clientReference: clientReference.text,
          items: items,
          subtotal: subtotal,
          total: total,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Quote Builder')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TextField(
      controller: clientName,
      decoration: InputDecoration(
        hintText: "Client's name",
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: clientAddress,
      decoration: InputDecoration(
        hintText: "Address",
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: clientReference,
      decoration: InputDecoration(
        hintText: "Reference",
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    ),
  ],
),
const SizedBox(height: 20),

            items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No items added yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      var item = items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              TextField(
                                decoration: const InputDecoration(labelText: 'Product/Service'),
                                onChanged: (v) => item['name'] = v,
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: const InputDecoration(labelText: 'Qty'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        item['qty'] = double.tryParse(v) ?? 0;
                                        calculateTotals();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      decoration: const InputDecoration(labelText: 'Rate'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        item['rate'] = double.tryParse(v) ?? 0;
                                        calculateTotals();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: const InputDecoration(
                                        labelText: 'Discount',
                                        suffixText: '%',
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        item['discount'] = double.tryParse(v) ?? 0;
                                        calculateTotals();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      decoration: const InputDecoration(
                                        labelText: 'Tax',
                                        suffixText: '%',
                                      ),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) {
                                        item['tax'] = double.tryParse(v) ?? 0;
                                        calculateTotals();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => removeItem(index),
                                  child: const Text('Remove'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: addItem, child: const Text('Add Item')),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Subtotal: ₹${subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Grand Total: ₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: openPreview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
                child: const Text('Preview Quote'),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
