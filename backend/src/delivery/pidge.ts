import { timingSafeEqual } from 'node:crypto';
import type { Config } from '../config.js';

// Pidge (pidge.in) last-mile delivery. The backend books a Pidge trip once the
// Zoho Sales Order is confirmed, and Pidge's status webhook moves the order
// through Shipped → Out for delivery → Delivered in the app.
//
// Endpoint paths and field names follow Pidge's vendor/channel API and are all
// overridable via PIDGE_* settings; confirm them against the API reference
// Pidge shares with your account before going live.

type FetchFn = typeof fetch;

export interface DeliveryParty {
  name: string;
  mobile: string;
  line: string;
  city?: string;
  state?: string;
  pincode?: string;
}

export interface DeliveryBooking {
  provider: 'pidge';
  deliveryId: string;
  status: DeliveryStatus;
  riderName?: string;
  riderMobile?: string;
  trackingUrl?: string;
  updatedAt: string;
}

export type DeliveryStatus = 'booked' | 'rider_assigned' | 'picked_up' | 'out_for_delivery' | 'delivered' | 'cancelled' | 'failed';

/** Normalises Pidge's status strings (e.g. "OUT_FOR_DELIVERY", "Delivered", "picked-up"). */
export function normaliseStatus(raw: unknown): DeliveryStatus | null {
  const s = String(raw ?? '').toLowerCase().replace(/[\s-]+/g, '_');
  if (!s) return null;
  if (s.includes('deliver') && !s.includes('out_for') && !s.includes('un') && !s.includes('fail')) return 'delivered';
  if (s.includes('out_for_delivery') || s.includes('ofd') || s.includes('reached_delivery')) return 'out_for_delivery';
  if (s.includes('picked') || s.includes('in_transit') || s.includes('reached_pickup')) return s.includes('reached_pickup') ? 'rider_assigned' : 'picked_up';
  if (s.includes('assign') || s.includes('accept') || s.includes('allot')) return 'rider_assigned';
  if (s.includes('cancel')) return 'cancelled';
  if (s.includes('fail') || s.includes('undeliver') || s.includes('rto')) return 'failed';
  if (s.includes('creat') || s.includes('pending') || s.includes('placed') || s.includes('book')) return 'booked';
  return null;
}

/** Order-tracking stage (index into STEPS) implied by a delivery status. */
export function stageForDelivery(status: DeliveryStatus): number | null {
  switch (status) {
    case 'rider_assigned':
      return 1;
    case 'picked_up':
      return 2;
    case 'out_for_delivery':
      return 3;
    case 'delivered':
      return 4;
    default:
      return null;
  }
}

export class PidgeError extends Error {}

export class PidgeClient {
  private token: string | null = null;
  private tokenAt = 0;

  constructor(
    private readonly cfg: Config['pidge'],
    private readonly fetchFn: FetchFn = fetch,
  ) {}

  get enabled() {
    return !!(this.cfg.username && this.cfg.password) || !!this.cfg.apiToken;
  }

