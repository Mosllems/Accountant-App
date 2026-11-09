import django_filters
from django import forms
from django_jalali.forms import jDateField as JalaliDateFormField
from rest_framework.exceptions import ValidationError

from .models import Payment


class JalaliDateFilter(django_filters.Filter):
    """
    فیلتر تاریخ شمسی (YYYY-MM-DD).

    DateFilter خود django-filter تاریخ را میلادی می‌خواند؛ یعنی 1405-06-01
    را سال ۱۴۰۵ میلادی حساب می‌کند و مقایسه غلط می‌شود. اینجا از فیلد فرم
    django_jalali استفاده می‌کنیم که خروجی‌اش jdatetime.date است.
    """

    field_class = JalaliDateFormField


class IntegerFilter(django_filters.NumberFilter):
    """NumberFilter پیش‌فرض اعشار را هم می‌پذیرد (4.5)؛ شناسه باید عدد صحیح باشد."""

    field_class = forms.IntegerField


class PaymentFilter(django_filters.FilterSet):
    worker = IntegerFilter(
        field_name="monthly_account__monthly_salary__worker",
        label = "شناسه کارگر",
        error_messages={"invalid": "شناسه‌ی کارگر نامعتبر است."},
    )
    date_from = JalaliDateFilter(
        field_name="date",
        label = "از تاریخ",
        lookup_expr="gte",
        error_messages={"invalid": "تاریخ باید به شکل YYYY-MM-DD (شمسی) باشد."},
    )
    date_to = JalaliDateFilter(
        field_name="date",
        label = "تا تاریخ",
        lookup_expr="lte",
        error_messages={"invalid": "تاریخ باید به شکل YYYY-MM-DD (شمسی) باشد."},
    )

    class Meta:
        model = Payment
        fields = ["worker", "date_from", "date_to"]

    def filter_queryset(self, queryset):
        date_from = self.form.cleaned_data.get("date_from")
        date_to = self.form.cleaned_data.get("date_to")
        if date_from and date_to and date_from > date_to:
            raise ValidationError(
                {"date_from": ["تاریخ شروع نباید بعد از تاریخ پایان باشد."]}
            )
        return super().filter_queryset(queryset)
