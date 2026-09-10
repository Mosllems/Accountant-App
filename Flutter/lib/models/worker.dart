// مدل‌های داده‌ای مربوط به کارگر و حساب‌های ماهانه.
// این کلاس‌ها خروجی JSON بک‌اند جنگو را به آبجکت‌های Dart تبدیل می‌کنند.

/// کارگر در حالت لیست (صفحه اصلی) — فقط اطلاعات پایه.
class Worker {
  final int id;
  final String name;
  final String startDate; // تاریخ جلالی به‌صورت رشته (مثلاً 1403-05-12)
  final bool isActive;

  Worker({
    required this.id,
    required this.name,
    required this.startDate,
    required this.isActive,
  });

  factory Worker.fromJson(Map<String, dynamic> json) {
    return Worker(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      startDate: json['start_date']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// کارگر در حالت جزئیات — شامل لیست حساب‌های ماهانه.
class WorkerDetail {
  final int id;
  final String name;
  final String startDate;
  final bool isActive;
  final List<MonthlyAccount> monthlyAccounts;

  WorkerDetail({
    required this.id,
    required this.name,
    required this.startDate,
    required this.isActive,
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
}

/// حقوق ماهانه — تودرتو داخل حساب ماهانه.
class MonthlySalary {
  final int id;
  final int year;
  final int month;
  final num salary;

  MonthlySalary({
    required this.id,
    required this.year,
    required this.month,
    required this.salary,
  });

  factory MonthlySalary.fromJson(Map<String, dynamic> json) {
    return MonthlySalary(
      id: json['id'] as int,
      year: json['year'] as int? ?? 0,
      month: json['month'] as int? ?? 0,
      salary: _toNum(json['salary']),
    );
  }
}

/// حساب ماهانه — با تمام مقادیر محاسبه‌شده در بک‌اند.
class MonthlyAccount {
  final int id;
  final MonthlySalary? monthlySalary;
  final int eligibleDays;
  final num dailySalary;
  final num calculatedAmount;
  final num totalPayments;
  final num balance;
  final String status; // creditor | debtor | paid
  final String statusDisplay; // طلبکار | بدهکار | تسویه شده
  final String? settledAt;
  final List<Payment> payments;

  MonthlyAccount({
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
    return MonthlyAccount(
      id: json['id'] as int,
      monthlySalary: json['monthly_salary'] != null
          ? MonthlySalary.fromJson(
              json['monthly_salary'] as Map<String, dynamic>)
          : null,
      eligibleDays: json['eligible_days'] as int? ?? 0,
      dailySalary: _toNum(json['daily_salary']),
      calculatedAmount: _toNum(json['calculated_amount']),
      totalPayments: _toNum(json['total_payments']),
      balance: _toNum(json['balance']),
      status: json['status']?.toString() ?? '',
      statusDisplay: json['status_display']?.toString() ?? '',
      settledAt: json['settled_at']?.toString(),
      payments: paymentsJson
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// یک پرداخت.
class Payment {
  final int id;
  final num amount;
  final String date;
  final String? description;

  Payment({
    required this.id,
    required this.amount,
    required this.date,
    required this.description,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as int,
      amount: _toNum(json['amount']),
      date: json['date']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}

/// DRF مقادیر Decimal را گاهی به‌صورت رشته ("12000") برمی‌گرداند.
/// این تابع هم رشته و هم عدد را امن به num تبدیل می‌کند.
num _toNum(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  return num.tryParse(value.toString()) ?? 0;
}
