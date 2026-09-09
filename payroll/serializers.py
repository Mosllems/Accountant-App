from rest_framework import serializers

from .models import (Worker, MonthlySalary, MonthlyAccount, Payment)


class MonthlySalarySerializer(serializers.ModelSerializer):
    class Meta:
        model = MonthlySalary
        fields = [
            "id",
            "year",
            "month",
            "salary",
        ]
        read_only_fields = ["id"]

class MonthlyAccountShortSerializer(serializers.ModelSerializer):
    class Meta:
        model = MonthlyAccount
        fields = [
            "id",
            "status",
            "status_display",
            "balance",
        ]


class PaymentSerializer(serializers.ModelSerializer):
    monthly_account = MonthlyAccountShortSerializer(read_only=True)

    class Meta:
        model = Payment
        fields = [
            "id",
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

    payments = PaymentSerializer(
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
        return MonthlyAccountSerializer(accounts, many=True).data
