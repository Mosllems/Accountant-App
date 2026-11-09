from django.shortcuts import render

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter
from rest_framework.viewsets import ModelViewSet
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny

from .models import Worker, MonthlySalary, MonthlyAccount, Payment
from .serializers import WorkerListSerializer, WorkerDetailSerializer, MonthlySalarySerializer, MonthlyAccountSerializer, PaymentSerializer
from .filters import PaymentFilter
from .permissions import IsAdminOrReadOnly

class PaymentViewSet(ModelViewSet):
    queryset = Payment.objects.select_related(
        "monthly_account__monthly_salary__worker"
    ).prefetch_related("monthly_account__payments").order_by("-date", "-id")
    serializer_class = PaymentSerializer
    permission_classes = [IsAdminOrReadOnly]
    filter_backends = [SearchFilter, DjangoFilterBackend]
    filterset_class = PaymentFilter
    search_fields = ["monthly_account__monthly_salary__worker__name"]


class MonthlySalaryViewSet(ModelViewSet):
    queryset = MonthlySalary.objects.select_related("worker").all()
    serializer_class = MonthlySalarySerializer
    permission_classes = [IsAdminOrReadOnly]
    

class MonthlyAccountViewSet(ModelViewSet):
    queryset = MonthlyAccount.objects.select_related("monthly_salary__worker").prefetch_related("payments").all() # چون در سریالایزر ما به خود کارگر را نمایش میدهیم و به آن نیاز داریم باید در این قسمت آن را 
    serializer_class = MonthlyAccountSerializer
    permission_classes = [IsAdminOrReadOnly]
    
class WorkerViewSet(ModelViewSet):
    queryset = Worker.objects.all()
    permission_classes = [IsAdminOrReadOnly]
    
    def get_serializer_class(self):
        if self.action == "retrieve":
            return WorkerDetailSerializer
        return WorkerListSerializer
