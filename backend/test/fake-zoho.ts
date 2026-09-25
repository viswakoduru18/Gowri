// An in-memory stand-in for the Zoho Inventory, Books and Payments REST APIs,
// exposed as a `fetch` implementation. Only the behaviour the backend relies on
// is modelled.

import type { ZohoItem, ZohoSalesOrder } from '../src/zoho/inventory.js';

export function item(sku: string, name: string, rate: number, mrp: number, stock: number, extra: Partial<ZohoItem> & Record<string, unknown> = {}): ZohoItem {
  return {
    item_id: `id-${sku}`,
    name,
    sku,
    rate,
    status: 'active',
    tax_percentage: 18,
    actual_available_stock: stock,
    category_name: 'Body',
    description: `${name} description`,
    custom_fields: [
      { api_name: 'cf_mrp', value: mrp },
      { api_name: 'cf_concern', value: 'Sleep & Stress' },
      { api_name: 'cf_pack_size', value: '200 ml' },
    ],
    ...extra,
  };
}

export class FakeZoho {
  items: ZohoItem[] = [
    item('MG-MAG-200', 'MyGlo Magnesium Body Spray', 440, 550, 327, { cf_best_seller: 'true' } as never),
    item('GW-ASH-60', 'Ashwagandha Calm Capsules', 559, 699, 142, { tax_percentage: 12, category_name: 'Herbal' }),
    item('GW-GLW-50', 'Glow Vitamin C Face Serum', 719, 899, 0, {
      category_name: 'Skin',
      custom_fields: [
        { api_name: 'cf_mrp', value: 899 },
        { api_name: 'cf_concern', value: 'Skin & Glow' },
      ],
    }),
    item('MG-D3-30', 'MyGlo Vitamin D3 Drops', 399, 450, 6, { category_name: 'Vitamins' }),
  ];
  contacts: { contact_id: string; contact_name: string; mobile: string; addresses: any[] }[] = [];
  salesorders: ZohoSalesOrder[] = [];
  payments = new Map<string, { payment_id: string; payments_session_id: string; status: string; amount: string; currency: string }>();
  sessions = new Map<string, { amount: string }>();
  returns: any[] = [];
  calls: string[] = [];
  pidgeOrders: any[] = [];
  pidgeStatus = new Map<string, string>();
  tokenRefreshes = 0;
  private n = 0;

