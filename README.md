# Gowri — D2C mobile app

Customer app for **mysaalife.com**: browse, buy and track wellness and personal-care products on iOS and Android.
**Zoho** is the system of record for products, stock, prices, customers, orders, invoices and payments. **Pidge** handles last-mile delivery.

```
┌──────────────┐  HTTPS/JSON   ┌───────────────────────┐   OAuth    ┌────────────────────────────────┐
│ Flutter app  │ ───────────▶  │  Gowri backend (Node) │ ─────────▶ │ Zoho Inventory · Books · Payments │
│ iOS + Android│ ◀───────────  │  backend/             │ ◀───────── │                                │
└──────────────┘               │  OTP, pricing, orders │   REST     └────────────────────────────────┘
        │  WebView (checkout)  │  payments, delivery   │ ─────────▶ ┌──────────────┐
        └─────────────────────▶│  /pay/:id             │ ◀───────── │ Pidge        │  (webhook: rider status)
                               └───────────────────────┘            └──────────────┘
```

The app never holds Zoho or Pidge credentials. Only the backend does.

| Folder | What it is |
|---|---|
| `app/` | Flutter app: all 12 screens from the design (login/OTP, home, shop/search, product, bag, checkout, payment, tracking, orders, wishlist, coupons, returns, profile) |
| `backend/` | Node 20+ / TypeScript API. The only component that talks to Zoho and Pidge |
| `project/` | The original Claude Design prototype (`Gowri App.dc.html`) and handoff notes |

---

## How each business flow maps to Zoho and Pidge

| In the app | What the backend does |
|---|---|
| Catalog, prices, "Only N left" / "Out of stock" | Reads **Zoho Inventory items** (rate, `actual_available_stock`, tax %, custom fields). Cached 60s |
| Product photos | Proxied from the Zoho item image |
| OTP login | Sends the SMS OTP (MSG91), then finds or creates the **Zoho contact** by mobile number |
| Saved addresses | Stored on the Zoho contact (`/contacts/{id}/address`) |
| Bag total, coupons, ₹49 delivery under ₹499, ₹30 COD fee | Priced on the server from **fresh** Zoho stock and price at checkout. The app's instant total follows the same rules |
| Place order | Creates a **Zoho Sales Order** (reference `GW-…`, coupon as discount, shipping charge, COD adjustment) |
| Pay by UPI, card, wallet or net banking | Creates a **Zoho Payments** session. The app opens the hosted checkout. The backend re-reads the payment from Zoho, checks amount and session, then **confirms the SO** (which commits stock). A webhook covers customers who close the app mid-payment |
| Cash on delivery | SO confirmed immediately |
| Rider pickup and delivery | On SO confirmation the backend books a **Pidge** trip from your warehouse to the customer, with cash to collect for COD. The Pidge ID is written into the SO notes |
| Order tracking | Stage = furthest of Zoho (SO → package → shipment) and Pidge status (rider assigned → picked up → out for delivery → delivered). Shows the rider's name and phone, plus a live tracking link |
| GST invoice | Opens the SO's **Zoho Books invoice** PDF through a 5-minute signed link. Available once invoiced |
| Returns | Creates a **Zoho sales return** against the SO. Your team issues the credit note on receipt |
| Order history, reorder | Zoho Sales Orders for that contact |

---

## Setup

### 1. Zoho (one-time, about 30 minutes)

1. **Item custom fields** (Inventory → Settings → Preferences → Items → Custom fields). Create these as text fields unless noted; the API names must match `backend/.env`:
   `cf_mrp` (number), `cf_concern` (e.g. "Sleep & Stress"), `cf_pack_size` ("200 ml"), `cf_how_to_use`, `cf_ingredients`, `cf_good_to_know`, `cf_best_seller` (checkbox), `cf_recommended` (checkbox).
   Item **Description** becomes "What it does". **Category** drives the Shop chips. The item **rate** is the selling price (GST-inclusive).
2. **Taxes**: make sure items carry GST and SOs are created **tax-inclusive** (the backend sends `is_inclusive_tax: true`). If Zoho's SO total differs from the app's quote by more than ₹1, the backend logs a warning.
3. **API client**: go to https://api-console.zoho.in → *Self Client* and generate a code with these scopes:
   `ZohoInventory.items.READ,ZohoInventory.contacts.ALL,ZohoInventory.salesorders.ALL,ZohoInventory.packages.READ,ZohoInventory.shipmentorders.READ,ZohoInventory.invoices.READ,ZohoInventory.salesreturns.CREATE,ZohoPay.payments.CREATE,ZohoPay.payments.READ`
   Exchange the code for a **refresh token**. Put the client ID, client secret, refresh token and organization ID into `backend/.env`.
4. **Zoho Payments**: copy the account ID and the publishable API key. Under Webhooks, add `<PUBLIC_BASE_URL>/webhooks/zoho-payments` and copy its signing key.

### 2. Pidge

