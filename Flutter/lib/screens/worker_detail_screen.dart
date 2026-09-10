import 'package:flutter/material.dart';

import '../models/worker.dart';
import '../services/api_client.dart';
import '../utils/formatters.dart';

/// صفحه جزئیات یک کارگر — شامل حساب‌های ماهانه و پرداخت‌های هر ماه.
class WorkerDetailScreen extends StatefulWidget {
  const WorkerDetailScreen({super.key, required this.workerId});

  final int workerId;

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  final ApiClient _api = ApiClient();

  late Future<WorkerDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<WorkerDetail> _load() async {
    final json = await _api.getWorkerDetail(widget.workerId);
    return WorkerDetail.fromJson(json);
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات کارگر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'بروزرسانی',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<WorkerDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.7),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تلاش دوباره'),
                    ),
                  ],
                ),
              ),
            );
          }

          final worker = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _WorkerHeader(worker: worker),
              const SizedBox(height: 20),
              if (worker.monthlyAccounts.isEmpty)
                const _EmptyAccounts()
              else
                ...worker.monthlyAccounts.map(
                  (account) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AccountCard(account: account),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// کارت بالای صفحه — نام و وضعیت کارگر + خلاصه مالی.
class _WorkerHeader extends StatelessWidget {
  const _WorkerHeader({required this.worker});

  final WorkerDetail worker;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // جمع کل مانده تمام ماه‌ها برای نمایش خلاصه
    num totalBalance = 0;
    for (final account in worker.monthlyAccounts) {
      totalBalance += account.balance;
    }

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primary,
                  child: Text(
                    worker.name.isNotEmpty ? worker.name.characters.first : '؟',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'شروع کار: ${worker.startDate}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                _ActiveBadge(isActive: worker.isActive),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'مانده کل',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    formatCurrency(totalBalance),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _balanceColor(totalBalance),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _balanceColor(num balance) {
    if (balance > 0) return Colors.green.shade800;
    if (balance < 0) return Colors.red.shade700;
    return Colors.black87;
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.green.shade700 : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        isActive ? 'فعال' : 'غیرفعال',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// کارت یک حساب ماهانه — با قابلیت بازشدن برای دیدن پرداخت‌ها.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final MonthlyAccount account;

  @override
  Widget build(BuildContext context) {
    final salary = account.monthlySalary;
    final title = salary != null
        ? formatYearMonth(salary.year, salary.month)
        : 'حساب ماهانه';

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        leading: _StatusIcon(status: account.status),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _StatusChip(status: account.status, label: account.statusDisplay),
              const SizedBox(width: 8),
              Text(
                'مانده: ${formatCurrency(account.balance)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _statusColor(account.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _InfoRow(label: 'حقوق ماهانه', value: formatCurrency(salary?.salary ?? 0)),
          _InfoRow(label: 'حقوق روزانه', value: formatCurrency(account.dailySalary)),
          _InfoRow(label: 'روزهای مشمول', value: '${account.eligibleDays} روز'),
          _InfoRow(
            label: 'مبلغ محاسبه‌شده',
            value: formatCurrency(account.calculatedAmount),
          ),
          _InfoRow(
            label: 'کل پرداختی',
            value: formatCurrency(account.totalPayments),
          ),
          _InfoRow(
            label: 'مانده',
            value: formatCurrency(account.balance),
            valueColor: _statusColor(account.status),
            bold: true,
          ),
          if (account.settledAt != null && account.settledAt!.isNotEmpty)
            _InfoRow(label: 'تاریخ تسویه', value: account.settledAt!),
          const Divider(height: 24),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'پرداخت‌ها (${account.payments.length})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          if (account.payments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'پرداختی ثبت نشده است.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          else
            ...account.payments.map((p) => _PaymentTile(payment: p)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, size: 20, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatCurrency(payment.amount),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  payment.date,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                if (payment.description != null && payment.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      payment.description!,
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: _statusColor(status).withValues(alpha: 0.15),
      child: Icon(_statusIconData(status), size: 18, color: _statusColor(status)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.isEmpty ? '—' : label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'creditor': // طلبکار
      return Colors.orange.shade800;
    case 'debtor': // بدهکار
      return Colors.red.shade700;
    case 'paid': // تسویه شده
      return Colors.green.shade700;
    default:
      return Colors.grey.shade600;
  }
}

IconData _statusIconData(String status) {
  switch (status) {
    case 'creditor':
      return Icons.south_west;
    case 'debtor':
      return Icons.north_east;
    case 'paid':
      return Icons.check_circle_outline;
    default:
      return Icons.help_outline;
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'حساب ماهانه‌ای برای این کارگر ثبت نشده است.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