  fetch = async (input: string | URL | Request, init: RequestInit = {}): Promise<Response> => {
    const url = new URL(String(input));
    const method = init.method ?? 'GET';
    const body = init.body ? JSON.parse(String(init.body)) : undefined;
    this.calls.push(`${method} ${url.pathname}`);
    const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { 'content-type': 'application/json' } });
    const p = url.pathname;

    if (url.host === 'api.pidge.in') {
      if (p.endsWith('/login')) return json({ data: { token: 'pidge-tok' } });
      if ((init.headers as Record<string, string>)?.Authorization !== 'pidge-tok') return json({ message: 'unauthorized' }, 401);
      if (p === '/v1.0/store/channel/vendor/order' && method === 'POST') {
        const id = `PDG${++this.n}`;
        this.pidgeOrders.push({ id, ...body });
        this.pidgeStatus.set(id, 'CREATED');
        return json({ data: { [body.trips[0].source_order_id]: id } });
      }
      const m2 = p.match(/\/order\/([^/]+)$/);
      if (m2) return json({ data: { id: m2[1], status: this.pidgeStatus.get(m2[1]), rider: { name: 'Ravi', mobile: '9000000001' } } });
    }
    if (p === '/oauth/v2/token') {
      this.tokenRefreshes++;
      return json({ access_token: 'tok', expires_in: 3600 });
    }
    if (!String((init.headers as Record<string, string>)?.Authorization).startsWith('Zoho-oauthtoken')) return json({ code: 57, message: 'unauthorized' }, 401);

    let m: RegExpMatchArray | null;
    if (p === '/inventory/v1/items') return json({ code: 0, items: this.items, page_context: { has_more_page: false } });
    if ((m = p.match(/^\/inventory\/v1\/items\/([^/]+)$/))) return json({ code: 0, item: this.items.find((i) => i.item_id === m![1]) });
    if ((m = p.match(/^\/inventory\/v1\/items\/([^/]+)\/image$/))) return new Response('img', { headers: { 'content-type': 'image/png' } });

    if (p === '/inventory/v1/contacts' && method === 'GET') {
      const q = url.searchParams.get('search_text') ?? '';
      return json({ code: 0, contacts: this.contacts.filter((c) => c.mobile.includes(q)) });
    }
    if (p === '/inventory/v1/contacts' && method === 'POST') {
      const c = { contact_id: `c${++this.n}`, contact_name: body.contact_name, mobile: body.mobile, created_time: '2026-09-25T10:00:00+0530', addresses: [] };
      this.contacts.push(c);
      return json({ code: 0, contact: c });
    }
    if ((m = p.match(/^\/inventory\/v1\/contacts\/([^/]+)\/address$/))) {
      const c = this.contacts.find((x) => x.contact_id === m![1])!;
      if (method === 'POST') {
        const a = { address_id: `a${++this.n}`, ...body };
        c.addresses.push(a);
        return json({ code: 0, address_info: a });
      }
      return json({ code: 0, addresses: c.addresses });
    }

    if (p === '/inventory/v1/salesorders' && method === 'POST') {
      const line_items = body.line_items.map((li: any, i: number) => {
        const it = this.items.find((x) => x.item_id === li.item_id)!;
        return { ...li, line_item_id: `li${i}`, sku: it.sku, name: it.name, item_total: li.rate * li.quantity };
      });
      const sub = line_items.reduce((a: number, li: any) => a + li.item_total, 0);
      const so: ZohoSalesOrder = {
        salesorder_id: `so${++this.n}`,
        salesorder_number: `SO-${String(this.n).padStart(5, '0')}`,
        reference_number: body.reference_number,
        date: body.date,
        status: 'draft',
        total: sub - (body.discount ?? 0) + (body.shipping_charge ?? 0) + (body.adjustment ?? 0),
        customer_id: body.customer_id,
        customer_name: this.contacts.find((c) => c.contact_id === body.customer_id)?.contact_name,
        shipping_address: this.contacts.flatMap((c) => c.addresses).find((a) => a.address_id === body.shipping_address_id),
        line_items,
        packages: [],
        invoices: [],
        notes: body.notes,
      };
      this.salesorders.push(so);
      return json({ code: 0, salesorder: so });
    }
    if (p === '/inventory/v1/salesorders') {
      const cid = url.searchParams.get('customer_id');
      return json({ code: 0, salesorders: this.salesorders.filter((s) => s.customer_id === cid).map(({ line_items: _l, packages: _p, ...rest }) => rest) });
    }
    if ((m = p.match(/^\/inventory\/v1\/salesorders\/([^/]+)\/status\/(\w+)$/))) {
      this.so(m[1]).status = m[2];
      return json({ code: 0 });
    }
    if ((m = p.match(/^\/inventory\/v1\/salesorders\/([^/]+)$/))) {
      if (method === 'PUT') Object.assign(this.so(m[1]), body);
      return json({ code: 0, salesorder: this.so(m[1]) });
    }
    if ((m = p.match(/^\/inventory\/v1\/invoices\/([^/]+)$/))) return new Response('%PDF-1.4', { headers: { 'content-type': 'application/pdf' } });
    if (p === '/inventory/v1/salesreturns') {
      const r = { salesreturn_id: `r${++this.n}`, salesreturn_number: `RMA-${this.n}`, salesorder_id: url.searchParams.get('salesorder_id'), ...body };
      this.returns.push(r);
      return json({ code: 0, salesreturn: r });
    }

    if (p === '/api/v1/paymentsessions') {
      const id = `ps${++this.n}`;
      this.sessions.set(id, { amount: body.amount });
      return json({ code: 0, payments_session: { payments_session_id: id, amount: body.amount, currency: 'INR' } });
    }
    if ((m = p.match(/^\/api\/v1\/payments\/([^/]+)$/))) {
      const pay = this.payments.get(m[1]);
      return pay ? json({ code: 0, payment: pay }) : json({ code: 1, message: 'not found' }, 404);
    }
    return json({ code: 404, message: `fake zoho: no route ${method} ${p}` }, 404);
  };

  so(id: string) {
    return this.salesorders.find((s) => s.salesorder_id === id)!;
  }

  /** Simulates a customer completing checkout in the Zoho Payments widget. */
  pay(sessionId: string, status = 'succeeded', amount?: string) {
    const id = `pay${++this.n}`;
    this.payments.set(id, { payment_id: id, payments_session_id: sessionId, status, amount: amount ?? this.sessions.get(sessionId)!.amount, currency: 'INR' });
    return id;
  }
}
