import type { Config } from '../config.js';

export class ZohoError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code?: number,
  ) {
    super(message);
  }
}

type FetchFn = typeof fetch;

/**
 * Holds a Zoho OAuth access token minted from the long-lived refresh token.
 * Access tokens last one hour; we refresh a minute early and share one
 * in-flight refresh across concurrent requests.
 */
export class ZohoAuth {
  private token: string | null = null;
  private expiresAt = 0;
  private pending: Promise<string> | null = null;

  constructor(
    private readonly cfg: Config['zoho'],
    private readonly fetchFn: FetchFn = fetch,
  ) {}

  async accessToken(): Promise<string> {
    if (this.token && Date.now() < this.expiresAt - 60_000) return this.token;
    this.pending ??= this.refresh().finally(() => {
      this.pending = null;
    });
    return this.pending;
  }

  invalidate() {
    this.token = null;
  }

  private async refresh(): Promise<string> {
    const form = new URLSearchParams({
      refresh_token: this.cfg.refreshToken,
      client_id: this.cfg.clientId,
      client_secret: this.cfg.clientSecret,
      grant_type: 'refresh_token',
    });
    const endpoint = `${this.cfg.accountsUrl.replace(/\/$/, '')}/oauth/v2/token`;
    let res: Response;
    try {
      res = await this.fetchFn(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json', 'User-Agent': 'gowri-backend/1.0' },
        body: form.toString(),
      });
    } catch (e) {
      throw new ZohoError(`Zoho token endpoint unreachable (${endpoint}): ${(e as Error).message}`, 502);
    }
    const text = await res.text();
    let body: { access_token?: string; expires_in?: number; error?: string } = {};
    try {
      body = JSON.parse(text);
    } catch {
      const title = text.match(/<title>([^<]*)<\/title>/i)?.[1]?.trim();
      throw new ZohoError(
        `Zoho token endpoint ${endpoint} returned HTML (HTTP ${res.status}${title ? `, page "${title}"` : ''}): ${text.replace(/\s+/g, ' ').slice(0, 200)}`,
        502,
      );
    }
    if (!res.ok || !body.access_token) {
      const hint =
        body.error === 'invalid_client'
          ? ' (check ZOHO_CLIENT_ID / ZOHO_CLIENT_SECRET and that ZOHO_ACCOUNTS_URL matches your data centre, e.g. accounts.zoho.in)'
          : body.error === 'invalid_code'
            ? ' (ZOHO_REFRESH_TOKEN is wrong or was revoked; generate a new one)'
            : '';
      throw new ZohoError(`Zoho token refresh failed: ${body.error ?? `HTTP ${res.status}`}${hint}`, 502);
    }
    this.token = body.access_token;
    this.expiresAt = Date.now() + (body.expires_in ?? 3600) * 1000;
    return this.token;
  }
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  query?: Record<string, string | number | undefined>;
  body?: unknown;
  /** Return the raw Response (used for PDFs and images). */
  raw?: boolean;
}

/**
 * Minimal Zoho REST client: adds the OAuth header and organization_id,
 * retries once on an expired token and backs off on 429 rate limits.
 */
export class ZohoClient {
  constructor(
    private readonly baseUrl: string,
    private readonly auth: ZohoAuth,
    private readonly orgParam: Record<string, string>,
    private readonly fetchFn: FetchFn = fetch,
  ) {}

  async request<T = any>(path: string, opts: RequestOptions = {}): Promise<T> {
    let url: URL;
    try {
      url = new URL(this.baseUrl + path);
    } catch {
      throw new ZohoError(`Invalid Zoho base URL "${this.baseUrl}"; check ZOHO_API_URL / ZOHO_PAYMENTS_URL`, 502);
    }
    for (const [k, v] of Object.entries({ ...this.orgParam, ...opts.query })) {
      if (v !== undefined && v !== '') url.searchParams.set(k, String(v));
    }
    for (let attempt = 0; ; attempt++) {
      const token = await this.auth.accessToken();
      let res: Response;
      try {
        res = await this.fetchFn(url, {
          method: opts.method ?? 'GET',
          headers: {
            Authorization: `Zoho-oauthtoken ${token}`,
            ...(opts.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
          },
          body: opts.body !== undefined ? JSON.stringify(opts.body) : undefined,
        });
      } catch (e) {
        throw new ZohoError(`Zoho ${path} unreachable: ${(e as Error).message}`, 502);
      }
      if (res.status === 401 && attempt === 0) {
        this.auth.invalidate();
        continue;
      }
      if (res.status === 429 && attempt < 3) {
        await new Promise((r) => setTimeout(r, 500 * 2 ** attempt));
        continue;
      }
      if (opts.raw) {
        if (!res.ok) throw new ZohoError(`Zoho ${path} failed`, res.status);
        return res as T;
      }
      const body = (await res.json().catch(() => ({}))) as { code?: number; message?: string };
      // Zoho returns HTTP 200 with a non-zero `code` for some business errors.
      if (!res.ok || (typeof body.code === 'number' && body.code !== 0)) {
        throw new ZohoError(`Zoho ${path}: ${body.message ?? `HTTP ${res.status}`}`, res.ok ? 422 : res.status, body.code);
      }
      return body as T;
    }
  }
}
