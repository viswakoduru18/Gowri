import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { test } from 'node:test';
import { config } from '../src/config.js';
import { toProduct } from '../src/domain/catalog.js';
import { stageOf, toOrder, formatEta } from '../src/domain/orders.js';
import { quote, type CouponRule } from '../src/domain/pricing.js';
import { loadCoupons } from '../src/domain/commerce.js';
import { verifyWebhookSignature } from '../src/zoho/payments.js';
import type { Product } from '../src/types.js';
import type { ZohoSalesOrder } from '../src/zoho/inventory.js';
import { item } from './fake-zoho.js';

const P = (sku: string, price: number, mrp: number, gst: number, concern: string, stock = 50): Product => ({
  sku, itemId: sku, name: sku, size: '', mrp, price, gst, stock, category: 'x', concern, warehouse: 'Hyderabad', best: false, rec: false, imageUrl: null, sections: [],
});
const catalog = new Map([
  ['MG-MAG-200', P('MG-MAG-200', 440, 550, 18, 'Sleep & Stress')],
  ['GW-ASH-60', P('GW-ASH-60', 559, 699, 12, 'Sleep & Stress')],
  ['GW-HAIR-100', P('GW-HAIR-100', 339, 399, 18, 'Hair & Scalp')],
  ['GW-GLW-50', P('GW-GLW-50', 719, 899, 18, 'Skin & Glow', 0)],
]);
const coupons = loadCoupons();
const c = (code: string) => coupons.find((x) => x.code === code) as CouponRule;

test('quote matches the prototype: MRP, discount, free delivery at ₹499, GST extracted', () => {
  const t = quote([{ sku: 'MG-MAG-200', qty: 1 }, { sku: 'GW-ASH-60', qty: 1 }], catalog);
  assert.equal(t.mrp, 1249);
  assert.equal(t.discount, 250);
  assert.equal(t.afterDiscounts, 999);
  assert.equal(t.shipping, 0);
  assert.equal(t.deliveryLabel, 'Free');
  assert.equal(t.total, 999);
  assert.equal(t.gst, Math.round(440 * 18 / 118 + 559 * 12 / 112));
});

test('₹49 delivery below ₹499 and ₹30 COD fee', () => {
  const t = quote([{ sku: 'GW-HAIR-100', qty: 1 }], catalog, { payment: 'cod' });
  assert.equal(t.shipping, 49);
  assert.equal(t.codFee, 30);
  assert.equal(t.deliveryLabel, '₹49 + ₹30 COD');
  assert.equal(t.total, 339 + 49 + 30);
});

test('SLEEP20 discounts only Sleep & Stress lines; FREESHIP waives delivery', () => {
  const t = quote([{ sku: 'MG-MAG-200', qty: 1 }, { sku: 'GW-HAIR-100', qty: 1 }], catalog, { coupon: c('SLEEP20') });
  assert.equal(t.coupon, 88);
  assert.equal(t.couponCode, 'SLEEP20');
  const f = quote([{ sku: 'GW-HAIR-100', qty: 1 }], catalog, { coupon: c('FREESHIP') });
  assert.equal(f.shipping, 0);
  assert.equal(f.total, 339);
});

test('coupon rules: SLEEP20 minimum order, GLOW10 first order only', () => {
  assert.equal(quote([{ sku: 'GW-HAIR-100', qty: 1 }], catalog, { coupon: c('SLEEP20') }).couponCode, null);
  assert.equal(quote([{ sku: 'GW-HAIR-100', qty: 2 }], catalog, { coupon: c('GLOW10'), isFirstOrder: false }).coupon, 0);
  assert.equal(quote([{ sku: 'GW-HAIR-100', qty: 2 }], catalog, { coupon: c('GLOW10'), isFirstOrder: true }).coupon, 68);
});

