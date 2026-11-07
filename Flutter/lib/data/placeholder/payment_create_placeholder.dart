// BACKEND-GAP(payment-create): POST /api/payments/ cannot create a payment.
//   - PaymentSerializer.monthly_account is read_only → the FK can't be set.
//   - Writes are limited to staff users on the backend (BACKEND-GAP(write-access));
//     the app intentionally has no login (single owner).
// Until the backend supports it, the register-payment form runs in demo
// mode: nothing is sent or saved, and the UI says so explicitly.
//
// To switch to the real API: set [kPaymentCreateSupportedByBackend] to true.
// The real request is already implemented in ApiClient.createPayment and
// PayrollRepository.createPayment — no UI change is needed.

/// Whether the backend can create payments.
const bool kPaymentCreateSupportedByBackend = false;

/// Simulated latency for the demo submission (keeps the real UX flow).
Future<void> simulatePaymentCreate() =>
    Future<void>.delayed(const Duration(milliseconds: 700));
