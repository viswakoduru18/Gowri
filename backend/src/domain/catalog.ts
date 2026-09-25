import type { Config } from '../config.js';
import type { InventoryApi, ZohoCustomField, ZohoItem } from '../zoho/inventory.js';
import type { Product } from '../types.js';

function cf(item: ZohoItem, apiName: string): unknown {
  const f: ZohoCustomField | undefined = item.custom_fields?.find(
    (c) => c.api_name === apiName || c.label?.toLowerCase().replace(/\s+/g, '_') === apiName.replace(/^cf_/, ''),
  );
  // List responses flatten custom fields to top-level `cf_*` keys; detail responses use custom_fields[].
  return f?.value ?? (item as unknown as Record<string, unknown>)[apiName];
}

const truthy = (v: unknown) => v === true || v === 'true' || v === 'Yes' || v === 'yes';

const num = (v: unknown) => (typeof v === 'number' ? v : typeof v === 'string' && v.trim() !== '' ? Number(v) : NaN);

/**
 * Sellable units. Organisations using warehouses/locations can report 0 in the
 * item-level summary while the stock sits in a location, so location totals are
 * used when the summary is empty. Committed-aware figures are preferred.
 */
export function stockOf(item: ZohoItem): number {
  const summary = [item.actual_available_stock, item.available_stock, item.stock_on_hand].map(num).find((n) => Number.isFinite(n) && n > 0);
  if (summary !== undefined) return Math.floor(summary);
  const sites = [...(item.locations ?? []), ...(item.warehouses ?? [])];
  const pick = (s: Record<string, unknown>) =>
    [
      'location_actual_available_for_sale_stock', 'location_available_for_sale_stock', 'location_actual_available_stock',
      'location_available_stock', 'location_stock_on_hand', 'warehouse_actual_available_for_sale_stock',
      'warehouse_available_for_sale_stock', 'warehouse_actual_available_stock', 'warehouse_available_stock', 'warehouse_stock_on_hand',
    ]
      .map((k) => num(s[k]))
      .find((n) => Number.isFinite(n)) ?? 0;
  const total = sites.reduce((a, s) => a + Math.max(0, pick(s)), 0);
  return Math.max(0, Math.floor(total));
}

/** GST % for an item. Zoho India keeps it in item_tax_preferences rather than tax_percentage. */
export function gstRate(item: ZohoItem): number {
  if (item.is_taxable === false) return 0;
  const prefs = item.item_tax_preferences ?? [];
  const pref = prefs.find((p) => p.tax_specification === 'intra') ?? prefs.find((p) => p.tax_specification === 'inter') ?? prefs[0];
  return Number(pref?.tax_percentage ?? item.intra_state_tax_rate ?? item.inter_state_tax_rate ?? item.tax_percentage ?? 0) || 0;
}

/** Maps a Zoho Inventory item to the app's Product. Returns null for items the app should not sell. */
export function toProduct(item: ZohoItem, cfg: Config['zoho'], publicBaseUrl: string): Product | null {
  if (!item.sku || (item.status && item.status !== 'active')) return null;
  const category = item.category_name || item.group_name || 'Other';
  if (cfg.sellableCategories.length && !cfg.sellableCategories.includes(category)) return null;
  const price = Number(item.rate) || 0;
  const mrp = Number(cf(item, cfg.cf.mrp)) || price;
  const stock = stockOf(item);
  const primaryWh = item.warehouses?.find((w) => w.is_primary)?.warehouse_name ?? (item.locations?.find((l) => l.is_primary)?.location_name as string | undefined);
  const sections = [
    ['What it does', item.description],
    ['How to use', cf(item, cfg.cf.howToUse)],
    ['Ingredients', cf(item, cfg.cf.ingredients)],
    ['Good to know', cf(item, cfg.cf.goodToKnow)],
  ]
    .filter(([, body]) => typeof body === 'string' && body.trim())
    .map(([title, body]) => ({ title: title as string, body: (body as string).trim() }));
  return {
    sku: item.sku,
    itemId: item.item_id,
    name: item.name,
    size: String(cf(item, cfg.cf.packSize) ?? item.unit ?? ''),
    mrp: Math.max(mrp, price),
    price,
    gst: gstRate(item),
    stock,
    category,
    concern: String(cf(item, cfg.cf.concern) ?? ''),
    warehouse: primaryWh ?? cfg.warehouseLabel,
    best: truthy(cf(item, cfg.cf.bestSeller)),
    rec: truthy(cf(item, cfg.cf.recommended)),
    imageUrl: item.image_name || item.image_document_id ? `${publicBaseUrl}/v1/catalog/products/${encodeURIComponent(item.sku)}/image` : null,
    sections,
  };
}

