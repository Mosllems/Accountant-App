from rest_framework import serializers

from .models import (Worker, MonthlySalary, MonthlyAccount, Payment)


class WorkerShortSerializer(serializers.ModelSerializer):
    class Meta:
        model = Worker
        fields = ["id", "name"]


class MonthlySalaryInWorkerSerializer(serializers.ModelSerializer):
    """حقوق ماهانه داخل جزئیات یک کارگر: کارگر را تکرار نمی‌کنیم."""

    class Meta:
        model = MonthlySalary
        fields = [
            "id",
            "year",
            "month",
            "salary",
        ]
        read_only_fields = ["id"]


class MonthlySalarySerializer(MonthlySalaryInWorkerSerializer):
    worker = WorkerShortSerializer(read_only=True)

    class Meta(MonthlySalaryInWorkerSerializer.Meta):
        fields = [
            "id",
            "worker",
            "year",
            "month",
            "salary",
        ]


class MonthlyAccountShortSerializer(serializers.ModelSerializer):
    year = serializers.IntegerField(source="monthly_salary.year", read_only=True)
    month = serializers.IntegerField(source="monthly_salary.month", read_only=True)
    status = serializers.CharField(read_only=True)
    status_display = serializers.CharField(read_only=True)
    balance = serializers.DecimalField(
        max_digits=10,
        decimal_places=0,
        read_only=True,
    )

    class Meta:
        model = MonthlyAccount
        fields = [
            "id",
            "year",
            "month",
            "status",
            "status_display",
            "balance",
        ]


class PaymentInAccountSerializer(serializers.ModelSerializer):
    """پرداخت داخل یک حساب ماهانه: فقط فیلدهای خود پرداخت."""

    class Meta:
        model = Payment
        fields = ["id", "amount", "date", "description"]


class PaymentSerializer(serializers.ModelSerializer):
    monthly_account = MonthlyAccountShortSerializer(read_only=True)
    # کارگرِ صاحب پرداخت: پرداخت ← حساب ماهانه ← حقوق ماهانه ← کارگر
    worker = WorkerShortSerializer(
        source="monthly_account.monthly_salary.worker",
        read_only=True,
    )

    class Meta:
        model = Payment
        fields = [
            "id",
            "worker",
            "monthly_account",
            "amount",
            "date",
            "description",
        ]
        read_only_fields = ["id"]
        
class MonthlyAccountSerializer(serializers.ModelSerializer):
    monthly_salary = MonthlySalarySerializer(read_only=True)
    
    # چون در مدلمان ما پراپرتی داریم که در دیتابیس ذخیره نمیشوند ما باید برای این پراپرتی ها یک فیلد درست کنیم تا در سریالایزر نمایش داده شوند
    eligible_days = serializers.IntegerField(read_only=True)
    
    daily_salary = serializers.DecimalField(
        max_digits=10,
        decimal_places=0,
        read_only=True,
    )

    calculated_amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=0,
        read_only=True,
    )

    total_payments = serializers.DecimalField(
        max_digits=10,
        decimal_places=0,
        read_only=True,
    )

    balance = serializers.DecimalField(
        max_digits=10,
        decimal_places=0,
        read_only=True,
    )

    status = serializers.CharField(read_only=True)
    status_display = serializers.CharField(read_only=True)

    # پرداخت‌ها داخل همین حساب‌اند؛ پس حساب و کارگر را دوباره تکرار نمی‌کنیم
    payments = PaymentInAccountSerializer(
        many=True,
        read_only=True,
    )

    class Meta:
        model = MonthlyAccount
        fields = [
            "id",
            "monthly_salary",
            "eligible_days",
            "daily_salary",
            "calculated_amount",
            "total_payments",
            "balance",
            "status",
            "status_display",
            "settled_at",
            "payments",
        ]
        read_only_fields = [
            "id",
            "monthly_salary",
            "eligible_days",
            "daily_salary",
            "calculated_amount",
            "total_payments",
            "balance",
            "status",
            "status_display",
            "payments",
            "settled_at",
        ]


class MonthlyAccountInWorkerSerializer(MonthlyAccountSerializer):
    """حساب ماهانه داخل جزئیات یک کارگر: حقوقش بدون کارگر نمایش داده می‌شود."""

    monthly_salary = MonthlySalaryInWorkerSerializer(read_only=True)


class WorkerListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Worker
        fields = [
            "id",
            "name",
            "start_date",
            "is_active",
        ]
        read_only_fields = ["id"]


class WorkerDetailSerializer(serializers.ModelSerializer):
    monthly_accounts = serializers.SerializerMethodField()

    class Meta:
        model = Worker
        fields = [
            "id",
            "name",
            "start_date",
            "is_active",
            "monthly_accounts",
        ]
        read_only_fields = ["id"]

    def get_monthly_accounts(self, obj):
        accounts = (MonthlyAccount.objects
            .filter(monthly_salary__worker=obj)
            .select_related("monthly_salary", "monthly_salary__worker")
            .prefetch_related("payments")
        )
        return MonthlyAccountInWorkerSerializer(accounts, many=True).data
