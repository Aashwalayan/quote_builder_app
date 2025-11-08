import 'package:flutter/material.dart';
import 'pages/quote_form_page.dart';

void main() {
  runApp(const QuoteBuilderApp());
}

class QuoteBuilderApp extends StatelessWidget {
  const QuoteBuilderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Product Quote Builder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const QuoteFormPage(),
    );
  }
}
