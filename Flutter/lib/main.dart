import 'package:flutter/material.dart';

import 'screens/worker_list_screen.dart';

void main() {
  runApp(const PayrollApp());
}

class PayrollApp extends StatelessWidget {
  const PayrollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'حسابدار',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // کل اپ راست‌به‌چپ است
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const WorkerListScreen(),
    );
  }
}
