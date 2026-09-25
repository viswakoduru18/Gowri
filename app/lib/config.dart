/// Build-time configuration, passed with --dart-define (see app/README.md).
class AppConfig {
  /// Gowri backend base URL, e.g. https://api.mysaalife.com. Empty = offline demo data.
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// "grid" selects the quick-commerce Home (design option 1b); default is "Shop by concern" (1a).
  static const homeLayout = String.fromEnvironment('HOME_LAYOUT', defaultValue: 'editorial');

  /// Items at or below this stock show "Only N left".
  static const lowStockThreshold = int.fromEnvironment('LOW_STOCK_THRESHOLD', defaultValue: 15);

  /// WhatsApp number for Help & support, with country code and no "+".
  static const supportWhatsApp = String.fromEnvironment('SUPPORT_WHATSAPP', defaultValue: '91');

  static const websiteUrl = 'https://www.mysaalife.com';
}
