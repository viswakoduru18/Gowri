import { readFileSync } from 'node:fs';
import type { Config } from '../config.js';
import type { Store } from '../store.js';
import type { Address, CartLine, Customer, Order, PaymentMethod, Product } from '../types.js';
import { fromPidgePayload, PidgeClient, type DeliveryBooking } from '../delivery/pidge.js';
import type { InventoryApi, ZohoAddress, ZohoSalesOrder } from '../zoho/inventory.js';
import { isPaymentSuccessful, type PaymentsApi } from '../zoho/payments.js';
import type { Catalog } from './catalog.js';
import { ZohoError } from '../zoho/client.js';
import { stateCode } from './india.js';
import { toOrder } from './orders.js';
import { PricingError, couponProblem, quote, type CouponRule } from './pricing.js';

export const PAYMENT_LABELS: Record<PaymentMethod, string> = {
  upi: 'UPI',
  card: 'Card',
  wallet: 'Wallet',
  netbanking: 'Net banking',
  cod: 'Cash on delivery',
};

export class CommerceError extends Error {
  constructor(
    message: string,
    readonly status = 400,
  ) {
    super(message);
  }
}

export function loadCoupons(path = new URL('../../config/coupons.json', import.meta.url)): CouponRule[] {
  return JSON.parse(readFileSync(path, 'utf8'));
}

const today = () => new Date().toISOString().slice(0, 10);

function addressLine(a: ZohoAddress): string {
  return [a.address, a.street2, a.city, [a.state, a.zip].filter(Boolean).join(' ')].filter(Boolean).join(', ');
}

/** Orchestrates catalog, pricing, Zoho Sales Orders and Zoho Payments for the app. */
export class Commerce {
  constructor(
    private readonly cfg: Config,
    private readonly store: Store,
    readonly catalog: Catalog,
    private readonly inventory: InventoryApi,
    private readonly payments: PaymentsApi,
    readonly coupons: CouponRule[],
    private readonly delivery: PidgeClient | null = null,
  ) {}

  // ── Customers ─────────────────────────────────────────────────────

  async signIn(phone: string): Promise<Customer> {
    const cached = this.store.customersByPhone.get(phone);
    if (cached) return cached;
    const contact = (await this.inventory.findContactByPhone(phone)) ?? (await this.inventory.createContact('', phone));
    const customer: Customer = {
      id: contact.contact_id,
      contactId: contact.contact_id,
      name: contact.contact_name,
      email: contact.email ?? '',
      phone,
      memberSince: (contact.created_time ?? today()).slice(0, 4),
    };
    this.store.customersByPhone.set(phone, customer);
    return customer;
  }

  /** Saves the customer's name and email on their Zoho contact. */
  async updateProfile(customer: Customer, p: { name: string; email?: string }): Promise<Customer> {
    const name = p.name.trim().replace(/\s+/g, ' ');
    const [first, ...rest] = name.split(' ');
    await this.inventory.updateContact(customer.contactId, { contact_name: name, gst_treatment: 'consumer' });
    try {
      await this.inventory.upsertPrimaryPerson(customer.contactId, { first_name: first, last_name: rest.join(' '), email: p.email || undefined, mobile: customer.phone });
    } catch (e) {
      console.warn(`[profile] contact person update failed for ${customer.contactId}: ${(e as Error).message}`);
    }
    await this.ensureBilling(customer.contactId);
    const updated = { ...customer, name, email: p.email ?? customer.email };
    this.store.customersByPhone.set(customer.phone, updated);
    return updated;
  }

  async addresses(contactId: string): Promise<Address[]> {
    const list = await this.inventory.listContactAddresses(contactId);
    return list.map((a, i) => ({ id: a.address_id ?? String(i), label: a.attention || (i === 0 ? 'Home' : `Address ${i + 1}`), line: addressLine(a), pincode: a.zip, state: a.state }));
  }

  async addAddress(contactId: string, a: { label: string; line1: string; line2?: string; city: string; state: string; pincode: string }): Promise<Address> {
    const saved = await this.inventory.addContactAddress(contactId, {
      attention: a.label,
      address: a.line1,
      street2: a.line2,
      city: a.city,
      state: a.state,
      zip: a.pincode,
      country: 'India',
    });
    await this.ensureBilling(contactId, { attention: a.label, address: a.line1, street2: a.line2, city: a.city, state: a.state, zip: a.pincode, country: 'India' });
    return { id: saved.address_id ?? '', label: a.label, line: addressLine(saved), pincode: a.pincode, state: a.state };
  }

