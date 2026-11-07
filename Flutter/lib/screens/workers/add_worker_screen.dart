import 'package:flutter/material.dart';

import '../../core/format/jalali.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/calendar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/page_header.dart';
import '../../core/widgets/state_views.dart';
import '../../services/api_client.dart';
import '../../services/app_scope.dart';

/// Add a worker via `POST /api/workers/` (real API).
/// The backend currently allows writes only for staff users
/// (BACKEND-GAP(write-access)); the app has no login by design, so until the
/// backend permission is changed the server rejects this with a clear message.
class AddWorkerScreen extends StatefulWidget {
  const AddWorkerScreen({super.key});

  @override
  State<AddWorkerScreen> createState() => _AddWorkerScreenState();
}

class _AddWorkerScreenState extends State<AddWorkerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  Jalali _startDate = Jalali.now();
  bool _isActive = true;
  bool _submitting = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _serverError(String field) => _fieldErrors[field]?.join('\n');

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await AppScope.of(context).createWorker(
        name: _nameController.text.trim(),
        startDate: _startDate,
        isActive: _isActive,
      );
      if (!mounted) return;
      showAppSnackBar(
        context,
        'کارگر با موفقیت ثبت شد.',
        type: FeedbackType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _fieldErrors = e.fieldErrors;
        _error = e.isAmbiguous
            ? 'نتیجه مشخص نیست؛ پیش از ثبت دوباره، فهرست کارگران را بررسی کنید.'
            : e.message;
      });
      showAppSnackBar(context, 'عملیات انجام نشد.', type: FeedbackType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('افزودن کارگر')),
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
                    const NoticeBanner(
                      message:
                          'سرور فعلاً اجازه‌ی ثبت اطلاعات از برنامه را نمی‌دهد. '
                          'پس از تنظیم دسترسی در بک‌اند، این فرم کار خواهد کرد.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.done,
                      maxLength: 255,
                      decoration: InputDecoration(
                        labelText: 'نام کارگر',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: _serverError('name'),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'نام را وارد کنید.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    JalaliDateField(
                      label: 'تاریخ شروع کار',
                      value: _startDate,
                      showTodayButton: true,
                      errorText: _serverError('start_date'),
                      onChanged: (d) =>
                          setState(() => _startDate = d ?? _startDate),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SwitchListTile(
                      value: _isActive,
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _isActive = v),
                      title: const Text('کارگر فعال است'),
                      activeThumbColor: AppColors.accent,
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      NoticeBanner(
                        message: _error!,
                        icon: Icons.error_outline,
                        color: AppColors.error,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'ثبت کارگر',
                      icon: Icons.check_rounded,
                      expand: true,
                      loading: _submitting,
                      onPressed: _submit,
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
