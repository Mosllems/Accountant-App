import django_jalali.admin as jadmin
from django.contrib import admin
from .models import Worker, MonthlySalary, MonthlyAccount, Payment


class MonthlySalaryInline(admin.TabularInline):
    model = MonthlySalary
    extra = 1
    fields = ["year", "month", "salary"]


class PaymentInline(admin.TabularInline):
    model = Payment
    extra = 1
    fields = ["amount", "date", "description"]


@admin.register(Worker)
class WorkerAdmin(admin.ModelAdmin):
    list_display = ["name", "start_date", "is_active", "created_at"]
    list_filter = ["is_active"]
    search_fields = ["name"]
    inlines = [MonthlySalaryInline]


@admin.register(MonthlySalary)
class MonthlySalaryAdmin(admin.ModelAdmin):
    list_display = ["worker", "year", "month", "salary"]
    list_filter = ["year", "month"]
    search_fields = ["worker__name"]


@admin.register(MonthlyAccount)
class MonthlyAccountAdmin(admin.ModelAdmin):
    list_display = [
        "get_worker",
        "get_year",
        "get_month",
        "display_eligible_days",
        "display_calculated_amount",
        "display_total_payments",
        "display_balance",
        "display_status",
        "settled_at",
    ]
    list_filter = ["settled_at"]
    search_fields = ["monthly_salary__worker__name"]
    inlines = [PaymentInline]
    readonly_fields = [
        "display_eligible_days",
        "display_calculated_amount",
        "display_total_payments",
        "display_balance",
        "display_status",
    ]

    @admin.display(description="کارگر")
    def get_worker(self, obj):
        return obj.monthly_salary.worker.name

    @admin.display(description="سال")
    def get_year(self, obj):
        return obj.monthly_salary.year

    @admin.display(description="ماه")
    def get_month(self, obj):
        return obj.monthly_salary.month

    @admin.display(description="روزهای مشمول")
    def display_eligible_days(self, obj):
        return obj.eligible_days

    @admin.display(description="حقوق نهایی")
    def display_calculated_amount(self, obj):
        return f"{obj.calculated_amount:,.0f} تومان"

    @admin.display(description="مجموع دریافتی")
    def display_total_payments(self, obj):
        return f"{obj.total_payments:,.0f} تومان"

    @admin.display(description="مانده")
    def display_balance(self, obj):
        return f"{obj.balance:,.0f} تومان"

    @admin.display(description="وضعیت")
    def display_status(self, obj):
        return obj.status_display


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ["get_worker", "amount", "date", "description", "created_at"]
    list_filter = ["date"]
    search_fields = ["monthly_account__monthly_salary__worker__name"]
    date_hierarchy = "date"

    @admin.display(description="کارگر")
    def get_worker(self, obj):
        return obj.monthly_account.monthly_salary.worker.name
