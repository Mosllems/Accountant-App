from decimal import Decimal

from django.db import models
from django.db.models import Sum

from django_jalali.db import models as jmodels


class Worker(models.Model):
    name = models.CharField("نام", max_length=255)
    start_date = jmodels.jDateField("تاریخ شروع کار")
    is_active = models.BooleanField("فعال", default=True)
    created_at = jmodels.jDateTimeField("تاریخ ایجاد", auto_now_add=True)
    updated_at = jmodels.jDateTimeField("تاریخ بروزرسانی", auto_now=True)

    class Meta:
        verbose_name = "کارگر"
        verbose_name_plural = "کارگران"
        ordering = ["-created_at"]

    def __str__(self):
        return self.name


class MonthlySalary(models.Model):
    worker = models.ForeignKey(Worker, on_delete=models.CASCADE, verbose_name="کارگر", related_name="monthly_salaries")
    year = models.PositiveIntegerField("سال")
    month = models.PositiveIntegerField("ماه")
    salary = models.DecimalField("حقوق ماهانه", max_digits=10, decimal_places=0)

    created_at = models.DateTimeField("تاریخ ایجاد", auto_now_add=True)
    updated_at = models.DateTimeField("تاریخ بروزرسانی", auto_now=True)

    class Meta:
        verbose_name = "حقوق ماهانه"
        verbose_name_plural = "حقوق ماهانه"
        unique_together = ["worker", "year", "month"]
        ordering = ["-year", "-month"]

    def __str__(self):
        return f"{self.worker.name} - {self.year} - {self.month}"



class MonthlyAccount(models.Model):

    class Status(models.TextChoices):
        CREDITOR = "creditor", "طلبکار"
        DEBTOR = "debtor", "بدهکار"
        PAID = "paid", "تسویه شده"

    monthly_salary = models.OneToOneField(MonthlySalary,on_delete=models.CASCADE,verbose_name="حقوق ماهانه",related_name="monthly_account")
    settled_at = jmodels.jDateTimeField("تاریخ تسویه",null=True,blank=True)
    created_at = models.DateTimeField("تاریخ ایجاد",auto_now_add=True)
    updated_at = models.DateTimeField("تاریخ بروزرسانی",auto_now=True)

    class Meta:
        verbose_name = "حساب ماهانه"
        verbose_name_plural = "حساب های ماهانه"

    def __str__(self):
        return (
            f"{self.monthly_salary.worker.name} - "
            f"{self.monthly_salary.year} - "
            f"{self.monthly_salary.month}"
        )

    @property
    def eligible_days(self):
        """محاسبه روز های مشمول حقوق"""

        worker_start_date = self.monthly_salary.worker.start_date

        salary_year = self.monthly_salary.year
        salary_month = self.monthly_salary.month

        # کارگر هنوز در این ماه شروع به کار نکرده
        if (
            worker_start_date.year > salary_year
            or (
                worker_start_date.year == salary_year
                and worker_start_date.month > salary_month
            )
        ):
            return 0

        # کارگر قبل از این ماه شروع کرده
        if (
            worker_start_date.year < salary_year
            or (
                worker_start_date.year == salary_year
                and worker_start_date.month < salary_month
            )
        ):
            return 30

        # شروع کار در همین ماه
        days = 31 - worker_start_date.day

        return min(days, 30)

    @property
    def daily_salary(self):
        """
        حقوق روزانه
        """
        return self.monthly_salary.salary / Decimal("30")

    @property
    def calculated_amount(self):
        """
        مبلغ محاسبه شده
        """
        return self.daily_salary * self.eligible_days

    @property
    def total_payments(self):
        """
        مبلغ کل پرداختی
        """
        # اگر payments قبلاً prefetch شده، بدون کوئری جدید از حافظه جمع می‌زنیم
        if "payments" in getattr(self, "_prefetched_objects_cache", {}):
            return sum((p.amount for p in self.payments.all()), Decimal("0"))
        # کش روی آبجکت: چون balance و status و status_display
        # چند بار پشت سر هم total_payments را صدا می‌زنند
        if hasattr(self, "_total_payments_cache"):
            return self._total_payments_cache
        total = self.payments.aggregate(total=Sum("amount"))["total"] or Decimal("0")
        self._total_payments_cache = total
        return total

    @property
    def balance(self):
        """
        مانده
        """
        return self.calculated_amount - self.total_payments

    @property
    def status(self):
        """
        وضعیت
        """
        bal = self.balance
        if bal > 0:
            return self.Status.CREDITOR

        if bal < 0:
            return self.Status.DEBTOR

        return self.Status.PAID

    @property
    def status_display(self):
        return self.Status(self.status).label

class Payment(models.Model):
    monthly_account = models.ForeignKey(MonthlyAccount,on_delete=models.CASCADE,verbose_name="حساب ماهانه",related_name="payments")
    amount = models.DecimalField("مبلغ",max_digits=12,decimal_places=0)
    date = jmodels.jDateField("تاریخ دریافتی")
    description = models.TextField("توضیحات", blank=True, null=True)
    created_at = models.DateTimeField("تاریخ ایجاد", auto_now_add=True)
    updated_at = models.DateTimeField("تاریخ بروزرسانی", auto_now=True)

    class Meta:
        verbose_name = "پرداخت"
        verbose_name_plural = "پرداخت ها"
        ordering = ["-created_at"]

    def __str__(self):
        return (
            f"{self.monthly_account.monthly_salary.worker.name} - "
            f"{self.amount} - "
            f"{self.date}"
        )
