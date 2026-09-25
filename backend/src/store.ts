import type { DeliveryBooking } from './delivery/pidge.js';
import type { Customer, PaymentMethod } from './types.js';

// Small key-value state the backend owns (Zoho remains the system of record for
// products, customers and orders). In-memory is fine for a single instance;
// swap for Redis/Postgres before running more than one replica.

export interface PendingPayment {
  orderRef: string;
  salesOrderId: string;
  sessionId: string;
  amount: number;
  method: PaymentMethod;
  customerId: string;
  settled: boolean;
}

export interface OtpEntry {
  code: string;
  expiresAt: number;
  attempts: number;
}

export class Store {
  otps = new Map<string, OtpEntry>();
  customersByPhone = new Map<string, Customer>();
  wishlists = new Map<string, string[]>();
  payments = new Map<string, PendingPayment>();
  /** Delivery bookings by Zoho salesorder_id. */
  deliveries = new Map<string, DeliveryBooking & { reference: string }>();
  private seq = 0;

  nextOrderRef(): string {
    // Time-based so refs stay unique across restarts; readable like the design's GW-10432.
    this.seq = (this.seq + 1) % 100;
    const n = Math.floor(Date.now() / 1000) % 10_000_000;
    return `GW-${n}${String(this.seq).padStart(2, '0')}`;
  }
}