Get API credentials (username/password or a token) and the API reference from your Pidge account manager. Then:
- Fill in the `PIDGE_*` settings in `backend/.env`, including the warehouse pickup address and phone.
- Give Pidge the webhook URL `<PUBLIC_BASE_URL>/webhooks/pidge` and the shared `PIDGE_WEBHOOK_TOKEN`.

If Pidge settings are left empty, orders still work and track from Zoho packages and shipments only.

### 3. Run the backend

```bash
cd backend
cp .env.example .env        # fill in Zoho, Zoho Payments, Pidge, MSG91, JWT_SECRET
npm install
npm test                    # 23 tests against simulated Zoho / Zoho Payments / Pidge
npm run dev                 # http://localhost:8080
```

Production on **Render**: `render.yaml` at the repo root is a ready Blueprint (Render → New → Blueprint → this repo). It builds `backend/`, runs it in Singapore, generates `JWT_SECRET`, and asks once for the Zoho/Payments/Pidge secrets.
Elsewhere: `npm run build && npm start` on any Node host (Render, Railway, AWS, GCP) behind HTTPS. Set `PUBLIC_BASE_URL` to the public URL, and set `NODE_ENV=production` so a missing `JWT_SECRET` blocks startup.

### 4. Run the app

Requires Flutter 3.47+ (Dart 3.13+).

```bash
cd app
flutter pub get
flutter test                                   # 9 tests, including a full login → order walkthrough
flutter run                                    # demo mode: built-in catalog, any 4-digit OTP
flutter run --dart-define=API_BASE_URL=https://api.yourdomain.com   # live Zoho via your backend
```

Build-time options (`--dart-define`):

| Key | Default | Meaning |
|---|---|---|
| `API_BASE_URL` | *(empty → demo data)* | Your backend URL |
| `HOME_LAYOUT` | `editorial` | `grid` switches Home to design option 1b (quick-commerce grid) |
| `LOW_STOCK_THRESHOLD` | `15` | "Only N left" threshold |
| `SUPPORT_WHATSAPP` | `91` | WhatsApp number for Help & support, e.g. `919876543210` |

### 5. Android builds (no local setup needed)

Every push to `main` that touches `app/` runs **GitHub Actions → Android build** (`.github/workflows/android.yml`). It runs the tests and builds the app pointed at `https://gowri-backend.onrender.com`.
Open the finished run on GitHub → **Artifacts** → `gowri-android-N` to download:
- `app-release.apk`: install directly on Android phones for testing
- `app-release.aab`: upload to Google Play Console

To rebuild on demand, or against another backend URL: **Actions → Android build → Run workflow**.
For Play Store signing, add repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`. Without them, builds are debug-signed (fine for testing, rejected by Play).

### 6. Local store builds

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.yourdomain.com   # Play Store (.aab)
flutter build ipa       --release --dart-define=API_BASE_URL=https://api.yourdomain.com   # App Store (needs a Mac + Xcode)
```

Bundle ID / application ID: `com.mysaalife.gowri`.

---

## Go-live checklist

- [ ] Zoho custom fields created and filled for every sellable item; product photos uploaded to Zoho items
- [ ] Backend deployed on HTTPS; `.env` complete; `npm test` green
- [ ] **Test one real ₹1 UPI payment and one COD order end to end in Zoho's sandbox/test mode.** The Zoho Payments widget call (`payment-page.ts`), webhook header name, and the Pidge endpoint paths and field names follow the vendors' published APIs but could not be exercised live from the build environment. Confirm them against your account's docs; all are isolated in `backend/src/zoho/payments.ts`, `backend/src/payment-page.ts` and `backend/src/delivery/pidge.ts`, and the Pidge paths are configurable via env
- [ ] MSG91 DLT-registered OTP template (`OTP_PROVIDER=msg91`)
- [ ] App icon and splash (replace `app/android/app/src/main/res/mipmap-*` and `app/ios/Runner/Assets.xcassets/AppIcon.appiconset`)
- [ ] Android release signing key (`app/android/key.properties`), Apple Developer account and certificates
- [ ] Privacy policy URL, and data-safety / App Privacy forms (phone number, address and order history are collected)
- [ ] Backend state (OTP codes, pending payments, Pidge bookings, wishlists) is in memory. That is fine for one server instance; move it to Redis or Postgres before running more than one

## Known gaps and deviations from the design

- **Tab bar icons** use Material icons instead of the prototype's placeholder glyphs (⌂ ☰ ▢ ◷ ◯), which render inconsistently on Android.
- **Address "Edit"** in Profile is replaced by "Use" (sets the default). Addresses can be added from Checkout and Profile; editing is not built yet.
- **Notifications** row removed: push notifications (order updates) are not implemented yet. The recommended next step is Firebase Cloud Messaging, triggered from the Pidge and Zoho Payments webhooks.
- **Customer name**: new customers are created in Zoho as "Gowri customer 1234" until a name-capture step is added, so the confirmation reads "Thank you!" instead of "Thank you, Ananya!".
- **Delivery ETA** is "SO shipment date, else order date + 2 days". Pidge's promised time can replace this once its field is confirmed.
- Prescription (Rx) products and subscriptions are out of scope.
