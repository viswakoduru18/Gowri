import { createHmac, timingSafeEqual } from 'node:crypto';
import type { ZohoClient } from './client.js';

// Zoho Payments (India). Flow:
//   1. Backend creates a payment session for the order amount.
//   2. The app opens /pay/:orderId, which loads Zoho's checkout widget with the
//      session id; the customer pays by UPI / card / wallet / net banking.
//   3. The widget returns a payment_id; the page redirects to /pay/:orderId/return.
//   4. Backend re-reads the payment from Zoho (never trusts the client) and
//      confirms the Sales Order. The webhook does the same if the app is closed.

export interface PaymentSession {
  payments_session_id: string;
  amount: string;
  currency: string;
}

export interface ZohoPayment {
  payment_id: string;
  payments_session_id?: string;
  status: string; // succeeded | failed | pending ...
  amount: string;
  currency: string;
  payment_method?: { type?: string };
  reference_number?: string;
}

export class PaymentsApi {
  constructor(
    private readonly zoho: ZohoClient,
    readonly accountId: string,
  ) {}

  async createSession(amountInr: number, description: string, referenceNumber: string): Promise<PaymentSession> {
    const res = await this.zoho.request<{ payments_session: PaymentSession }>('/api/v1/paymentsessions', {
      method: 'POST',
      body: {
        amount: amountInr.toFixed(2),
        currency: 'INR',
        description,
        invoice_number: referenceNumber,
        meta_data: [{ key: 'order_ref', value: referenceNumber }],
      },
    });
    return res.payments_session;
  }

  async getPayment(paymentId: string): Promise<ZohoPayment> {
    return (await this.zoho.request<{ payment: ZohoPayment }>(`/api/v1/payments/${paymentId}`)).payment;
  }
}

/**
 * Verifies a Zoho Payments webhook signature (HMAC-SHA256 of the raw body with
 * the webhook signing key). Confirm the header name and format against your
 * webhook settings; it is read from `x-zoho-webhook-signature` by default.
 */
export function verifyWebhookSignature(rawBody: Buffer, signature: string | undefined, secret: string): boolean {
  if (!secret || !signature) return false;
  const expected = createHmac('sha256', secret).update(rawBody).digest('hex');
  const provided = signature.replace(/^sha256=/, '').trim();
  if (provided.length !== expected.length) return false;
  return timingSafeEqual(Buffer.from(provided), Buffer.from(expected));
}

export const isPaymentSuccessful = (p: Pick<ZohoPayment, 'status'>) => p.status.toLowerCase() === 'succeeded';
