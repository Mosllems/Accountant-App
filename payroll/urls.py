from . import views
from rest_framework.routers import DefaultRouter

router = DefaultRouter()

router.register("payments", views.PaymentViewSet, basename="payment")
router.register("monthly-salaries", views.MonthlySalaryViewSet, basename="monthly-salary")
router.register("monthly-accounts", views.MonthlyAccountViewSet, basename="monthly-account")
router.register("workers", views.WorkerViewSet, basename="worker")


urlpatterns = router.urls
