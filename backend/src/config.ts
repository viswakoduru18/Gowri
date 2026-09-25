function env(name: string, fallback = ''): string {
  return process.env[name] ?? fallback;
}

export const config = {
  port: Number(env('PORT', '8080')),
  publicBaseUrl: env('PUBLIC_BASE_URL', 'http://localhost:8080').replace(/\/$/, ''),
  jwtSecret: env('JWT_SECRET', 'dev-only-secret-change-me'),
  catalogCacheSeconds: Number(env('CATALOG_CACHE_SECONDS', '60')),
  zoho: {
    accountsUrl: env('ZOHO_ACCOUNTS_URL', 'https://accounts.zoho.in'),
    apiUrl: env('ZOHO_API_URL', 'https://www.zohoapis.in'),
    clientId: env('ZOHO_CLIENT_ID'),
    clientSecret: env('ZOHO_CLIENT_SECRET'),
    refreshToken: env('ZOHO_REFRESH_TOKEN'),
    organizationId: env('ZOHO_ORGANIZATION_ID'),
    warehouseLabel: env('ZOHO_WAREHOUSE_LABEL', 'Hyderabad'),
    sellableCategories: env('ZOHO_SELLABLE_CATEGORIES')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    cf: {
      mrp: env('ZOHO_CF_MRP', 'cf_mrp'),
      concern: env('ZOHO_CF_CONCERN', 'cf_concern'),
      packSize: env('ZOHO_CF_PACK_SIZE', 'cf_pack_size'),
      howToUse: env('ZOHO_CF_HOW_TO_USE', 'cf_how_to_use'),
      ingredients: env('ZOHO_CF_INGREDIENTS', 'cf_ingredients'),
      goodToKnow: env('ZOHO_CF_GOOD_TO_KNOW', 'cf_good_to_know'),
      bestSeller: env('ZOHO_CF_BEST_SELLER', 'cf_best_seller'),
      recommended: env('ZOHO_CF_RECOMMENDED', 'cf_recommended'),
    },
  },
  payments: {
    url: env('ZOHO_PAYMENTS_URL', 'https://payments.zoho.in'),
    accountId: env('ZOHO_PAYMENTS_ACCOUNT_ID'),
    apiKey: env('ZOHO_PAYMENTS_API_KEY'),
    webhookSecret: env('ZOHO_PAYMENTS_WEBHOOK_SECRET'),
  },
  pidge: {
    baseUrl: env('PIDGE_BASE_URL', 'https://api.pidge.in').replace(/\/$/, ''),
    loginPath: env('PIDGE_LOGIN_PATH', '/v1.0/store/channel/vendor/login'),
    createPath: env('PIDGE_CREATE_PATH', '/v1.0/store/channel/vendor/order'),
    statusPath: env('PIDGE_STATUS_PATH', '/v1.0/store/channel/vendor/order/:id'),
    username: env('PIDGE_USERNAME'),
    password: env('PIDGE_PASSWORD'),
    /** Static token, if Pidge issued one instead of username/password. */
    apiToken: env('PIDGE_API_TOKEN'),
    channel: env('PIDGE_CHANNEL', 'gowri-app'),
    /** Shared secret Pidge sends with status webhooks (x-pidge-token or Authorization header). */
    webhookToken: env('PIDGE_WEBHOOK_TOKEN'),
    pickup: {
      name: env('PIDGE_PICKUP_NAME', 'Gowri Warehouse'),
      mobile: env('PIDGE_PICKUP_MOBILE'),
      line: env('PIDGE_PICKUP_ADDRESS'),
      city: env('PIDGE_PICKUP_CITY', 'Hyderabad'),
      state: env('PIDGE_PICKUP_STATE', 'Telangana'),
      pincode: env('PIDGE_PICKUP_PINCODE'),
    },
  },
  otp: {
    provider: env('OTP_PROVIDER', 'console') as 'console' | 'msg91',
    msg91AuthKey: env('MSG91_AUTH_KEY'),
    msg91TemplateId: env('MSG91_TEMPLATE_ID'),
  },
};

export type Config = typeof config;

/** Lists the Zoho settings that are missing, so startup can fail loudly instead of at checkout. */
export function missingZohoSettings(c: Config = config): string[] {
  const required: [string, string][] = [
    ['ZOHO_CLIENT_ID', c.zoho.clientId],
    ['ZOHO_CLIENT_SECRET', c.zoho.clientSecret],
    ['ZOHO_REFRESH_TOKEN', c.zoho.refreshToken],
    ['ZOHO_ORGANIZATION_ID', c.zoho.organizationId],
    ['ZOHO_PAYMENTS_ACCOUNT_ID', c.payments.accountId],
    ['ZOHO_PAYMENTS_API_KEY', c.payments.apiKey],
  ];
  return required.filter(([, v]) => !v).map(([k]) => k);
}

/** Pidge is optional at startup, but if credentials are set the pickup details must be too. */
export function missingPidgeSettings(c: Config = config): string[] {
  if (!c.pidge.username && !c.pidge.apiToken) return [];
  const required: [string, string][] = [
    ['PIDGE_PICKUP_MOBILE', c.pidge.pickup.mobile],
    ['PIDGE_PICKUP_ADDRESS', c.pidge.pickup.line],
    ['PIDGE_PICKUP_PINCODE', c.pidge.pickup.pincode],
    ['PIDGE_WEBHOOK_TOKEN', c.pidge.webhookToken],
  ];
  return required.filter(([, v]) => !v).map(([k]) => k);
}
