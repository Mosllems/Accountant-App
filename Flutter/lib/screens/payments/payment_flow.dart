import 'package:flutter/material.dart';

import '../../models/worker.dart';
import 'register_payment_screen.dart';
import 'select_worker_screen.dart';

/// Starts "register payment".
/// - With [worker] (from worker details): opens the form directly.
/// - Without: opens worker selection first, then the form.
Future<void> startPaymentFlow(BuildContext context, {WorkerDetail? worker}) {
  final navigator = Navigator.of(context);
  if (worker != null) {
    return navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterPaymentScreen(worker: worker),
      ),
    );
  }
  return navigator.push(
    MaterialPageRoute<void>(builder: (_) => const SelectWorkerScreen()),
  );
}
