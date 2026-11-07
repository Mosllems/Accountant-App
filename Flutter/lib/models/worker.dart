// Data models mirroring the Django REST API (payroll app).
// Field meanings follow payroll/models.py; values are never recomputed here.

import '../core/format/jalali.dart';
import '../core/format/money.dart';

/// Account status values sent by the backend (`MonthlyAccount.status`).
enum AccountStatus {
  debtor('debtor', 'بدهکار'),
  creditor('creditor', 'طلبکار'),
  paid('paid', 'تسویه‌شده'),
  unknown('', 'نامشخص');

  const AccountStatus(this.apiValue, this.fallbackLabel);

  final String apiValue;
  final String fallbackLabel;

  static AccountStatus fromApi(String? value) =>
      AccountStatus.values.firstWhere(
        (s) => s.apiValue == value,
        orElse: () => AccountStatus.unknown,
      );
}

/// Worker as returned by `/api/workers/`.
class Worker {
  const Worker({
    required this.id,
    required this.name,
    required this.startDate,
    required this.isActive,
  });

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    startDate: json['start_date']?.toString() ?? '',
    isActive: json['is_active'] as bool? ?? true,
  );

  final int id;
  final String name;

  /// Jalali date string from the API, e.g. `1403-05-12`.
  final String startDate;
  final bool isActive;
}

/// Worker with all monthly accounts, from `/api/workers/{id}/`.
class WorkerDetail extends Worker {
  const WorkerDetail({
    required super.id,
    required super.name,
    required super.startDate,
    required super.isActive,
    required this.monthlyAccounts,
  });

  factory WorkerDetail.fromJson(Map<String, dynamic> json) {
    final accountsJson = json['monthly_accounts'] as List<dynamic>? ?? [];
    return WorkerDetail(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      startDate: json['start_date']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
      monthlyAccounts: accountsJson
          .map((e) => MonthlyAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<MonthlyAccount> monthlyAccounts;

  /// The account of a given Jalali month, if the backend has one.
  MonthlyAccount? accountFor(YearMonth month) {
    for (final a in monthlyAccounts) {
      if (a.yearMonth == month) return a;
    }
    return null;
  }

  /// Most recent month that has an account.
  MonthlyAccount? get latestAccount {
    MonthlyAccount? latest;
    for (final a in monthlyAccounts) {
      final ym = a.yearMonth;
      if (ym == null) continue;
      if (latest == null || ym.compareTo(latest.yearMonth!) > 0) latest = a;
    }
    return latest;
  }

  /// All payments of this worker (across months).
  Iterable<Payment> get allPayments =>
      monthlyAccounts.expand((a) => a.payments);

  /// Most recent payment by date (then id), or null.
  Payment? get lastPayment {
    Payment? last;
    for (final p in allPayments) {
      if (last == null || p.compareByDate(last) > 0) last = p;
    }
    return last;
  }
}

/// Nested `monthly_salary`.
class MonthlySalary {
  const MonthlySalary({
    required this.id,
    required this.year,
    required this.month,
    required this.salary,
  });

  factory MonthlySalary.fromJson(Map<String, dynamic> json) => MonthlySalary(
    id: json['id'] as int,
    year: json['year'] as int,
    month: json['month'] as int,
    salary: _money(json, 'salary'),
  );

  final int id;
  final int year;
  final int month;

  /// Base monthly salary (input value) — NOT the accrued amount.
  final num salary;
}

/// Monthly account with backend-computed values.
class MonthlyAccount {
  const MonthlyAccount({
    required this.id,
    required this.monthlySalary,
    required this.eligibleDays,
    required this.dailySalary,
    required this.calculatedAmount,
    required this.totalPayments,
    required this.balance,
    required this.status,
    required this.statusDisplay,
    required this.settledAt,
    required this.payments,
  });

  factory MonthlyAccount.fromJson(Map<String, dynamic> json) {
    final paymentsJson = json['payments'] as List<dynamic>? ?? [];
    final salaryJson = json['monthly_salary'];
    return MonthlyAccount(
      id: json['id'] as int,
      monthlySalary: salaryJson is Map<String, dynamic>
          ? MonthlySalary.fromJson(salaryJson)
          : null,
      eligibleDays: json['eligible_days'] as int?,
      dailySalary: parseMoney(json['daily_salary']),
      calculatedAmount: _money(json, 'calculated_amount'),
      totalPayments: _money(json, 'total_payments'),
      balance: _money(json, 'balance'),
      status: AccountStatus.fromApi(json['status']?.toString()),
      statusDisplay: json['status_display']?.toString() ?? '',
      settledAt: json['settled_at']?.toString(),
      payments: paymentsJson
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final MonthlySalary? monthlySalary;
  final int? eligibleDays;
  final num? dailySalary;

  /// Accrued salary for the eligible days (backend computed).
  final num calculatedAmount;
  final num totalPayments;
  final num balance;
  final AccountStatus status;

  /// Backend label for [status] — preferred for display.
  final String statusDisplay;
  final String? settledAt;
  final List<Payment> payments;

  YearMonth? get yearMonth => monthlySalary == null
      ? null
      : YearMonth(monthlySalary!.year, monthlySalary!.month);

  String get statusLabel =>
      statusDisplay.isNotEmpty ? statusDisplay : status.fallbackLabel;
}

/// A payment (nested in accounts, or from `/api/payments/`).
class Payment {
  const Payment({
    required this.id,
    required this.amount,
    required this.date,
    required this.description,
  });

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
    id: json['id'] as int,
    amount: _money(json, 'amount'),
    date: json['date']?.toString() ?? '',
    description: (json['description'] as String?)?.trim().isEmpty ?? true
        ? null
        : (json['description'] as String).trim(),
  );

  final int id;
  final num amount;

  /// Jalali date string from the API, e.g. `1405-06-17`.
  final String date;
  final String? description;

  Jalali? get jalaliDate => parseApiDate(date);

  /// Orders by date, then id (newer id wins on same date).
  int compareByDate(Payment other) {
    final a = jalaliDate;
    final b = other.jalaliDate;
    if (a != null && b != null) {
      final c = a.compareTo(b);
      if (c != 0) return c;
    } else if (a != null) {
      return 1;
    } else if (b != null) {
      return -1;
    }
    return id.compareTo(other.id);
  }
}

/// Required money field: fails loudly instead of silently becoming 0.
num _money(Map<String, dynamic> json, String key) {
  final value = parseMoney(json[key]);
  if (value == null) {
    throw FormatException('Invalid money field "$key"');
  }
  return value;
}
