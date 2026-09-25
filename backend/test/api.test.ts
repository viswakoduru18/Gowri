import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import type { AddressInfo } from 'node:net';
import { after, before, test } from 'node:test';
import { config } from '../src/config.js';
import { createApp } from '../src/app.js';
import { OtpService, type SmsSender } from '../src/auth/otp.js';
import { Sessions } from '../src/auth/session.js';
import { Catalog } from '../src/domain/catalog.js';
import { Commerce, loadCoupons } from '../src/domain/commerce.js';
import { Store } from '../src/store.js';
import { ZohoAuth, ZohoClient } from '../src/zoho/client.js';
import { InventoryApi } from '../src/zoho/inventory.js';
import { PaymentsApi } from '../src/zoho/payments.js';
import { PidgeClient } from '../src/delivery/pidge.js';
import { FakeZoho, item } from './fake-zoho.js';

const zoho = new FakeZoho();
const sms: SmsSender & { last?: string } = { async send(_p, code) { sms.last = code; } };
const cfg = {
  ...config,
  payments: { ...config.payments, accountId: 'acc', apiKey: 'pk', webhookSecret: 'whsec' },
  pidge: { ...config.pidge, username: 'u', password: 'p', webhookToken: 'pidge-hook', pickup: { ...config.pidge.pickup, mobile: '9000000000', line: 'Warehouse, Kukatpally', pincode: '500072' } },
};
let base = '';
let server: ReturnType<ReturnType<typeof createApp>['listen']>;