  /**
   * Invoices need a billing address, GST treatment and place of supply on the
   * contact. Fills them from `addr` (or the first saved address) when missing.
   * Never throws.
   */
  private async ensureBilling(contactId: string, addr?: ZohoAddress): Promise<void> {
    try {
      const contact = await this.inventory.getContact(contactId);
      if (contact.billing_address?.address) return;
      const src = addr ?? (await this.inventory.listContactAddresses(contactId))[0];
      if (!src?.address) return;
      const { address_id: _id, ...billing } = src;
      const code = stateCode(billing.state);
      await this.withoutOptional(
        (extra) => this.inventory.updateContact(contactId, { billing_address: billing, gst_treatment: 'consumer', ...extra }),
        code ? { place_of_contact: code } : {},
      );
    } catch (e) {
      console.warn(`[billing] could not set billing address on ${contactId}: ${(e as Error).message}`);
    }
  }

  /** Runs a Zoho write with optional GST fields; if Zoho rejects them, retries without. */
  private async withoutOptional<T>(write: (extra: Record<string, unknown>) => Promise<T>, extra: Record<string, unknown>): Promise<T> {
    try {
      return await write(extra);
    } catch (e) {
      if (!(e instanceof ZohoError) || !Object.keys(extra).length) throw e;
      console.warn(`[zoho] retrying without ${Object.keys(extra).join(', ')}: ${e.message}`);
      return write({});
    }
  }

  // ── Pricing ───────────────────────────────────────────────────────

  findCoupon(code?: string | null): CouponRule | null {
    if (!code) return null;
    return this.coupons.find((c) => c.code === code.trim().toUpperCase()) ?? null;
  }

  async quote(lines: CartLine[], couponCode: string | null | undefined, payment: PaymentMethod | undefined, contactId: string) {
    const catalog = await this.catalog.all();
    const coupon = this.findCoupon(couponCode);
    const isFirstOrder = coupon?.firstOrderOnly ? (await this.inventory.listSalesOrders(contactId)).length === 0 : true;
    const totals = quote(lines, catalog, { coupon, payment, isFirstOrder });
    const sell = totals.items.reduce((a, i) => a + i.lineTotal, 0);
    const couponMessage = couponCode
      ? !coupon
        ? "Hmm, that code isn't valid."
        : (couponProblem(coupon, sell, isFirstOrder) ?? `${coupon.code} applied. Nice.`)
      : null;
    return { totals, couponMessage, couponApplied: !!totals.couponCode };
  }

  // ── Orders ────────────────────────────────────────────────────────

  async placeOrder(customer: Customer, input: { items: CartLine[]; couponCode?: string | null; addressId?: string; payment: PaymentMethod }) {
    if (!input.items.length) throw new CommerceError('Your bag is empty.');
    // Re-read stock and price from Zoho for exactly what is being bought.
    const fresh = await this.catalog.fresh(input.items.map((i) => i.sku));
    for (const line of input.items) {
      const p = fresh.get(line.sku);
      if (!p) throw new CommerceError(`${line.sku} is no longer available.`, 409);
      if (p.stock < line.qty) throw new CommerceError(p.stock ? `Only ${p.stock} of ${p.name} left.` : `${p.name} just sold out.`, 409);
    }
    const coupon = this.findCoupon(input.couponCode);
    const isFirstOrder = coupon?.firstOrderOnly ? (await this.inventory.listSalesOrders(customer.contactId)).length === 0 : true;
    let totals;
    try {
      totals = quote(input.items, fresh, { coupon, payment: input.payment, isFirstOrder });
    } catch (e) {
      if (e instanceof PricingError) throw new CommerceError(e.message, 409);
      throw e;
    }

    const ref = this.store.nextOrderRef();
    const method = PAYMENT_LABELS[input.payment];
    const addresses = input.addressId ? await this.addresses(customer.contactId).catch(() => []) : [];
    const pos = stateCode(addresses.find((a) => a.id === input.addressId)?.state);
    const so = await this.withoutOptional((extra) => this.inventory.createSalesOrder({
      ...extra,
      customer_id: customer.contactId,
      reference_number: ref,
      date: today(),
      is_inclusive_tax: true,
      line_items: totals.items.map((i) => ({ item_id: (fresh.get(i.sku) as Product).itemId, quantity: i.qty, rate: i.price })),
      ...(totals.coupon ? { discount: totals.coupon, discount_type: 'entity_level' as const, is_discount_before_tax: true } : {}),
      shipping_charge: totals.shipping,
      ...(totals.codFee ? { adjustment: totals.codFee, adjustment_description: 'COD handling' } : {}),
      shipping_address_id: input.addressId,
      billing_address_id: input.addressId,
      notes: `Gowri app order ${ref}\nPayment: ${method}${totals.couponCode ? `\nCoupon: ${totals.couponCode}` : ''}`,
    }), { gst_treatment: 'consumer', ...(pos ? { place_of_supply: pos } : {}) });
    if (Math.abs(so.total - totals.total) > 1) {
      console.warn(`[order ${ref}] Zoho total ₹${so.total} differs from app quote ₹${totals.total}; check tax/shipping settings in Zoho.`);
    }
    this.catalog.invalidate();

    if (input.payment === 'cod') {
      // COD: confirm now so stock is committed and the warehouse can pack.
      await this.inventory.markSalesOrder(so.salesorder_id, 'confirmed');
      await this.bookDelivery(so.salesorder_id, customer.phone);
      return { order: await this.order(customer.contactId, so.salesorder_id), payUrl: null };
    }
    const payUrl = await this.startPayment(customer, so.salesorder_id, ref, totals.total, input.payment);
    return { order: toOrder(so, await this.catalog.all()), payUrl };
  }