test('quote rejects out-of-stock items and clamps quantity to stock', () => {
  assert.throws(() => quote([{ sku: 'GW-GLW-50', qty: 1 }], catalog), /out of stock/);
  const small = new Map([['A', P('A', 100, 100, 18, '', 2)]]);
  assert.equal(quote([{ sku: 'A', qty: 5 }], small).items[0].qty, 2);
});

test('Zoho item → Product uses custom fields for MRP, concern and pack size', () => {
  const p = toProduct(item('MG-MAG-200', 'Spray', 440, 550, 327), config.zoho, 'https://api.gowri.in')!;
  assert.equal(p.mrp, 550);
  assert.equal(p.price, 440);
  assert.equal(p.stock, 327);
  assert.equal(p.concern, 'Sleep & Stress');
  assert.equal(p.size, '200 ml');
  assert.equal(p.gst, 18);
  assert.equal(p.sections[0].title, 'What it does');
  // flattened list-response custom field
  const q = toProduct({ ...item('X', 'X', 10, 10, 1), custom_fields: [], cf_mrp: 20 } as never, config.zoho, '')!;
  assert.equal(q.mrp, 20);
  assert.equal(toProduct({ ...item('Y', 'Y', 1, 1, 1), status: 'inactive' }, config.zoho, ''), null);
});

const so = (patch: Partial<ZohoSalesOrder>): ZohoSalesOrder => ({
  salesorder_id: '1', salesorder_number: 'SO-00432', reference_number: 'GW-10432', date: '2026-09-25', status: 'confirmed', total: 999, customer_id: 'c',
  line_items: [{ item_id: 'MG-MAG-200', sku: 'MG-MAG-200', rate: 440, quantity: 1 }], notes: 'Payment: UPI · pay1', ...patch,
});

test('tracking stage follows Sales Order → Package → Shipment state', () => {
  assert.equal(stageOf(so({ status: 'draft' })), -1);
  assert.equal(stageOf(so({})), 0);
  assert.equal(stageOf(so({ packages: [{ package_id: 'p', status: 'not_shipped' }] })), 1);
  assert.equal(stageOf(so({ packages: [{ package_id: 'p', status: 'shipped' }] })), 2);
  assert.equal(stageOf(so({ packages: [{ package_id: 'p', status: 'shipped', shipment_status: 'out_for_delivery' }] })), 3);
  assert.equal(stageOf(so({ packages: [{ package_id: 'p', status: 'delivered' }] })), 4);
});

test('toOrder builds the design’s tracking steps and labels', () => {
  const o = toOrder(so({}), catalog);
  assert.equal(o.id, 'GW-10432');
  assert.equal(o.status, 'Confirmed');
  assert.equal(o.payment, 'UPI');
  assert.equal(o.steps[0].sub, 'Sales Order SO-00432 created in Zoho');
  assert.equal(o.steps[0].state, 'current');
  assert.equal(o.eta, 'Sun, 27 Sep');
  assert.equal(formatEta('2026-09-27'), 'Sun, 27 Sep');
  const d = toOrder(so({ packages: [{ package_id: 'p', status: 'delivered', shipment_date: '2026-09-12', carrier: 'Delhivery', tracking_number: '123' }] }), catalog);
  assert.equal(d.status, 'Delivered');
  assert.equal(d.eta, 'delivered 12 Sep 2026');
  assert.equal(d.courier, 'Delhivery · AWB 123');
});

test('webhook signature verification', () => {
  const body = Buffer.from('{"a":1}');
  const sig = createHmac('sha256', 'k').update(body).digest('hex');
  assert.equal(verifyWebhookSignature(body, sig, 'k'), true);
  assert.equal(verifyWebhookSignature(body, sig, 'other'), false);
  assert.equal(verifyWebhookSignature(body, undefined, 'k'), false);
});

