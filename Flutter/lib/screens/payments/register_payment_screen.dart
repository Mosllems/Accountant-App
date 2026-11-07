import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format/amount_input_formatter.dart';
import '../../core/format/jalali.dart';
import '../../core/format/money.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/calendar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/placeholder/payment_create_placeholder.dart';
import '../../models/worker.dart';
import '../../services/api_client.dart';
import '../../services/app_scope.dart';
import '../../services/payroll_repository.dart';

/// Register a payment for [worker] (independent page, section-based form).
class RegisterPaymentScreen extends StatefulWidget {
  const RegisterPaymentScreen({super.key, required this.worker});

  final WorkerDetail worker;

  @override
  State<RegisterPaymentScreen> createState() => _RegisterPaymentScreenState();
}

class _RegisterPaymentScreenState extends State<RegisterPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  Jalali _date = Jalali.now();

  bool _submitting = false;
  String? _submitError;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onChanged);
    _descriptionController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  /// The payment belongs to the worker's account of the payment date's month.
  /// (Assumption — see BACKEND-GAP(payment-account) in backend-gaps.md.)
  MonthlyAccount? get _account => widget.worker.accountFor(YearMonth.of(_date));

  String? get _normalizedAmount => normalizeAmountInput(_amountController.text);

  String? get _description {
    final text = _descriptionController.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitError = null;
      _fieldErrors = const {};
    });
    if (!_formKey.currentState!.validate()) return;
    final account = _account;
    if (account == null) return;

    setState(() => _submitting = true);
    final repo = AppScope.of(context);
    try {
      final outcome = await repo.createPayment(
        account: account,
        amount: _normalizedAmount!,
        date: _date,
        description: _description,
      );
      if (!mounted) return;
      switch (outcome) {
        case PaymentCreateOutcome.saved:
          showAppSnackBar(
            context,
            'پرداخت با موفقیت ثبت شد.',
            type: FeedbackType.success,
          );
          await Future<void>.delayed(const Duration(milliseconds: 700));
          if (mounted) Navigator.of(context).pop();
        case PaymentCreateOutcome.demoNotSaved:
          setState(() => _submitting = false);
          showAppSnackBar(context, 'حالت آزمایشی: پرداخت در سرور ذخیره نشد.');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _fieldErrors = e.fieldErrors;
        _submitError = e.isAmbiguous
            ? 'نتیجه‌ی ثبت مشخص نیست؛ ممکن است پرداخت ذخیره شده باشد. '
                  'پیش از ثبت دوباره، فهرست پرداخت‌ها را بررسی کنید.'
            : e.message;
      });
      showAppSnackBar(context, 'عملیات انجام نشد.', type: FeedbackType.error);
    }
  }

  String? _serverError(String field) {
    final list = _fieldErrors[field];
    return (list == null || list.isEmpty) ? null : list.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final amount = _normalizedAmount;
    return Scaffold(
      appBar: AppBar(title: const Text('ثبت پرداخت')),
      body: PopScope(
        canPop: !_submitting,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!kPaymentCreateSupportedByBackend) ...[
                      const NoticeBanner(
                        icon: Icons.science_outlined,
                        message:
                            'حالت آزمایشی: سرور هنوز امکان ثبت پرداخت را ندارد. '
                            'فرم کامل کار می‌کند اما اطلاعات ذخیره نمی‌شود.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _WorkerSummary(worker: widget.worker, account: account),
                    const SizedBox(height: AppSpacing.sectionGap),
                    const SectionTitle('اطلاعات پرداخت'),
                    TextFormField(
                      controller: _amountController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        const AmountInputFormatter(),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      style: AppText.amountSmall,
                      decoration: InputDecoration(
                        labelText: 'مبلغ',
                        hintText: 'مثلاً ۵٬۰۰۰٬۰۰۰',
                        suffixText: currencyUnit,
                        errorText: _serverError('amount'),
                        prefixIcon: _amountController.text.isEmpty
                            ? const Icon(Icons.payments_outlined)
                            : IconButton(
                                tooltip: 'پاک کردن مبلغ',
                                icon: const Icon(Icons.close),
                                onPressed: _amountController.clear,
                              ),
                      ),
                      validator: validateAmountInput,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    JalaliDateField(
                      label: 'تاریخ پرداخت',
                      value: _date,
                      showTodayButton: true,
                      errorText:
                          _serverError('date') ??
                          (account == null
                              ? 'برای ${YearMonth.of(_date).label} حساب ماهانه‌ای برای این کارگر ثبت نشده است.'
                              : null),
                      onChanged: _submitting
                          ? (_) {}
                          : (d) => setState(() => _date = d ?? _date),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    const SectionTitle('توضیحات'),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_submitting,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'اختیاری',
                        errorText: _serverError('description'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sectionGap),
                    const SectionTitle('پیش‌نمایش'),
                    AppCard(
                      child: Column(
                        children: [
                          InfoRow(label: 'کارگر', value: widget.worker.name),
                          InfoRow(
                            label: 'مبلغ',
                            value: amount == null
                                ? missingValue
                                : formatMoney(int.tryParse(amount) ?? amount),
                            emphasize: true,
                          ),
                          InfoRow(label: 'تاریخ', value: formatDateLong(_date)),
                          InfoRow(
                            label: 'بابت حساب ماه',
                            value: account?.yearMonth?.label ?? missingValue,
                          ),
                          if (_description != null)
                            InfoRow(label: 'توضیحات', value: _description!),
                        ],
                      ),
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      NoticeBanner(
                        message: _submitError!,
                        icon: Icons.error_outline,
                        color: AppColors.error,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'ثبت پرداخت',
                      icon: Icons.check_rounded,
                      expand: true,
                      loading: _submitting,
                      onPressed: account == null ? null : _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerSummary extends StatelessWidget {
  const _WorkerSummary({required this.worker, required this.account});

  final WorkerDetail worker;
  final MonthlyAccount? account;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const LeadingIcon(Icons.person_outline, color: AppColors.navy),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.name, style: AppText.cardTitle),
                Text(
                  account == null
                      ? 'حسابی برای ماه تاریخ پرداخت وجود ندارد'
                      : 'مانده‌ی ${account!.yearMonth?.label ?? ''}: ${formatMoneyAbs(account!.balance)}',
                  style: AppText.secondary,
                ),
              ],
            ),
          ),
          if (account != null)
            StatusBadge(status: account!.status, label: account!.statusLabel),
        ],
      ),
    );
  }
}