  /** Creates (or re-creates after a failed attempt) a Zoho Payments session for a draft order. */
  async startPayment(customer: Customer, salesOrderId: string, ref: string, amount: number, method: PaymentMethod): Promise<string> {
    const session = await this.payments.createSession(amount, `Gowri order ${ref}`, ref);
    this.store.payments.set(salesOrderId, {
      orderRef: ref,
      salesOrderId,
      sessionId: session.payments_session_id,
      amount,
      method,
      customerId: customer.contactId,
      settled: false,
    });
    return `${this.cfg.publicBaseUrl}/pay/${salesOrderId}`;
  }

  async retryPayment(customer: Customer, salesOrderId: string): Promise<string> {
    const so = await this.ownedSalesOrder(customer.contactId, salesOrderId);
    if (so.status !== 'draft') throw new CommerceError('This order is already paid.', 409);
    const prev = this.store.payments.get(salesOrderId);
    return this.startPayment(customer, salesOrderId, so.reference_number ?? so.salesorder_number, so.total, prev?.method ?? 'upi');
  }

  pendingPayment(salesOrderId: string) {
    return this.store.payments.get(salesOrderId);
  }

  /**
   * Verifies a payment with Zoho Payments and confirms the Sales Order.
   * Idempotent; safe to call from both the return URL and the webhook.
   */
  async settlePayment(salesOrderId: string, paymentId: string): Promise<boolean> {
    const pending = this.store.payments.get(salesOrderId);
    if (!pending) throw new CommerceError('Unknown payment.', 404);
    if (pending.settled) return true;
    const payment = await this.payments.getPayment(paymentId);
    const amountOk = Math.abs(Number(payment.amount) - pending.amount) < 0.01;
    const sessionOk = !payment.payments_session_id || payment.payments_session_id === pending.sessionId;
    if (!isPaymentSuccessful(payment) || !amountOk || !sessionOk) return false;
    await this.inventory.markSalesOrder(salesOrderId, 'confirmed');
    await this.inventory.updateSalesOrderNotes(
      salesOrderId,
      `Gowri app order ${pending.orderRef}\nPayment: ${PAYMENT_LABELS[pending.method]} · ${payment.payment_id}`,
    );
    pending.settled = true;
    const phone = [...this.store.customersByPhone.values()].find((c) => c.contactId === pending.customerId)?.phone;
    await this.bookDelivery(salesOrderId, phone);
    return true;
  }

  async settleBySession(sessionId: string, paymentId: string): Promise<boolean> {
    const pending = [...this.store.payments.values()].find((p) => p.sessionId === sessionId);
    return pending ? this.settlePayment(pending.salesOrderId, paymentId) : false;
  }

  async orders(contactId: string): Promise<Order[]> {
    const catalog = await this.catalog.all();
    const list = await this.inventory.listSalesOrders(contactId);
    // The list endpoint omits line items and packages; fetch details for the recent ones.
    const detailed = await Promise.all(list.slice(0, 20).map((so) => this.inventory.getSalesOrder(so.salesorder_id)));
    return detailed.filter((so) => so.status !== 'void').map((so) => toOrder(so, catalog, this.store.deliveries.get(so.salesorder_id)));
  }

  async order(contactId: string, salesOrderId: string): Promise<Order> {
    const so = await this.ownedSalesOrder(contactId, salesOrderId);
    const delivery = await this.deliveryFor(so);
    return toOrder(so, await this.catalog.all(), delivery);
  }

  // ── Delivery (Pidge) ──────────────────────────────────────────────