test('Pidge status strings normalise to tracking stages', async () => {
  const { normaliseStatus, stageForDelivery } = await import('../src/delivery/pidge.js');
  assert.equal(normaliseStatus('OUT_FOR_DELIVERY'), 'out_for_delivery');
  assert.equal(normaliseStatus('Delivered'), 'delivered');
  assert.equal(normaliseStatus('UNDELIVERED'), 'failed');
  assert.equal(normaliseStatus('picked-up'), 'picked_up');
  assert.equal(normaliseStatus('RIDER_ASSIGNED'), 'rider_assigned');
  assert.equal(normaliseStatus('CREATED'), 'booked');
  assert.equal(stageForDelivery('out_for_delivery'), 3);
  assert.equal(stageForDelivery('booked'), null);
});

test('Zoho token refresh sends a form body and reports HTML replies clearly', async () => {
  const { ZohoAuth } = await import('../src/zoho/client.js');
  const cfg = { ...config.zoho, clientId: 'id', clientSecret: 'sec', refreshToken: 'rt' };
  let seen: RequestInit | undefined;
  const ok = new ZohoAuth(cfg, (async (_u: string, init: RequestInit) => {
    seen = init;
    return new Response(JSON.stringify({ access_token: 'a', expires_in: 3600 }));
  }) as unknown as typeof fetch);
  assert.equal(await ok.accessToken(), 'a');
  assert.equal(String(seen?.body), 'refresh_token=rt&client_id=id&client_secret=sec&grant_type=refresh_token');
  const html = new ZohoAuth(cfg, (async () => new Response('<html><head><title>Zoho Accounts</title></head></html>', { status: 400 })) as unknown as typeof fetch);
  await assert.rejects(html.accessToken(), /returned HTML \(HTTP 400, page "Zoho Accounts"\)/);
  const bad = new ZohoAuth(cfg, (async () => new Response(JSON.stringify({ error: 'invalid_client' }))) as unknown as typeof fetch);
  await assert.rejects(bad.accessToken(), /invalid_client \(check ZOHO_CLIENT_ID/);
});

test('GST comes from Zoho India item_tax_preferences', async () => {
  const { gstRate } = await import('../src/domain/catalog.js');
  assert.equal(gstRate({ ...item('A', 'A', 1, 1, 1), tax_percentage: undefined, item_tax_preferences: [{ tax_specification: 'inter', tax_percentage: 12 }, { tax_specification: 'intra', tax_percentage: 12 }] }), 12);
  assert.equal(gstRate({ ...item('A', 'A', 1, 1, 1), tax_percentage: undefined, intra_state_tax_rate: 5 } as never), 5);
  assert.equal(gstRate({ ...item('A', 'A', 1, 1, 1), is_taxable: false }), 0);
});

test('stock: summary fields first, then location/warehouse totals', async () => {
  const { stockOf } = await import('../src/domain/catalog.js');
  const base = item('S', 'S', 1, 1, 0);
  assert.equal(stockOf({ ...base, actual_available_stock: 7 }), 7);
  assert.equal(stockOf({ ...base, actual_available_stock: 0, available_stock: 0, stock_on_hand: 12 }), 12);
  assert.equal(stockOf({ ...base, actual_available_stock: 0, locations: [{ location_actual_available_for_sale_stock: 5 }, { location_actual_available_for_sale_stock: 3 }] }), 8);
  assert.equal(stockOf({ ...base, actual_available_stock: 0, warehouses: [{ warehouse_name: 'W', warehouse_actual_available_stock: '4' }] }), 4);
  assert.equal(stockOf({ ...base, actual_available_stock: 0 }), 0);
});

test('Indian state names map to Zoho place-of-supply codes', async () => {
  const { stateCode } = await import('../src/domain/india.js');
  assert.equal(stateCode('Telangana'), 'TS');
  assert.equal(stateCode(' tamil nadu '), 'TN');
  assert.equal(stateCode('Jammu & Kashmir'), 'JK');
  assert.equal(stateCode('KA'), 'KA');
  assert.equal(stateCode('Atlantis'), undefined);
});