  private async auth(): Promise<string> {
    if (this.cfg.apiToken) return this.cfg.apiToken;
    // Vendor tokens are long-lived; refresh every 12 hours.
    if (this.token && Date.now() - this.tokenAt < 12 * 3600_000) return this.token;
    const res = await this.fetchFn(this.cfg.baseUrl + this.cfg.loginPath, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: this.cfg.username, password: this.cfg.password }),
    });
    const body = (await res.json().catch(() => ({}))) as { data?: { token?: string }; token?: string; message?: string };
    const token = body.data?.token ?? body.token;
    if (!res.ok || !token) throw new PidgeError(`Pidge login failed: ${body.message ?? res.status}`);
    this.token = token;
    this.tokenAt = Date.now();
    return token;
  }

  private async call<T>(method: 'GET' | 'POST', path: string, body?: unknown, retried = false): Promise<T> {
    const res = await this.fetchFn(this.cfg.baseUrl + path, {
      method,
      headers: { Authorization: await this.auth(), 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    if (res.status === 401 && !retried && !this.cfg.apiToken) {
      this.token = null;
      return this.call(method, path, body, true);
    }
    const json = (await res.json().catch(() => ({}))) as { message?: string };
    if (!res.ok) throw new PidgeError(`Pidge ${path} failed: ${json.message ?? res.status}`);
    return json as T;
  }

  /** Books a pickup from the warehouse to the customer for a confirmed order. */
  async createOrder(o: {
    reference: string;
    drop: DeliveryParty;
    items: { name: string; qty: number; price: number }[];
    billAmount: number;
    codAmount: number;
    notes?: string;
  }): Promise<DeliveryBooking> {
    const pickup = this.cfg.pickup;
    const party = (p: DeliveryParty) => ({
      name: p.name,
      mobile: p.mobile,
      address: { address_line_1: p.line, city: p.city ?? '', state: p.state ?? '', pincode: p.pincode ?? '', country: 'India' },
    });
    const res = await this.call<{ data?: Record<string, unknown> | Record<string, unknown>[] }>('POST', this.cfg.createPath, {
      channel: this.cfg.channel,
      sender_detail: party(pickup),
      poc_detail: { name: pickup.name, mobile: pickup.mobile },
      trips: [
        {
          source_order_id: o.reference,
          reference_id: o.reference,
          receiver_detail: party(o.drop),
          packages: [{ label: o.reference, quantity: 1 }],
          products: o.items.map((i) => ({ name: i.name, quantity: i.qty, price: i.price })),
          bill_amount: o.billAmount,
          cod_amount: o.codAmount,
          notes: o.notes ?? '',
        },
      ],
    });
    const data = Array.isArray(res.data) ? res.data[0] : res.data;
    const id = String((data as Record<string, unknown> | undefined)?.id ?? (data as Record<string, unknown> | undefined)?.order_id ?? Object.values(data ?? {})[0] ?? '');
    if (!id) throw new PidgeError('Pidge did not return an order id');
    return { provider: 'pidge', deliveryId: id, status: 'booked', updatedAt: new Date().toISOString() };
  }

  /** Reads the current trip status (fallback when a webhook was missed). */
  async getStatus(deliveryId: string): Promise<Partial<DeliveryBooking>> {
    const res = await this.call<{ data?: Record<string, any> }>('GET', this.cfg.statusPath.replace(':id', encodeURIComponent(deliveryId)));
    return fromPidgePayload(res.data ?? {});
  }

  verifyWebhook(headerToken: string | undefined): boolean {
    const want = this.cfg.webhookToken;
    if (!want || !headerToken) return false;
    const a = Buffer.from(headerToken.replace(/^Bearer\s+/i, ''));
    const b = Buffer.from(want);
    return a.length === b.length && timingSafeEqual(a, b);
  }
}

/** Extracts status and rider details from a Pidge order/trip payload or webhook body. */
export function fromPidgePayload(p: Record<string, any>): Partial<DeliveryBooking> & { reference?: string; deliveryId?: string } {
  const trip = Array.isArray(p.trips) ? p.trips[0] ?? {} : p.trip ?? p;
  const rider = p.rider ?? trip.rider ?? p.fulfillment?.rider ?? {};
  const status = normaliseStatus(p.status ?? trip.status ?? p.fulfillment?.status ?? p.event);
  return {
    deliveryId: p.id ? String(p.id) : p.order_id ? String(p.order_id) : undefined,
    reference: trip.source_order_id ?? trip.reference_id ?? p.source_order_id ?? p.reference_id,
    ...(status ? { status } : {}),
    riderName: rider.name ?? undefined,
    riderMobile: rider.mobile ?? rider.phone ?? undefined,
    trackingUrl: p.tracking_url ?? trip.tracking_url ?? p.fulfillment?.track_url ?? undefined,
  };
}