  /**
   * Books a Pidge trip for a confirmed order. Never throws: a failed booking
   * is logged and retried the next time the order is viewed.
   */
  async bookDelivery(salesOrderId: string, customerPhone?: string): Promise<DeliveryBooking | null> {
    if (!this.delivery?.enabled) return null;
    const existing = this.store.deliveries.get(salesOrderId);
    if (existing) return existing;
    try {
      const so = await this.inventory.getSalesOrder(salesOrderId);
      if (so.status !== 'confirmed') return null;
      const ref = so.reference_number || so.salesorder_number;
      const addr = so.shipping_address ?? {};
      const mobile = (customerPhone ?? so.contact_persons_details?.[0]?.mobile ?? addr.phone ?? '').replace(/\D/g, '').slice(-10);
      const cod = /Payment:\s*Cash on delivery/.test(so.notes ?? '');
      const booking = await this.delivery.createOrder({
        reference: ref,
        drop: {
          name: addr.attention || so.customer_name || 'Gowri customer',
          mobile,
          line: [addr.address, addr.street2].filter(Boolean).join(', '),
          city: addr.city,
          state: addr.state,
          pincode: addr.zip,
        },
        items: so.line_items.map((li) => ({ name: li.name ?? li.sku ?? 'Item', qty: li.quantity, price: li.rate })),
        billAmount: so.total,
        codAmount: cod ? so.total : 0,
        notes: `Zoho ${so.salesorder_number}`,
      });
      this.store.deliveries.set(salesOrderId, { ...booking, reference: ref });
      // Record the Pidge id on the Sales Order so the warehouse team sees it in Zoho.
      await this.inventory.updateSalesOrderNotes(salesOrderId, `${so.notes ?? ''}\nDelivery: Pidge ${booking.deliveryId}`.trim()).catch(() => {});
      return this.store.deliveries.get(salesOrderId)!;
    } catch (e) {
      console.error(`[pidge] booking failed for ${salesOrderId}:`, (e as Error).message);
      return null;
    }
  }

  private async deliveryFor(so: ZohoSalesOrder): Promise<DeliveryBooking | undefined> {
    if (!this.delivery?.enabled || so.status !== 'confirmed') return this.store.deliveries.get(so.salesorder_id);
    let d = this.store.deliveries.get(so.salesorder_id) ?? (await this.bookDelivery(so.salesorder_id)) ?? undefined;
    // Webhooks are primary; poll Pidge at most every 2 minutes as a fallback.
    if (d && !['delivered', 'cancelled'].includes(d.status) && Date.now() - Date.parse(d.updatedAt) > 120_000) {
      try {
        const fresh = await this.delivery.getStatus(d.deliveryId);
        d = this.applyDeliveryUpdate(so.salesorder_id, fresh) ?? d;
      } catch (e) {
        console.warn('[pidge] status poll failed:', (e as Error).message);
      }
    }
    return d;
  }

  private applyDeliveryUpdate(salesOrderId: string, u: Partial<DeliveryBooking>) {
    const d = this.store.deliveries.get(salesOrderId);
    if (!d) return null;
    Object.assign(d, Object.fromEntries(Object.entries(u).filter(([k, v]) => v !== undefined && k !== 'deliveryId')), { updatedAt: new Date().toISOString() });
    return d;
  }

  /** Handles a Pidge status webhook. Returns false when the trip is unknown. */
  handleDeliveryWebhook(payload: Record<string, unknown>): boolean {
    const u = fromPidgePayload(payload as Record<string, any>);
    const entry = [...this.store.deliveries.entries()].find(([, d]) => (u.deliveryId && d.deliveryId === u.deliveryId) || (u.reference && d.reference === u.reference));
    if (!entry) return false;
    this.applyDeliveryUpdate(entry[0], u);
    return true;
  }

  async invoicePdf(contactId: string, salesOrderId: string): Promise<Response> {
    const so = await this.ownedSalesOrder(contactId, salesOrderId);
    const inv = so.invoices?.find((i) => i.status !== 'void' && i.status !== 'draft');
    if (!inv) throw new CommerceError('Your GST invoice is ready once the order ships.', 404);
    return this.inventory.invoicePdf(inv.invoice_id);
  }

  async requestReturn(contactId: string, salesOrderId: string, skus: string[], reason: string) {
    const so = await this.ownedSalesOrder(contactId, salesOrderId);
    if (!skus.length) throw new CommerceError('Pick at least one item to return.');
    const lines = so.line_items.filter((li) => li.sku && skus.includes(li.sku));
    if (!lines.length) throw new CommerceError('Those items are not in this order.');
    const ret = await this.inventory.createSalesReturn(
      salesOrderId,
      lines.map((li) => ({ item_id: li.item_id, salesorder_item_id: li.line_item_id ?? '', quantity: li.quantity })),
      reason,
    );
    const amount = lines.reduce((a, li) => a + (li.item_total ?? li.rate * li.quantity), 0);
    return { returnId: ret.salesreturn_number, amount };
  }

  private async ownedSalesOrder(contactId: string, salesOrderId: string) {
    const so = await this.inventory.getSalesOrder(salesOrderId);
    if (so.customer_id !== contactId) throw new CommerceError('Order not found.', 404);
    return so;
  }
}
