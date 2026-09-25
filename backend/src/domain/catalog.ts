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

/** Maps a Zoho Inventory item to the app's Product. Returns null for items the app should not sell. */
export function toProduct(item: ZohoItem, cfg: Config['zoho'], publicBaseUrl: string): Product | null {
  if (!item.sku || (item.status && item.status !== 'active')) return null;
  const category = item.category_name || item.group_name || 'Other';
  if (cfg.sellableCategories.length && !cfg.sellableCategories.includes(category)) return null;
  const price = Number(item.rate) || 0;
  const mrp = Number(cf(item, cfg.cf.mrp)) || price;
  const stock = Math.max(0, Math.floor(item.actual_available_stock ?? item.available_stock ?? item.stock_on_hand ?? 0));
  const primaryWh = item.warehouses?.find((w) => w.is_primary)?.warehouse_name;
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
    gst: item.is_taxable === false ? 0 : Number(item.tax_percentage ?? 0),
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
    const bySku = new Map<string, Product>();
    for (const it of items) {
      const p = toProduct(it, this.cfg, this.publicBaseUrl);
      if (p) bySku.set(p.sku, p);
    }
    this.cache = { at: Date.now(), bySku };
    return bySku;
  }
}
