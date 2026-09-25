const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c] as string);

/**
 * Hosted checkout page the app opens in a WebView. It loads the Zoho Payments
 * checkout widget for an existing payment session, then redirects to
 * /pay/:id/return with the payment id so the backend can verify it.
 */
export function paymentPage(p: { salesOrderId: string; orderRef: string; amount: number; sessionId: string; accountId: string; apiKey: string; phone: string }): string {
  const opts = {
    amount: p.amount.toFixed(2),
    currency_code: 'INR',
    currency_symbol: '₹',
    payments_session_id: p.sessionId,
    business: 'Gowri',
    description: `Order ${p.orderRef}`,
    address: { phone: p.phone },
  };
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pay · Gowri</title>
<style>body{margin:0;font-family:system-ui,sans-serif;background:#FBF8F3;color:#2B1F27;display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center}
.c{padding:24px}.a{font-size:28px;font-weight:700;margin:8px 0}.m{color:#7a6c75;font-size:14px}</style>
<script src="https://static.zohocdn.com/zpay/zpay-js/v1/zpayments.js"></script></head>
<body><div class="c"><div class="m">Gowri · order ${esc(p.orderRef)}</div><div class="a">₹${p.amount}</div><div class="m" id="s">Opening secure checkout…</div></div>
<script>
(async function(){
  var ret = ${JSON.stringify(`/pay/${p.salesOrderId}/return`)};
  try {
    var zp = new window.ZPayments({ account_id: ${JSON.stringify(p.accountId)}, domain: 'IN', otherOptions: { api_key: ${JSON.stringify(p.apiKey)} } });
    var data = await zp.requestPaymentMethod(${JSON.stringify(opts)});
    location.replace(ret + '?payment_id=' + encodeURIComponent(data.payment_id));
  } catch (e) {
    location.replace(ret + '?status=' + (e && e.code === 'widget_closed' ? 'cancelled' : 'failed'));
  }
})();
</script></body></html>`;
}

export function resultPage(ok: boolean): string {
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Gowri</title></head>
<body style="font-family:system-ui;background:#FBF8F3;color:#2B1F27;display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center">
<div><div style="font-size:22px;font-weight:600">${ok ? 'Payment received' : 'Payment not completed'}</div><div style="color:#7a6c75;margin-top:8px">You can return to the Gowri app.</div></div></body></html>`;
}
