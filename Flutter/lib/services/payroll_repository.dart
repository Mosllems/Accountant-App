import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/format/jalali.dart';
import '../data/placeholder/payment_create_placeholder.dart';
import '../models/worker.dart';
import 'api_client.dart';

/// A payment together with its worker and monthly account.
class PaymentEntry {
  const PaymentEntry({
    required this.payment,
    required this.worker,
    required this.account,
  });

  final Payment payment;
  final WorkerDetail worker;
  final MonthlyAccount account;
}

/// A worker's account for one month.
class WorkerAccount {
  const WorkerAccount(this.worker, this.account);

  final WorkerDetail worker;
  final MonthlyAccount account;
}

/// Complete, consistent view of the backend data at one point in time.
///
/// Built from `/api/workers/` + `/api/workers/{id}/`, which is the only API
/// path that links workers → accounts → payments (BACKEND-GAP(worker-link)).
/// The API is unpaginated, so this dataset is complete.
class PayrollSnapshot {
  PayrollSnapshot(List<WorkerDetail> workers)
    : workers = List.unmodifiable(workers),
      payments = List.unmodifiable(_collectPayments(workers));

  final List<WorkerDetail> workers;

  /// All payments, newest first (by date, then id).
  final List<PaymentEntry> payments;

  static List<PaymentEntry> _collectPayments(List<WorkerDetail> workers) {
    final list = <PaymentEntry>[
      for (final w in workers)
        for (final a in w.monthlyAccounts)
          for (final p in a.payments)
            PaymentEntry(payment: p, worker: w, account: a),
    ];
    list.sort((x, y) => y.payment.compareByDate(x.payment));
    return list;
  }

  List<WorkerDetail> get activeWorkers =>
      workers.where((w) => w.isActive).toList();

  WorkerDetail? workerById(int id) {
    for (final w in workers) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// One entry per worker that has an account in [month] (unique workers,
  /// since the backend enforces one salary per worker per month).
  List<WorkerAccount> accountsIn(YearMonth month) => [
    for (final w in workers)
      if (w.accountFor(month) case final a?) WorkerAccount(w, a),
  ];

  /// Payments whose payment date falls in [month].
  List<PaymentEntry> paymentsDatedIn(YearMonth month) =>
      payments.where((e) => month.contains(e.payment.jalaliDate)).toList();

  /// Months that have at least one account, ascending.
  List<YearMonth> get accountMonths {
    final set = <YearMonth>{
      for (final w in workers)
        for (final a in w.monthlyAccounts) ?a.yearMonth,
    };
    return set.toList()..sort();
  }
}

/// Result of a payment submission.
enum PaymentCreateOutcome {
  /// The backend confirmed and saved the payment.
  saved,

  /// Demo mode (BACKEND-GAP(payment-create)): nothing was sent or saved.
  demoNotSaved,
}

/// Single source of backend data for all screens.
///
/// Uses Flutter's built-in [ChangeNotifier] (no state-management package).
/// Keeps the previous snapshot while refreshing so screens never blank out.
class PayrollRepository extends ChangeNotifier {
  PayrollRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  PayrollSnapshot? _snapshot;
  ApiException? _error;
  Future<void>? _inFlight;

  PayrollSnapshot? get snapshot => _snapshot;
  ApiException? get error => _error;
  bool get isLoading => _inFlight != null;

  /// Loads once; later calls reuse the existing data.
  Future<void> ensureLoaded() => _snapshot != null ? Future.value() : refresh();

  /// Reloads everything. Concurrent calls share one request.
  Future<void> refresh() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _load();
    _inFlight = future;
    notifyListeners();
    return future;
  }

  Future<void> _load() async {
    try {
      final list = await _api.getWorkers();
      final ids = list.map((w) => w['id'] as int).toList();
      // N+1: the list endpoint has no accounts (BACKEND-GAP(worker-link)).
      final details = await Future.wait(ids.map(_api.getWorkerDetail));
      _snapshot = PayrollSnapshot(details.map(WorkerDetail.fromJson).toList());
      _error = null;
    } on ApiException catch (e) {
      _error = e;
    } on Object {
      // Malformed data: never show partial or guessed numbers.
      _error = ApiException(
        ApiErrorKind.invalidResponse,
        'داده‌های دریافتی از سرور معتبر نیست.',
      );
    } finally {
      _inFlight = null;
      notifyListeners();
    }
  }

  /// Creates a worker (`POST /api/workers/`), then refreshes.
  Future<void> createWorker({
    required String name,
    required Jalali startDate,
    required bool isActive,
  }) async {
    await _api.createWorker(
      name: name,
      startDate: toApiDate(startDate),
      isActive: isActive,
    );
    unawaited(refresh());
  }

  /// Deletes a worker (`DELETE /api/workers/{id}/`), then refreshes.
  Future<void> deleteWorker(int id) async {
    await _api.deleteWorker(id);
    unawaited(refresh());
  }

  /// Registers a payment against [account].
  ///
  /// [amount] must already be normalized ASCII digits.
  Future<PaymentCreateOutcome> createPayment({
    required MonthlyAccount account,
    required String amount,
    required Jalali date,
    String? description,
  }) async {
    if (!kPaymentCreateSupportedByBackend) {
      // BACKEND-GAP(payment-create): demo mode, nothing is sent.
      await simulatePaymentCreate();
      return PaymentCreateOutcome.demoNotSaved;
    }
    await _api.createPayment(
      monthlyAccountId: account.id,
      amount: amount,
      date: toApiDate(date),
      description: description,
    );
    unawaited(refresh());
    return PaymentCreateOutcome.saved;
  }
}
