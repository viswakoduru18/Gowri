import { stageForDelivery, type DeliveryBooking } from '../delivery/pidge.js';
import type { ZohoSalesOrder } from '../zoho/inventory.js';
import type { Order, OrderStep, Product } from '../types.js';

export const STEPS = ['Order confirmed', 'Packed at warehouse', 'Shipped', 'Out for delivery', 'Delivered'];

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/** "2026-09-12" → "12 Sep 2026" */
export function formatDate(iso: string): string {
  const [y, m, d] = iso.slice(0, 10).split('-').map(Number);
  return `${d} ${MONTHS[m - 1]} ${y}`;
}

/** "2026-09-27" → "Sat, 27 Sep" */
export function formatEta(iso: string): string {
  const dt = new Date(iso.slice(0, 10) + 'T00:00:00Z');
  return `${DAYS[dt.getUTCDay()]}, ${dt.getUTCDate()} ${MONTHS[dt.getUTCMonth()]}`;
}

export function addDays(iso: string, days: number): string {
  const dt = new Date(iso.slice(0, 10) + 'T00:00:00Z');
  dt.setUTCDate(dt.getUTCDate() + days);
  return dt.toISOString().slice(0, 10);
}

/**
 * Derives the tracking stage (index into STEPS) from Zoho Sales Order,
 * Package and Shipment state. -1 means not yet confirmed (awaiting payment).
 */
export function stageOf(so: ZohoSalesOrder): number {
  if (so.status === 'draft' || so.status === 'void') return -1;
  const pkgs = so.packages ?? [];
  const pkgStatus = pkgs.map((p) => (p.shipment_status || p.status || '').toLowerCase());
  if (pkgStatus.some((s) => s === 'delivered') || so.shipped_status === 'fulfilled') return 4;
  if (pkgStatus.some((s) => s === 'out_for_delivery')) return 3;
  if (pkgStatus.some((s) => s === 'shipped' || s === 'in_transit') || so.shipped_status === 'shipped' || so.shipped_status === 'partially_shipped')
    return 2;
  if (pkgs.length > 0) return 1;
  return 0;
}

export function statusLabel(so: ZohoSalesOrder, stage: number): string {
  if (so.status === 'void') return 'Cancelled';
  if (stage < 0) return 'Awaiting payment';
  return ['Confirmed', 'Packed', 'Shipped', 'Out for delivery', 'Delivered'][stage];
}

/** Payment method is written into SO notes as "Payment: UPI · <payment id>". */
export function paymentFromNotes(notes?: string): string {
  return notes?.match(/Payment:\s*([^·\n]+)/)?.[1]?.trim() ?? '—';
}

export function toOrder(so: ZohoSalesOrder, catalog: Map<string, Product>, delivery?: DeliveryBooking): Order {
  // Zoho packages/shipments and the delivery partner can each move the order forward; take the furthest.
  const deliveryStage = delivery ? stageForDelivery(delivery.status) : null;
  const stage = stageOf(so) < 0 ? stageOf(so) : Math.max(stageOf(so), deliveryStage ?? 0);
  const pkg = so.packages?.find((p) => p.carrier || p.tracking_number || p.delivery_method);
  const steps: OrderStep[] = STEPS.map((title, i) => {
    const state: OrderStep['state'] = i < stage ? 'done' : i === stage ? 'current' : 'pending';
    const sub =
      state === 'done' ? 'Done' : state === 'current' ? (i === 0 ? `Sales Order ${so.salesorder_number} created in Zoho` : 'In progress') : 'Pending';
    return { title, sub, state };
  });
  const bySkuOrItem = (sku?: string, itemId?: string) =>
    [...catalog.values()].find((p) => (sku && p.sku === sku) || p.itemId === itemId);
  const items = so.line_items.map((li) => {
    const p = bySkuOrItem(li.sku, li.item_id);
    return {
      sku: li.sku ?? p?.sku ?? li.item_id,
      qty: li.quantity,
      name: li.name ?? p?.name ?? 'Item',
      price: li.rate,
      lineTotal: li.item_total ?? li.rate * li.quantity,
    };
  });
  const delivered = stage >= 4;
  const deliveredOn = (delivery?.status === 'delivered' ? delivery.updatedAt : undefined) ?? so.packages?.find((p) => p.shipment_date)?.shipment_date ?? so.date;
  return {
    id: so.reference_number || so.salesorder_number,
    zohoSo: so.salesorder_number,
    salesOrderId: so.salesorder_id,
    date: formatDate(so.date),
    status: statusLabel(so, stage),
    stage: Math.max(stage, 0),
    items,
    payment: paymentFromNotes(so.notes),
    total: so.total,
    eta: delivered ? `delivered ${formatDate(deliveredOn)}` : formatEta(so.shipment_date || addDays(so.date, 2)),
    courier: delivery
      ? delivery.riderName
        ? ['Pidge', `Rider ${delivery.riderName}`, delivery.riderMobile].filter(Boolean).join(' · ')
        : 'Pidge · rider being assigned'
      : pkg ? [pkg.carrier || pkg.delivery_method, pkg.tracking_number ? `AWB ${pkg.tracking_number}` : 'AWB pending'].filter(Boolean).join(' · ') : 'Courier assigned at dispatch',
    steps,
    invoiceAvailable: (so.invoices ?? []).some((i) => i.status !== 'void' && i.status !== 'draft'),
    trackingUrl: delivery?.trackingUrl ?? null,
  };
}
