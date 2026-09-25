// Zoho Books/Inventory (India) identifies GST place of supply by a short state code.
const STATE_CODES: Record<string, string> = {
  'andaman and nicobar islands': 'AN', 'andhra pradesh': 'AP', 'arunachal pradesh': 'AR', assam: 'AS', bihar: 'BR',
  chandigarh: 'CH', chhattisgarh: 'CG', 'dadra and nagar haveli and daman and diu': 'DN', 'daman and diu': 'DD',
  delhi: 'DL', 'new delhi': 'DL', goa: 'GA', gujarat: 'GJ', haryana: 'HR', 'himachal pradesh': 'HP',
  'jammu and kashmir': 'JK', jharkhand: 'JH', karnataka: 'KA', kerala: 'KL', ladakh: 'LA', lakshadweep: 'LD',
  'madhya pradesh': 'MP', maharashtra: 'MH', manipur: 'MN', meghalaya: 'ML', mizoram: 'MZ', nagaland: 'NL',
  odisha: 'OD', orissa: 'OD', puducherry: 'PY', pondicherry: 'PY', punjab: 'PB', rajasthan: 'RJ', sikkim: 'SK',
  'tamil nadu': 'TN', telangana: 'TS', tripura: 'TR', 'uttar pradesh': 'UP', uttarakhand: 'UK', 'west bengal': 'WB',
};

/** "Telangana" → "TS"; already-coded values pass through; unknown → undefined. */
export function stateCode(state?: string): string | undefined {
  if (!state) return undefined;
  const s = state.trim();
  if (/^[A-Z]{2}$/.test(s)) return s;
  return STATE_CODES[s.toLowerCase().replace(/&/g, 'and').replace(/\s+/g, ' ')];
}
