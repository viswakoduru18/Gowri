import type { ZohoClient } from './client.js';

// Thin, typed wrappers over the Zoho Inventory v1 endpoints the app needs.
// Zoho Inventory and Zoho Books share one organization, so invoices raised in
// either product are readable here.

export interface ZohoCustomField {
  api_name?: string;
  customfield_id?: string;
  label?: string;
  value?: unknown;
}

export interface ZohoItem {
  item_id: string;
  name: string;
  sku?: string;
  rate: number;
  status?: string;
  description?: string;
  unit?: string;
  tax_percentage?: number;
  is_taxable?: boolean;
  /** India GST: separate intra-state (CGST+SGST) and inter-state (IGST) rates. */
  item_tax_preferences?: { tax_specification?: string; tax_percentage?: number }[];
  intra_state_tax_rate?: number;
  inter_state_tax_rate?: number;
  stock_on_hand?: number;
  available_stock?: number;
  actual_available_stock?: number;
  category_name?: string;
  group_name?: string;
  image_name?: string;
  image_document_id?: string;
  custom_fields?: ZohoCustomField[];
  warehouses?: ({ warehouse_name: string; is_primary?: boolean } & Record<string, unknown>)[];
  locations?: ({ location_name?: string; is_primary?: boolean } & Record<string, unknown>)[];
}

export interface ZohoLineItem {
  line_item_id?: string;
  item_id: string;
  sku?: string;
  name?: string;
  rate: number;
  quantity: number;
  item_total?: number;
}

export interface ZohoPackage {
  package_id: string;
  status?: string; // not_shipped | shipped | delivered
  shipment_id?: string;
  shipment_status?: string;
  shipment_date?: string;
  delivery_method?: string;
  tracking_number?: string;
  carrier?: string;
}

export interface ZohoSalesOrder {
  salesorder_id: string;
  salesorder_number: string;
  reference_number?: string;
  date: string;
  status: string; // draft | confirmed | closed | void | onhold
  shipped_status?: string; // pending | partially_shipped | shipped | fulfilled
  order_status?: string;
  paid_status?: string;
  invoiced_status?: string;
  total: number;
  shipment_date?: string;
  customer_id: string;
  line_items: ZohoLineItem[];
  packages?: ZohoPackage[];
  invoices?: { invoice_id: string; invoice_number: string; status: string }[];
  custom_fields?: ZohoCustomField[];
  notes?: string;
  customer_name?: string;
  shipping_address?: ZohoAddress;
  contact_persons_details?: { mobile?: string; phone?: string }[];
}

export interface ZohoContactPerson {
  contact_person_id: string;
  first_name?: string;
  last_name?: string;
  email?: string;
  mobile?: string;
  is_primary_contact?: boolean;
}

export interface ZohoContact {
  contact_id: string;
  contact_name: string;
  email?: string;
  contact_persons?: ZohoContactPerson[];
  mobile?: string;
  phone?: string;
  created_time?: string;
  shipping_address?: ZohoAddress;
  billing_address?: ZohoAddress;
}

export interface ZohoAddress {
  address_id?: string;
  attention?: string;
  address?: string;
  street2?: string;
  city?: string;
  state?: string;
  zip?: string;
  country?: string;
  phone?: string;
}

export class InventoryApi {
  constructor(private readonly zoho: ZohoClient) {}

  /** All active items, following Zoho's 200-per-page pagination. */
  async listItems(): Promise<ZohoItem[]> {
    const out: ZohoItem[] = [];
    for (let page = 1; page < 50; page++) {
      const res = await this.zoho.request<{ items: ZohoItem[]; page_context?: { has_more_page?: boolean } }>(
        '/inventory/v1/items',
        { query: { page, per_page: 200, filter_by: 'Status.Active' } },
      );
      out.push(...(res.items ?? []));
      if (!res.page_context?.has_more_page) break;
    }
    return out;
  }

  async getItem(itemId: string): Promise<ZohoItem> {
    return (await this.zoho.request<{ item: ZohoItem }>(`/inventory/v1/items/${itemId}`)).item;
  }

  itemImage(itemId: string): Promise<Response> {
    return this.zoho.request<Response>(`/inventory/v1/items/${itemId}/image`, { raw: true });
  }

  async findContactByPhone(phone: string): Promise<ZohoContact | null> {
    const res = await this.zoho.request<{ contacts: ZohoContact[] }>('/inventory/v1/contacts', {
      query: { search_text: phone, filter_by: 'Status.Active' },
    });
    const digits = (s?: string) => (s ?? '').replace(/\D/g, '').slice(-10);
    return res.contacts.find((c) => digits(c.mobile) === phone || digits(c.phone) === phone) ?? null;
  }