before(async () => {
  const auth = new ZohoAuth({ ...cfg.zoho, refreshToken: 'r', clientId: 'i', clientSecret: 's' }, zoho.fetch as typeof fetch);
  const inventory = new InventoryApi(new ZohoClient('https://www.zohoapis.in', auth, { organization_id: 'org' }, zoho.fetch as typeof fetch));
  const payments = new PaymentsApi(new ZohoClient('https://payments.zoho.in', auth, { account_id: 'acc' }, zoho.fetch as typeof fetch), 'acc');
  const store = new Store();
  const pidge = new PidgeClient(cfg.pidge, zoho.fetch as typeof fetch);
  const commerce = new Commerce(cfg, store, new Catalog(inventory, cfg.zoho, 'http://t', 60_000), inventory, payments, loadCoupons(), pidge);
  const app = createApp({
    cfg, store, otp: new OtpService(store, sms), sessions: new Sessions('test'), commerce,
    inventoryImage: (id) => inventory.itemImage(id), verifyPidgeWebhook: (t) => pidge.verifyWebhook(t),
  });
  server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
after(() => server.close());

let token = '';
async function api(path: string, init: { method?: string; body?: unknown; auth?: boolean } = {}) {
  const res = await fetch(base + path, {
    method: init.method ?? (init.body ? 'POST' : 'GET'),
    headers: { 'content-type': 'application/json', ...(init.auth !== false && token ? { authorization: `Bearer ${token}` } : {}) },
    body: init.body ? JSON.stringify(init.body) : undefined,
    redirect: 'manual',
  });
  const text = await res.text();
  let json: any = null;
  try { json = JSON.parse(text); } catch { /* html/pdf */ }
  return { status: res.status, json, text, headers: res.headers };
}

test('OTP login creates a Zoho contact for a new phone', async () => {
  assert.equal((await api('/v1/auth/otp/send', { body: { phone: '12345' } })).status, 400);
  assert.equal((await api('/v1/auth/otp/send', { body: { phone: '9876543210' } })).status, 200);
  assert.equal((await api('/v1/auth/otp/verify', { body: { phone: '9876543210', code: sms.last === '0000' ? '1111' : '0000' } })).status, 400);
  const ok = await api('/v1/auth/otp/verify', { body: { phone: '9876543210', code: sms.last } });
  assert.equal(ok.status, 200);
  token = ok.json.token;
  assert.equal(zoho.contacts.length, 1);
  assert.equal(zoho.contacts[0].mobile, '9876543210');
  assert.equal((await api('/v1/me')).json.customer.phone, '9876543210');
});

test('profile: name and email are saved on the Zoho contact', async () => {
  assert.equal(zoho.contacts[0].contact_name, 'Gowri customer 3210');
  assert.equal(zoho.contacts[0].gst_treatment, 'consumer', 'new contacts are GST consumers');
  assert.equal((await api('/v1/me', { method: 'PUT', body: { name: 'A' } })).status, 400);
  assert.equal((await api('/v1/me', { method: 'PUT', body: { name: 'Ananya Rao', email: 'nope' } })).status, 400);
  const r = await api('/v1/me', { method: 'PUT', body: { name: '  Ananya   Rao ', email: 'ananya@example.com' } });
  assert.equal(r.status, 200);
  assert.equal(r.json.customer.name, 'Ananya Rao');
  assert.equal(zoho.contacts[0].contact_name, 'Ananya Rao');
  const person = zoho.contacts[0].contact_persons[0];
  assert.deepEqual([person.first_name, person.last_name, person.email, person.is_primary_contact], ['Ananya', 'Rao', 'ananya@example.com', true]);
  assert.equal((await api('/v1/me')).json.customer.name, 'Ananya Rao');
  // Editing again updates the same person rather than adding another.
  await api('/v1/me', { method: 'PUT', body: { name: 'Ananya R', email: 'a@example.com' } });
  assert.equal(zoho.contacts[0].contact_persons.length, 1);
  assert.equal(zoho.contacts[0].contact_persons[0].email, 'a@example.com');
});

test('catalog is public, hides Zoho item ids, and flags stock', async () => {
  const r = await api('/v1/catalog/products', { auth: false });
  assert.equal(r.status, 200);
  const spray = r.json.products.find((p: any) => p.sku === 'MG-MAG-200');
  assert.equal(spray.price, 440);
  assert.equal(spray.mrp, 550);
  assert.equal(spray.best, true);
  assert.equal(spray.itemId, undefined);
  assert.equal(r.json.products.find((p: any) => p.sku === 'GW-GLW-50').stock, 0);
});

test('orders require a session', async () => {
  assert.equal((await api('/v1/orders', { auth: false })).status, 401);
});

test('addresses are stored on the Zoho contact', async () => {
  const r = await api('/v1/me/addresses', { body: { label: 'Home', line1: 'Plot 42, Road No. 10', city: 'Hyderabad', state: 'Telangana', pincode: '500033' } });
  assert.equal(r.status, 200);
  const list = await api('/v1/me/addresses');
  assert.equal(list.json.addresses[0].label, 'Home');
  const c = zoho.contacts[0];
  assert.equal(c.billing_address.city, 'Hyderabad', 'first address becomes the billing address');
  assert.equal(c.place_of_contact, 'TS');
  assert.match(list.json.addresses[0].line, /Jubilee|Road No. 10/);
});

test('quote applies coupons server-side and explains rejections', async () => {
  const q = await api('/v1/cart/quote', { body: { items: [{ sku: 'MG-MAG-200', qty: 1 }, { sku: 'GW-ASH-60', qty: 1 }], couponCode: 'sleep20' } });
  assert.equal(q.json.totals.coupon, 200);
  assert.equal(q.json.couponMessage, 'SLEEP20 applied. Nice.');
  const bad = await api('/v1/cart/quote', { body: { items: [{ sku: 'MG-MAG-200', qty: 1 }], couponCode: 'NOPE' } });
  assert.equal(bad.json.couponMessage, "Hmm, that code isn't valid.");
});

test('UPI order: draft SO → Zoho Payments session → verified payment confirms SO', async () => {
  const r = await api('/v1/orders', { body: { items: [{ sku: 'MG-MAG-200', qty: 1 }, { sku: 'GW-ASH-60', qty: 1 }], couponCode: 'SLEEP20', payment: 'upi', addressId: (await api('/v1/me/addresses')).json.addresses[0].id } });
  assert.equal(r.status, 201);
  const so = zoho.so(r.json.order.salesOrderId) as any;
  assert.equal(so.status, 'draft');
  assert.equal(so.place_of_supply, 'TS', 'GST place of supply from the delivery state');
  assert.equal(so.gst_treatment, 'consumer');
  assert.ok(so.billing_address_id, 'billing address set so the SO can be invoiced');
  assert.equal(so.total, 799);
  assert.match(r.json.payUrl, /\/pay\/so\d+$/);

  const page = await api(new URL(r.json.payUrl).pathname);
  assert.match(page.text, /zpayments\.js/);
  const sessionId = page.text.match(/"payments_session_id":"(ps\d+)"/)![1];

  assert.equal(zoho.pidgeOrders.length, 0, 'no rider before payment');
  // A tampered amount must not confirm the order.
  const cheap = zoho.pay(sessionId, 'succeeded', '1.00');
  const bad = await api(`/pay/${so.salesorder_id}/return?payment_id=${cheap}`);
  assert.match(bad.headers.get('location')!, /status=failed/);
  assert.equal(so.status, 'draft');

  const paid = zoho.pay(sessionId);
  const ret = await api(`/pay/${so.salesorder_id}/return?payment_id=${paid}`);
  assert.match(ret.headers.get('location')!, /status=success/);
  assert.equal(so.status, 'confirmed');
  assert.match(so.notes!, /Payment: UPI · pay\d+/);
  const trip = zoho.pidgeOrders.at(-1);
  assert.equal(trip.trips[0].source_order_id, so.reference_number, 'Pidge trip booked once payment is verified');
  assert.equal(trip.trips[0].cod_amount, 0);
  assert.equal(trip.trips[0].receiver_detail.address.pincode, '500033');
  assert.equal(trip.sender_detail.address.pincode, '500072');
  assert.match(so.notes!, /Delivery: Pidge PDG\d+/);

  const o = await api(`/v1/orders/${so.salesorder_id}`);
  assert.equal(o.json.order.status, 'Confirmed');
  assert.equal(o.json.order.payment, 'UPI');
  assert.equal(o.json.order.steps[0].sub, `Sales Order ${so.salesorder_number} created in Zoho`);
});

test('COD order is confirmed immediately and includes the ₹30 fee', async () => {
  const r = await api('/v1/orders', { body: { items: [{ sku: 'MG-MAG-200', qty: 1 }], payment: 'cod' } });
  assert.equal(r.status, 201);
  assert.equal(r.json.payUrl, null);
  const so = zoho.so(r.json.order.salesOrderId);
  assert.equal(so.status, 'confirmed');
  assert.equal(so.total, 440 + 49 + 30);
  assert.equal(zoho.pidgeOrders.at(-1).trips[0].cod_amount, 519, 'rider collects cash for COD');
});

test('Pidge webhooks move tracking to out for delivery and delivered, with rider details', async () => {
  const r = await api('/v1/orders', { body: { items: [{ sku: 'MG-MAG-200', qty: 2 }], payment: 'cod' } });
  const soId = r.json.order.salesOrderId;
  const pidgeId = zoho.pidgeOrders.at(-1).id;
  assert.equal(r.json.order.courier, 'Pidge · rider being assigned');

  const hook = (body: unknown, token = 'pidge-hook') => fetch(`${base}/webhooks/pidge`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-pidge-token': token }, body: JSON.stringify(body) });
  assert.equal((await hook({ id: pidgeId, status: 'OUT_FOR_DELIVERY' }, 'wrong')).status, 401);

  await hook({ id: pidgeId, status: 'OUT_FOR_DELIVERY', rider: { name: 'Ravi', mobile: '9000000001' }, tracking_url: 'https://track.pidge.in/x' });
  let o = (await api(`/v1/orders/${soId}`)).json.order;
  assert.equal(o.status, 'Out for delivery');
  assert.equal(o.stage, 3);
  assert.equal(o.courier, 'Pidge · Rider Ravi · 9000000001');
  assert.equal(o.trackingUrl, 'https://track.pidge.in/x');

  // Webhook keyed by our order reference also works.
  await hook({ trips: [{ source_order_id: r.json.order.id, status: 'Delivered' }] });
  o = (await api(`/v1/orders/${soId}`)).json.order;
  assert.equal(o.status, 'Delivered');
  assert.equal(o.steps[4].state, 'current');
});

test('orders still go through if Zoho rejects the GST fields', async () => {
  zoho.rejectSoFields = ['place_of_supply'];
  const addressId = (await api('/v1/me/addresses')).json.addresses[0].id;
  const r = await api('/v1/orders', { body: { items: [{ sku: 'MG-MAG-200', qty: 1 }], payment: 'cod', addressId } });
  zoho.rejectSoFields = [];
  assert.equal(r.status, 201);
  assert.equal((zoho.so(r.json.order.salesOrderId) as any).place_of_supply, undefined);
});

test('stock held in a Zoho location counts even when the item summary says 0', async () => {
  zoho.items.push(item('LOC-1', 'Location Stocked Cream', 300, 400, 0));
  zoho.locationStock.set('LOC-1', 42);
  // Any order clears the catalog cache; the next load re-reads zero-stock items' locations.
  await api('/v1/orders', { body: { items: [{ sku: 'GW-ASH-60', qty: 1 }], payment: 'cod' } });
  const p = (await api('/v1/catalog/products')).json.products.find((x: any) => x.sku === 'LOC-1');
  assert.equal(p.stock, 42);
  assert.equal(p.warehouse, 'Hyderabad WH');
  const r = await api('/v1/orders', { body: { items: [{ sku: 'LOC-1', qty: 2 }], payment: 'cod' } });
  assert.equal(r.status, 201, 'checkout re-read sees location stock too');
});

test('checkout re-reads stock from Zoho and refuses oversell', async () => {
  const r = await api('/v1/orders', { body: { items: [{ sku: 'MG-D3-30', qty: 7 }], payment: 'upi' } });
  assert.equal(r.status, 409);
  assert.equal(r.json.error, 'Only 6 of MyGlo Vitamin D3 Drops left.');
  const sold = await api('/v1/orders', { body: { items: [{ sku: 'GW-GLW-50', qty: 1 }], payment: 'upi' } });
  assert.equal(sold.status, 409);
});

test('webhook settles a payment when the app was closed', async () => {
  const r = await api('/v1/orders', { body: { items: [{ sku: 'GW-ASH-60', qty: 1 }], payment: 'card' } });
  const soId = r.json.order.salesOrderId;
  const sessionId = (await api(`/pay/${soId}`)).text.match(/"payments_session_id":"(ps\d+)"/)![1];
  const paymentId = zoho.pay(sessionId);
  const body = JSON.stringify({ event_type: 'payment.succeeded', event_object: { payment: { payment_id: paymentId, payments_session_id: sessionId } } });
  const unsigned = await fetch(`${base}/webhooks/zoho-payments`, { method: 'POST', body });
  assert.equal(unsigned.status, 401);
  const sig = createHmac('sha256', 'whsec').update(body).digest('hex');
  const signed = await fetch(`${base}/webhooks/zoho-payments`, { method: 'POST', body, headers: { 'x-zoho-webhook-signature': sig } });
  assert.equal(signed.status, 200);
  assert.equal(zoho.so(soId).status, 'confirmed');
});

test('order history, invoice gating, and returns create a Zoho sales return', async () => {
  const list = await api('/v1/orders');
  assert.ok(list.json.orders.length >= 3);
  const first = list.json.orders[0];
  assert.equal((await api(`/v1/orders/${first.salesOrderId}/invoice`)).status, 404);
  zoho.so(first.salesOrderId).invoices = [{ invoice_id: 'inv1', invoice_number: 'INV-1', status: 'sent' }];
  const pdf = await api(`/v1/orders/${first.salesOrderId}/invoice`);
  assert.equal(pdf.status, 200);
  assert.equal(pdf.headers.get('content-type'), 'application/pdf');

  const link = await api(`/v1/orders/${first.salesOrderId}/invoice-link`, { body: {} });
  const viaLink = await fetch(link.json.url.replace(config.publicBaseUrl, base));
  assert.equal(viaLink.headers.get('content-type'), 'application/pdf');
  assert.equal((await fetch(`${base}/invoices/${token}`)).status, 410, 'session token is not an invoice link');
  const linkToken = decodeURIComponent(link.json.url.split('/').pop());
  assert.equal((await fetch(`${base}/v1/orders`, { headers: { authorization: `Bearer ${linkToken}` } })).status, 401, 'invoice link is not a session');

  const ret = await api(`/v1/orders/${first.salesOrderId}/returns`, { body: { skus: [first.items[0].sku], reason: 'Damaged in transit' } });
  assert.equal(ret.status, 201);
  assert.equal(zoho.returns.at(-1).reason, 'Damaged in transit');
  assert.equal(ret.json.amount, first.items[0].lineTotal);
});

test('another customer cannot read my order', async () => {
  const mine = (await api('/v1/orders')).json.orders[0].salesOrderId;
  await new Promise((r) => setTimeout(r, 10));
  await api('/v1/auth/otp/send', { body: { phone: '9123456789' } });
  const other = await api('/v1/auth/otp/verify', { body: { phone: '9123456789', code: sms.last } });
  const r = await fetch(`${base}/v1/orders/${mine}`, { headers: { authorization: `Bearer ${other.json.token}` } });
  assert.equal(r.status, 404);
});

test('Zoho OAuth token is minted once and reused', () => {
  assert.equal(zoho.tokenRefreshes, 1);
});
