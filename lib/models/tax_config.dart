class TaxConfig {
  final String? taxId;
  final double taxRate;
  final String taxLabel;
  final String invoicePrefix;
  final bool taxEnabled;

  const TaxConfig({
    this.taxId,
    this.taxRate = 0,
    this.taxLabel = 'GST',
    this.invoicePrefix = 'INV',
    this.taxEnabled = false,
  });

  factory TaxConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const TaxConfig();
    return TaxConfig(
      taxId: data['taxId'] as String?,
      taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0,
      taxLabel: data['taxLabel'] as String? ?? 'GST',
      invoicePrefix: data['invoicePrefix'] as String? ?? 'INV',
      taxEnabled: data['taxEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (taxId != null) 'taxId': taxId,
      'taxRate': taxRate,
      'taxLabel': taxLabel,
      'invoicePrefix': invoicePrefix,
      'taxEnabled': taxEnabled,
    };
  }

  double calculateTax(double amount) {
    if (!taxEnabled || taxRate <= 0) return 0;
    return amount * taxRate / 100;
  }
}