  async createContact(name: string, phone: string): Promise<ZohoContact> {
    const res = await this.zoho.request<{ contact: ZohoContact }>('/inventory/v1/contacts', {
      method: 'POST',
      body: {
        contact_name: name || `Gowri customer ${phone.slice(-4)}`,
        contact_type: 'customer',
        customer_sub_type: 'individual',
        // Zoho India needs a GST treatment before a Sales Order can be invoiced.
        gst_treatment: 'consumer',
        mobile: phone,
        notes: 'Created by the Gowri mobile app',
      },
    });
    return res.contact;
  }

  async updateContact(contactId: string, body: Record<string, unknown>): Promise<ZohoContact> {
    return (await this.zoho.request<{ contact: ZohoContact }>(`/inventory/v1/contacts/${contactId}`, { method: 'PUT', body })).contact;
  }

  /** Sets the primary contact person's name/email (that email receives invoices). */
  async upsertPrimaryPerson(contactId: string, p: { first_name: string; last_name: string; email?: string; mobile: string }): Promise<void> {
    const contact = await this.getContact(contactId);
    const primary = contact.contact_persons?.find((c) => c.is_primary_contact) ?? contact.contact_persons?.[0];
    if (primary) {
      await this.zoho.request(`/inventory/v1/contacts/contactpersons/${primary.contact_person_id}`, {
        method: 'PUT',
        body: { contact_id: contactId, ...p },
      });
    } else {
      const res = await this.zoho.request<{ contact_person: ZohoContactPerson }>('/inventory/v1/contacts/contactpersons', {
        method: 'POST',
        body: { contact_id: contactId, ...p },
      });
      await this.zoho.request(`/inventory/v1/contacts/contactpersons/${res.contact_person.contact_person_id}/primary`, { method: 'POST' }).catch(() => {});
    }
  }

  async getContact(contactId: string): Promise<ZohoContact> {
    return (await this.zoho.request<{ contact: ZohoContact }>(`/inventory/v1/contacts/${contactId}`)).contact;
  }

  async addContactAddress(contactId: string, addr: ZohoAddress): Promise<ZohoAddress> {
    const res = await this.zoho.request<{ address_info: ZohoAddress }>(`/inventory/v1/contacts/${contactId}/address`, {
      method: 'POST',
      body: addr,
    });
    return res.address_info;
  }

  async listContactAddresses(contactId: string): Promise<ZohoAddress[]> {
    const res = await this.zoho.request<{ addresses: ZohoAddress[] }>(`/inventory/v1/contacts/${contactId}/address`);
    return res.addresses ?? [];
  }

  async createSalesOrder(body: {
    customer_id: string;
    reference_number: string;
    date: string;
    line_items: { item_id: string; quantity: number; rate: number }[];
    discount?: number;
    is_discount_before_tax?: boolean;
    discount_type?: 'entity_level';
    shipping_charge?: number;
    adjustment?: number;
    adjustment_description?: string;
    shipping_address_id?: string;
    billing_address_id?: string;
    place_of_supply?: string;
    gst_treatment?: string;
    is_inclusive_tax?: boolean;
    notes?: string;
  }): Promise<ZohoSalesOrder> {
    const res = await this.zoho.request<{ salesorder: ZohoSalesOrder }>('/inventory/v1/salesorders', {
      method: 'POST',
      body,
    });
    return res.salesorder;
  }

  async getSalesOrder(id: string): Promise<ZohoSalesOrder> {
    return (await this.zoho.request<{ salesorder: ZohoSalesOrder }>(`/inventory/v1/salesorders/${id}`)).salesorder;
  }

  async listSalesOrders(customerId: string): Promise<ZohoSalesOrder[]> {
    const res = await this.zoho.request<{ salesorders: ZohoSalesOrder[] }>('/inventory/v1/salesorders', {
      query: { customer_id: customerId, sort_column: 'date', sort_order: 'D', per_page: 50 },
    });
    return res.salesorders;
  }

  async markSalesOrder(id: string, status: 'confirmed' | 'void'): Promise<void> {
    await this.zoho.request(`/inventory/v1/salesorders/${id}/status/${status}`, { method: 'POST' });
  }

  async updateSalesOrderNotes(id: string, notes: string): Promise<void> {
    await this.zoho.request(`/inventory/v1/salesorders/${id}`, { method: 'PUT', body: { notes } });
  }

  invoicePdf(invoiceId: string): Promise<Response> {
    return this.zoho.request<Response>(`/inventory/v1/invoices/${invoiceId}`, { query: { accept: 'pdf' }, raw: true });
  }

  async createSalesReturn(
    salesOrderId: string,
    lineItems: { item_id: string; salesorder_item_id: string; quantity: number }[],
    reason: string,
  ): Promise<{ salesreturn_id: string; salesreturn_number: string }> {
    const res = await this.zoho.request<{ salesreturn: { salesreturn_id: string; salesreturn_number: string } }>(
      '/inventory/v1/salesreturns',
      {
        method: 'POST',
        query: { salesorder_id: salesOrderId },
        body: { date: new Date().toISOString().slice(0, 10), reason, line_items: lineItems },
      },
    );
    return res.salesreturn;
  }
}
