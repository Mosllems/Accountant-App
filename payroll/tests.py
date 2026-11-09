from unittest.mock import patch

import jdatetime
from django.test import TestCase
from rest_framework.pagination import PageNumberPagination
from rest_framework.test import APIClient

from .models import MonthlyAccount, MonthlySalary, Payment, Worker

def jdate(text):
    return jdatetime.datetime.strptime(text, "%Y-%m-%d").date()


# DRF reads PAGE_SIZE once at import time, so override_settings has no effect;
# pin the page size here so the tests don't depend on settings.py.
@patch.object(PageNumberPagination, "page_size", 2)
class PaymentListTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.ali = Worker.objects.create(name="علی رضایی", start_date=jdate("1405-01-01"))
        cls.matin = Worker.objects.create(name="متین", start_date=jdate("1405-01-01"))

        def account(worker, month):
            salary = MonthlySalary.objects.create(worker=worker, year=1405, month=month, salary=30_000_000)
            return MonthlyAccount.objects.create(monthly_salary=salary)

        ali_6 = account(cls.ali, 6)
        matin_6 = account(cls.matin, 6)

        def pay(acc, amount, date):
            return Payment.objects.create(monthly_account=acc, amount=amount, date=jdate(date))

        cls.p1 = pay(ali_6, 1_000_000, "1405-06-01")
        cls.p2 = pay(matin_6, 2_000_000, "1405-06-10")
        cls.p3 = pay(ali_6, 3_000_000, "1405-06-20")
        cls.p4 = pay(matin_6, 4_000_000, "1405-06-20")  # same date as p3 → id breaks the tie

    def setUp(self):
        self.client = APIClient()

    def get(self, **params):
        return self.client.get("/api/payments/", params)

    def ids(self, response):
        return [p["id"] for p in response.json()["results"]]

    def test_payload_has_worker_and_account_month(self):
        row = self.get(worker=self.ali.id).json()["results"][0]
        self.assertEqual(row["worker"], {"id": self.ali.id, "name": "علی رضایی"})
        self.assertEqual(row["monthly_account"]["year"], 1405)
        self.assertEqual(row["monthly_account"]["month"], 6)
        # money is a string like the other money fields, not a float
        self.assertIsInstance(row["monthly_account"]["balance"], str)

    def test_ordering_newest_date_then_id_across_pages(self):
        page1 = self.get()
        page2 = self.get(page=2)
        self.assertEqual(page1.json()["count"], 4)
        self.assertEqual(self.ids(page1) + self.ids(page2), [self.p4.id, self.p3.id, self.p2.id, self.p1.id])

    def test_search_by_worker_name(self):
        response = self.get(search="رضایی")
        self.assertEqual(response.json()["count"], 2)
        self.assertEqual(self.ids(response), [self.p3.id, self.p1.id])

    def test_filter_by_worker(self):
        response = self.get(worker=self.matin.id)
        self.assertEqual(self.ids(response), [self.p4.id, self.p2.id])

    def test_date_range_is_inclusive(self):
        response = self.get(date_from="1405-06-10", date_to="1405-06-20")
        self.assertEqual(response.json()["count"], 3)

    def test_filters_combine_with_pagination_count(self):
        response = self.get(worker=self.ali.id, date_from="1405-06-05")
        self.assertEqual(response.json()["count"], 1)
        self.assertEqual(self.ids(response), [self.p3.id])

    def test_invalid_params_return_400(self):
        for params in (
            {"worker": "abc"},
            {"worker": "4.5"},
            {"date_from": "1405/06/01"},
            {"date_to": "1405-13-01"},
            {"date_from": "1405-06-20", "date_to": "1405-06-01"},
        ):
            with self.subTest(params=params):
                self.assertEqual(self.get(**params).status_code, 400)

    def test_list_query_count_does_not_grow_with_rows(self):
        # count + payments (with joins) + prefetch of account payments
        with self.assertNumQueries(3):
            self.get()

    def test_error_messages_are_persian_field_errors(self):
        response = self.get(worker="abc")
        self.assertEqual(response.json(), {"worker": ["شناسه‌ی کارگر نامعتبر است."]})

    def test_nested_payments_in_worker_detail_do_not_repeat_account_or_worker(self):
        detail = self.client.get(f"/api/workers/{self.ali.id}/").json()
        payment = detail["monthly_accounts"][0]["payments"][0]
        self.assertEqual(set(payment), {"id", "amount", "date", "description"})

    def test_monthly_salary_and_account_lists_show_worker(self):
        salary = self.client.get("/api/monthly-salaries/").json()["results"][0]
        self.assertEqual(set(salary["worker"]), {"id", "name"})
        account = self.client.get("/api/monthly-accounts/").json()["results"][0]
        self.assertEqual(set(account["monthly_salary"]["worker"]), {"id", "name"})

    def test_worker_detail_does_not_repeat_worker_inside_salary(self):
        detail = self.client.get(f"/api/workers/{self.ali.id}/").json()
        salary = detail["monthly_accounts"][0]["monthly_salary"]
        self.assertEqual(set(salary), {"id", "year", "month", "salary"})

