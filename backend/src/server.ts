import { config, missingPidgeSettings, missingZohoSettings } from './config.js';
import { PidgeClient } from './delivery/pidge.js';
import { OtpService, smsSender } from './auth/otp.js';
import { Sessions } from './auth/session.js';
import { createApp } from './app.js';
import { Catalog } from './domain/catalog.js';
import { Commerce, loadCoupons } from './domain/commerce.js';
import { Store } from './store.js';
import { ZohoAuth, ZohoClient } from './zoho/client.js';
import { InventoryApi } from './zoho/inventory.js';
import { PaymentsApi } from './zoho/payments.js';

const missing = [...missingZohoSettings(), ...missingPidgeSettings()];
if (missing.length) {
  console.error(`Missing settings: ${missing.join(', ')}. See backend/.env.example.`);
  process.exit(1);
}
if (config.jwtSecret === 'dev-only-secret-change-me' && process.env.NODE_ENV === 'production') {
  console.error('Set JWT_SECRET before running in production.');
  process.exit(1);
}

const auth = new ZohoAuth(config.zoho);
const inventoryClient = new ZohoClient(config.zoho.apiUrl, auth, { organization_id: config.zoho.organizationId });
const paymentsClient = new ZohoClient(config.payments.url, auth, { account_id: config.payments.accountId });
const inventory = new InventoryApi(inventoryClient);
const payments = new PaymentsApi(paymentsClient, config.payments.accountId);
const store = new Store();
const catalog = new Catalog(inventory, config.zoho, config.publicBaseUrl, config.catalogCacheSeconds * 1000);
const pidge = new PidgeClient(config.pidge);
const commerce = new Commerce(config, store, catalog, inventory, payments, loadCoupons(), pidge.enabled ? pidge : null);

const app = createApp({
  cfg: config,
  store,
  otp: new OtpService(store, smsSender(config.otp)),
  sessions: new Sessions(config.jwtSecret),
  commerce,
  inventoryImage: (id) => inventory.itemImage(id),
  verifyPidgeWebhook: (t) => pidge.verifyWebhook(t),
});

app.listen(config.port, () => console.log(`Gowri backend on :${config.port} (Zoho org ${config.zoho.organizationId}, Pidge ${pidge.enabled ? 'on' : 'off'})`));
