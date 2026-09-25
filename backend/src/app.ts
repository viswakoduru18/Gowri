import express, { type NextFunction, type Request, type Response } from 'express';
import { z } from 'zod';
import type { Config } from './config.js';
import { OtpError, type OtpService } from './auth/otp.js';
import type { SessionClaims, Sessions } from './auth/session.js';
import { CommerceError, type Commerce } from './domain/commerce.js';
import { verifyWebhookSignature } from './zoho/payments.js';
import { ZohoError } from './zoho/client.js';
import { paymentPage, resultPage } from './payment-page.js';
import type { Store } from './store.js';
import type { Customer, Product } from './types.js';

export interface Deps {
  cfg: Config;
  store: Store;
  otp: OtpService;
  sessions: Sessions;
  commerce: Commerce;
  inventoryImage: (itemId: string) => Promise<Response | globalThis.Response>;
  verifyPidgeWebhook: (token: string | undefined) => boolean;
}

const phoneSchema = z.string().regex(/^[6-9]\d{9}$/, 'Enter a valid 10-digit mobile number');
const lineSchema = z.object({ sku: z.string().min(1), qty: z.number().int().positive().max(99) });
const paymentSchema = z.enum(['upi', 'card', 'wallet', 'netbanking', 'cod']);

type Handler = (req: Request, res: Response) => Promise<unknown>;
const h = (fn: Handler) => (req: Request, res: Response, next: NextFunction) => fn(req, res).catch(next);

/** Public product shape (drops the internal Zoho item id). */
const publicProduct = ({ itemId: _itemId, ...p }: Product) => p;