/**
 * Catalog read-through cache. Prices and stock stay "live" to within
 * CATALOG_CACHE_SECONDS; checkout always re-reads the items it sells.
 */
export class Catalog {
  private cache: { at: number; bySku: Map<string, Product> } | null = null;
  private pending: Promise<Map<string, Product>> | null = null;

  constructor(
    private readonly inventory: InventoryApi,
    private readonly cfg: Config['zoho'],
    private readonly publicBaseUrl: string,
    private readonly ttlMs: number,
  ) {}

  async all(): Promise<Map<string, Product>> {
    if (this.cache && Date.now() - this.cache.at < this.ttlMs) return this.cache.bySku;
    this.pending ??= this.load().finally(() => {
      this.pending = null;
    });
    return this.pending;
  }

  /** Fresh stock and price for specific SKUs, bypassing the cache (used at checkout). */
  async fresh(skus: string[]): Promise<Map<string, Product>> {
    const cached = await this.all();
    const out = new Map<string, Product>();
    await Promise.all(
      skus.map(async (sku) => {
        const p = cached.get(sku);
        if (!p) return;
        const item = await this.inventory.getItem(p.itemId);
        const fresh = toProduct(item, this.cfg, this.publicBaseUrl);
        if (fresh) {
          out.set(sku, fresh);
          cached.set(sku, fresh);
        }
      }),
    );
    return out;
  }

  invalidate() {
    this.cache = null;
  }

  private async load(): Promise<Map<string, Product>> {
    const items = await this.inventory.listItems();
    // List responses omit per-location stock; re-read zero-stock items (5 at a time) to check locations.
    const zero = items.filter((it) => it.sku && stockOf(it) === 0);
    for (let i = 0; i < zero.length && i < 100; i += 5) {
      await Promise.all(
        zero.slice(i, i + 5).map(async (it) => {
          try {
            const detail = await this.inventory.getItem(it.item_id);
            Object.assign(it, { locations: detail.locations, warehouses: detail.warehouses });
            for (const k of ['actual_available_stock', 'available_stock', 'stock_on_hand'] as const) if (detail[k] !== undefined) it[k] = detail[k];
            if (i === 0 && it === zero[0]) {
              const raw = { summary: [detail.actual_available_stock, detail.available_stock, detail.stock_on_hand], locations: detail.locations ?? detail.warehouses ?? null };
              console.log(`[catalog] stock fields for "${it.name}": ${JSON.stringify(raw).slice(0, 600)}`);
            }
          } catch (e) {
            console.warn(`[catalog] could not re-read stock for ${it.name}: ${(e as Error).message}`);
          }
        }),
      );
    }
    const bySku = new Map<string, Product>();
    let skipped = 0;
    for (const it of items) {
      try {
        const p = toProduct(it, this.cfg, this.publicBaseUrl);
        if (p && bySku.has(p.sku)) {
          // Same SKU on two Zoho items: keep both, disambiguated by Zoho item id.
          const key = `${p.sku} #${p.itemId.slice(-4)}`;
          console.warn(`[catalog] duplicate SKU "${p.sku}" on "${p.name}"; listed as "${key}"`);
          bySku.set(key, { ...p, sku: key, imageUrl: p.imageUrl && `${this.publicBaseUrl}/v1/catalog/products/${encodeURIComponent(key)}/image` });
        } else if (p) bySku.set(p.sku, p);
        else skipped++;
      } catch (e) {
        // One malformed item must not take the whole catalog down.
        skipped++;
        console.warn(`[catalog] skipped item ${it?.item_id} (${it?.name}): ${(e as Error).message}`);
      }
    }
    console.log(`[catalog] ${items.length} Zoho items → ${bySku.size} sellable (${skipped} skipped: inactive, no SKU, or not in ZOHO_SELLABLE_CATEGORIES)`);
    this.cache = { at: Date.now(), bySku };
    return bySku;
  }
}
