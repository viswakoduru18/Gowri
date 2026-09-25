import type { CartLine, Coupon, PaymentMethod, Product, Totals } from '../types.js';

export const FREE_SHIPPING_THRESHOLD = 499;
export const SHIPPING_FEE = 49;
export const COD_FEE = 30;

export interface CouponRule extends Coupon {
  firstOrderOnly?: boolean;
}

export class PricingError extends Error {}

/** Validates a coupon against the cart; returns a customer-facing reason when it cannot be used. */
export function couponProblem(c: CouponRule, sell: number, isFirstOrder: boolean): string | null {
  if (c.minOrder && sell < c.minOrder) return `${c.code} needs a minimum order of ₹${c.minOrder}.`;
  if (c.firstOrderOnly && !isFirstOrder) return `${c.code} is valid on your first order only.`;
  return null;
}

/**
 * Server-authoritative cart pricing. All prices are GST inclusive, so GST is
 * extracted from the selling price rather than added on top.
 */
export function quote(
  lines: CartLine[],
  catalog: Map<string, Product>,
  opts: { coupon?: CouponRule | null; payment?: PaymentMethod; isFirstOrder?: boolean } = {},
): Totals {
  const items = lines
    .filter((l) => l.qty > 0)
    .map((l) => {
      const p = catalog.get(l.sku);
      if (!p) throw new PricingError(`Unknown product ${l.sku}`);
      if (p.stock <= 0) throw new PricingError(`${p.name} is out of stock`);
      const qty = Math.min(Math.floor(l.qty), p.stock);
      return { sku: p.sku, qty, name: p.name, price: p.price, mrp: p.mrp, lineTotal: p.price * qty, gstPct: p.gst, concern: p.concern };
    });
  const mrp = items.reduce((a, i) => a + i.mrp * i.qty, 0);
  const sell = items.reduce((a, i) => a + i.lineTotal, 0);
  let shipping = sell >= FREE_SHIPPING_THRESHOLD || sell === 0 ? 0 : SHIPPING_FEE;
  let couponAmount = 0;
  const coupon = opts.coupon && !couponProblem(opts.coupon, sell, opts.isFirstOrder ?? false) ? opts.coupon : null;
  if (coupon) {
    if (coupon.ship) shipping = 0;
    else if (coupon.concern)
      couponAmount = Math.round(
        (items.filter((i) => i.concern === coupon.concern).reduce((a, i) => a + i.lineTotal, 0) * (coupon.pct ?? 0)) / 100,
      );
    else couponAmount = Math.round((sell * (coupon.pct ?? 0)) / 100);
  }
  const codFee = opts.payment === 'cod' && items.length ? COD_FEE : 0;
  const afterDiscounts = sell - couponAmount;
  const total = afterDiscounts + shipping + codFee;
  const gst = Math.round(items.reduce((a, i) => a + i.lineTotal * (i.gstPct / (100 + i.gstPct)), 0));
  const deliveryLabel =
    shipping === 0 ? (codFee ? `Free + ₹${COD_FEE} COD` : 'Free') : `₹${shipping}${codFee ? ` + ₹${COD_FEE} COD` : ''}`;
  return {
    items: items.map(({ sku, qty, name, price, mrp, lineTotal }) => ({ sku, qty, name, price, mrp, lineTotal })),
    mrp,
    discount: mrp - sell,
    coupon: couponAmount,
    couponCode: coupon?.code ?? null,
    afterDiscounts,
    shipping,
    codFee,
    deliveryLabel,
    total,
    gst,
  };
}