export function createApp(d: Deps) {
  const app = express();
  app.disable('x-powered-by');

  // Webhook needs the raw body for signature verification, so it is mounted before express.json().
  app.post(
    '/webhooks/zoho-payments',
    express.raw({ type: '*/*' }),
    h(async (req, res) => {
      const raw = req.body as Buffer;
      if (!verifyWebhookSignature(raw, req.header('x-zoho-webhook-signature'), d.cfg.payments.webhookSecret)) {
        return res.status(401).json({ error: 'bad signature' });
      }
      const evt = JSON.parse(raw.toString('utf8'));
      const payment = evt?.event_object?.payment ?? evt?.payment ?? {};
      if (payment.payment_id && payment.payments_session_id) {
        await d.commerce.settleBySession(payment.payments_session_id, payment.payment_id);
      }
      res.json({ ok: true });
    }),
  );

  app.use(express.json({ limit: '100kb' }));

  // Pidge delivery status updates.
  app.post('/webhooks/pidge', (req, res) => {
    const token = req.header('x-pidge-token') ?? req.header('authorization');
    if (!d.verifyPidgeWebhook(token)) return res.status(401).json({ error: 'bad token' });
    const known = d.commerce.handleDeliveryWebhook(req.body ?? {});
    res.json({ ok: true, known });
  });

  app.get('/healthz', (_req, res) => res.json({ ok: true }));

  // ── Auth ────────────────────────────────────────────────────────────
  app.post(
    '/v1/auth/otp/send',
    h(async (req, res) => {
      const phone = phoneSchema.parse(req.body?.phone);
      await d.otp.send(phone);
      res.json({ ok: true });
    }),
  );

  app.post(
    '/v1/auth/otp/verify',
    h(async (req, res) => {
      const { phone, code } = z.object({ phone: phoneSchema, code: z.string().regex(/^\d{4}$/) }).parse(req.body);
      if (!d.otp.verify(phone, code)) return res.status(400).json({ error: "That code doesn't match. Try again." });
      const customer = await d.commerce.signIn(phone);
      const token = await d.sessions.issue({ customerId: customer.id, contactId: customer.contactId, phone });
      res.json({ token, customer });
    }),
  );

  // ── Catalog (public) ────────────────────────────────────────────────
  app.get(
    '/v1/catalog/products',
    h(async (_req, res) => {
      const all = [...(await d.commerce.catalog.all()).values()];
      res.set('Cache-Control', 'public, max-age=30').json({ products: all.map(publicProduct) });
    }),
  );

  app.get(
    '/v1/catalog/products/:sku',
    h(async (req, res) => {
      const p = (await d.commerce.catalog.all()).get(String(req.params.sku));
      if (!p) return res.status(404).json({ error: 'Product not found' });
      res.json({ product: publicProduct(p) });
    }),
  );

  app.get(
    '/v1/catalog/products/:sku/image',
    h(async (req, res) => {
      const p = (await d.commerce.catalog.all()).get(String(req.params.sku));
      if (!p) return res.status(404).end();
      const img = (await d.inventoryImage(p.itemId)) as globalThis.Response;
      res.set('Content-Type', img.headers.get('content-type') ?? 'image/jpeg').set('Cache-Control', 'public, max-age=86400');
      res.send(Buffer.from(await img.arrayBuffer()));
    }),
  );

  app.get('/v1/coupons', (_req, res) => {
    res.json({ coupons: d.commerce.coupons.map(({ code, value, desc, pct, concern, ship, minOrder, firstOrderOnly }) => ({ code, value, desc, pct, concern, ship, minOrder, firstOrderOnly })) });
  });

  // ── Signed-in customer ──────────────────────────────────────────────
  const authed = express.Router();
  authed.use(d.sessions.middleware());
  const session = (res: Response) => res.locals.session as SessionClaims;
  const customerOf = async (res: Response): Promise<Customer> => d.commerce.signIn(session(res).phone);

  authed.get(
    '/me',
    h(async (_req, res) => res.json({ customer: await customerOf(res) })),
  );

  authed.get(
    '/me/addresses',
    h(async (_req, res) => res.json({ addresses: await d.commerce.addresses(session(res).contactId) })),
  );

  authed.post(
    '/me/addresses',
    h(async (req, res) => {
      const body = z
        .object({ label: z.string().min(1).max(40), line1: z.string().min(3), line2: z.string().optional(), city: z.string().min(2), state: z.string().min(2), pincode: z.string().regex(/^\d{6}$/) })
        .parse(req.body);
      res.json({ address: await d.commerce.addAddress(session(res).contactId, body) });
    }),
  );

  authed.get('/me/wishlist', (_req, res) => {
    res.json({ skus: d.store.wishlists.get(session(res).customerId) ?? [] });
  });

  authed.put('/me/wishlist', (req, res) => {
    const skus = z.array(z.string()).max(200).parse(req.body?.skus);
    d.store.wishlists.set(session(res).customerId, skus);
    res.json({ skus });
  });

  authed.post(
    '/cart/quote',
    h(async (req, res) => {
      const body = z.object({ items: z.array(lineSchema), couponCode: z.string().nullish(), payment: paymentSchema.optional() }).parse(req.body);
      res.json(await d.commerce.quote(body.items, body.couponCode, body.payment, session(res).contactId));
    }),
  );

  authed.post(
    '/orders',
    h(async (req, res) => {
      const body = z
        .object({ items: z.array(lineSchema).min(1), couponCode: z.string().nullish(), addressId: z.string().optional(), payment: paymentSchema })
        .parse(req.body);
      res.status(201).json(await d.commerce.placeOrder(await customerOf(res), body));
    }),
  );

  authed.get(
    '/orders',
    h(async (_req, res) => res.json({ orders: await d.commerce.orders(session(res).contactId) })),
  );

  authed.get(
    '/orders/:id',
    h(async (req, res) => res.json({ order: await d.commerce.order(session(res).contactId, String(req.params.id)) })),
  );

  authed.post(
    '/orders/:id/pay',
    h(async (req, res) => res.json({ payUrl: await d.commerce.retryPayment(await customerOf(res), String(req.params.id)) })),
  );

  const sendInvoice = async (res: Response, contactId: string, salesOrderId: string) => {
    const pdf = (await d.commerce.invoicePdf(contactId, salesOrderId)) as globalThis.Response;
    res.set('Content-Type', 'application/pdf').set('Content-Disposition', `inline; filename="gowri-invoice-${salesOrderId}.pdf"`);
    res.send(Buffer.from(await pdf.arrayBuffer()));
  };

  authed.get(
    '/orders/:id/invoice',
    h(async (req, res) => sendInvoice(res, session(res).contactId, String(req.params.id))),
  );

  // A 5-minute signed link so the app can open the PDF in the system viewer without exposing its session token.
  authed.post(
    '/orders/:id/invoice-link',
    h(async (req, res) => {
      const id = String(req.params.id);
      await d.commerce.order(session(res).contactId, id); // ownership check
      const t = await d.sessions.signLink({ contactId: session(res).contactId, salesOrderId: id });
      res.json({ url: `${d.cfg.publicBaseUrl}/invoices/${encodeURIComponent(t)}` });
    }),
  );

  authed.post(
    '/orders/:id/returns',
    h(async (req, res) => {
      const body = z.object({ skus: z.array(z.string()).min(1), reason: z.string().min(2).max(200) }).parse(req.body);
      res.status(201).json(await d.commerce.requestReturn(session(res).contactId, String(req.params.id), body.skus, body.reason));
    }),
  );

  app.use('/v1', authed);

  // ── Hosted payment page (opened in the app's WebView) ───────────────
  app.get('/pay/:id', (req, res) => {
    const pending = d.commerce.pendingPayment(String(req.params.id));
    if (!pending || pending.settled) return res.status(404).send(resultPage(!!pending?.settled));
    const phone = [...d.store.customersByPhone.values()].find((c) => c.contactId === pending.customerId)?.phone ?? '';
    res.type('html').send(
      paymentPage({
        salesOrderId: pending.salesOrderId,
        orderRef: pending.orderRef,
        amount: pending.amount,
        sessionId: pending.sessionId,
        accountId: d.cfg.payments.accountId,
        apiKey: d.cfg.payments.apiKey,
        phone,
      }),
    );
  });

  app.get(
    '/pay/:id/return',
    h(async (req, res) => {
      const id = String(req.params.id);
      const paymentId = typeof req.query.payment_id === 'string' ? req.query.payment_id : '';
      const ok = paymentId ? await d.commerce.settlePayment(id, paymentId) : false;
      // The app watches for this URL to close the WebView.
      res.redirect(`/pay/${id}/done?status=${ok ? 'success' : req.query.status === 'cancelled' ? 'cancelled' : 'failed'}`);
    }),
  );

  app.get(
    '/invoices/:token',
    h(async (req, res) => {
      const link = await d.sessions.verifyLink(String(req.params.token)).catch(() => null);
      if (!link) return res.status(410).send('This invoice link has expired. Open it again from the Gowri app.');
      await sendInvoice(res, link.contactId, link.salesOrderId);
    }),
  );

  app.get('/pay/:id/done', (req, res) => res.type('html').send(resultPage(req.query.status === 'success')));

  // ── Errors ──────────────────────────────────────────────────────────
  app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (err instanceof z.ZodError) return res.status(400).json({ error: err.issues[0]?.message ?? 'Invalid request' });
    if (err instanceof OtpError) return res.status(429).json({ error: err.message });
    if (err instanceof CommerceError) return res.status(err.status).json({ error: err.message });
    if (err instanceof ZohoError) {
      console.error('[zoho]', err.status, err.code, err.message);
      return res.status(502).json({ error: "We couldn't reach our store system. Please try again in a moment." });
    }
    console.error(err);
    res.status(500).json({ error: 'Something went wrong on our side.' });
  });

  return app;
}
