// The app-facing data contract. The Flutter models in app/lib/data/models.dart mirror these.

export interface ProductSection {
  title: string;
  body: string;
}

export interface Product {
  sku: string;
  /** Zoho item_id; never shown in the app, used for order line items. */
  itemId: string;
  name: string;
  size: string;
  /** Maximum retail price (GST inclusive), INR. */
  mrp: number;
  /** Selling rate (GST inclusive), INR. */
  price: number;
  gst: number;
  /** Units available to sell (net of committed stock). */
  stock: number;
  category: string;
  concern: string;
  warehouse: string;
  best: boolean;
  rec: boolean;
  imageUrl: string | null;
  sections: ProductSection[];
}

export interface Coupon {
  code: string;
  value: string;
  desc: string;
  pct?: number;
  concern?: string;
  ship?: boolean;
  minOrder?: number;
}

export interface Address {
  id: string;
  label: string;
  line: string;
  pincode?: string;
  state?: string;
}

export type PaymentMethod = 'upi' | 'card' | 'wallet' | 'netbanking' | 'cod';

export interface CartLine {
  sku: string;
  qty: number;
}

export interface Totals {
  items: (CartLine & { name: string; price: number; mrp: number; lineTotal: number })[];
  mrp: number;
  discount: number;
  coupon: number;
  couponCode: string | null;
  afterDiscounts: number;
  shipping: number;
  codFee: number;
  deliveryLabel: string;
  total: number;
  gst: number;
}

export interface OrderStep {
  title: string;
  sub: string;
  state: 'done' | 'current' | 'pending';
}

export interface Order {
  id: string;
  zohoSo: string;
  salesOrderId: string;
  date: string;
  status: string;
  stage: number;
  items: (CartLine & { name: string; price: number; lineTotal: number })[];
  payment: string;
  total: number;
  eta: string;
  courier: string;
  steps: OrderStep[];
  invoiceAvailable: boolean;
  /** Live rider tracking link from the delivery partner, when available. */
  trackingUrl: string | null;
}

export interface Customer {
  id: string;
  /** Zoho contact_id */
  contactId: string;
  name: string;
  email: string;
  phone: string;
  memberSince: string;
}
