enum TransactionType {
  cafe,
  merchandise,
  session,
  credit,
  tournamentRegistration,
}

class SalesTransaction {
  final String id;
  final TransactionType type;
  final DateTime date;
  final double total;
  final double paidTotal;
  final String paymentMethod;
  final String description;
  final List<TransactionItem> items;
  final String? customerId;
  final String? customerName;

  // For session transactions, these will be populated.
  final double creditsUsed;
  final double tableCharges;
  final double cafeCharges;
  final double merchandiseCharges;
  final double tournamentCharges;

  SalesTransaction({
    required this.id,
    required this.type,
    required this.date,
    required this.total,
    double? paidTotal,
    required this.paymentMethod,
    required this.description,
    this.items = const [],
    this.customerId,
    this.customerName,
    this.creditsUsed = 0.0,
    this.tableCharges = 0.0,
    this.cafeCharges = 0.0,
    this.merchandiseCharges = 0.0,
    this.tournamentCharges = 0.0,
  }) : paidTotal = paidTotal ?? total;

  SalesTransaction copyWith({
    String? id,
    TransactionType? type,
    DateTime? date,
    double? total,
    double? paidTotal,
    String? paymentMethod,
    String? description,
    List<TransactionItem>? items,
    String? customerId,
    String? customerName,
    double? creditsUsed,
    double? tableCharges,
    double? cafeCharges,
    double? merchandiseCharges,
    double? tournamentCharges,
  }) {
    return SalesTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      date: date ?? this.date,
      total: total ?? this.total,
      paidTotal: paidTotal ?? this.paidTotal,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      description: description ?? this.description,
      items: items ?? this.items,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      creditsUsed: creditsUsed ?? this.creditsUsed,
      tableCharges: tableCharges ?? this.tableCharges,
      cafeCharges: cafeCharges ?? this.cafeCharges,
      merchandiseCharges: merchandiseCharges ?? this.merchandiseCharges,
      tournamentCharges: tournamentCharges ?? this.tournamentCharges,
    );
  }
}

class TransactionItem {
  final String name;
  final int quantity;
  final double price;

  TransactionItem({
    required this.name,
    required this.quantity,
    required this.price,
  });
}

class CreditSummary {
  /// Total worth of credits sold (manual top-ups paid via cash/upi)
  final double totalCreditsSold;

  /// Total worth of credits allotted (from memberships, promotions)
  final double totalCreditsAllotted;

  /// Gross credits spent by customers (before refunds)
  final double grossCreditsSpent;

  /// Total credits refunded to customers
  final double totalCreditsRefunded;

  /// Net credits spent by customers (gross - refunded)
  double get totalCreditsSpent => grossCreditsSpent - totalCreditsRefunded;

  /// Current credit balance across all customers
  final double totalCreditBalance;

  /// Number of top-up transactions
  final int topUpCount;

  /// Number of credit spend transactions
  final int spendCount;

  /// Number of credit refund transactions
  final int refundCount;

  const CreditSummary({
    this.totalCreditsSold = 0.0,
    this.totalCreditsAllotted = 0.0,
    this.grossCreditsSpent = 0.0,
    this.totalCreditsRefunded = 0.0,
    this.totalCreditBalance = 0.0,
    this.topUpCount = 0,
    this.spendCount = 0,
    this.refundCount = 0,
  });

  CreditSummary copyWith({
    double? totalCreditsSold,
    double? totalCreditsAllotted,
    double? grossCreditsSpent,
    double? totalCreditsRefunded,
    double? totalCreditBalance,
    int? topUpCount,
    int? spendCount,
    int? refundCount,
  }) {
    return CreditSummary(
      totalCreditsSold: totalCreditsSold ?? this.totalCreditsSold,
      totalCreditsAllotted: totalCreditsAllotted ?? this.totalCreditsAllotted,
      grossCreditsSpent: grossCreditsSpent ?? this.grossCreditsSpent,
      totalCreditsRefunded: totalCreditsRefunded ?? this.totalCreditsRefunded,
      totalCreditBalance: totalCreditBalance ?? this.totalCreditBalance,
      topUpCount: topUpCount ?? this.topUpCount,
      spendCount: spendCount ?? this.spendCount,
      refundCount: refundCount ?? this.refundCount,
    );
  }
}

class SalesDataSummary {
  final double totalRevenue;
  final int totalTransactions;
  final Map<String, double> revenueByType;
  final Map<String, double> paymentMethodTotals;
  final List<SalesTransaction> transactions;
  final CreditSummary creditSummary;
  final bool isLoading;
  final Object? error;

  SalesDataSummary({
    this.totalRevenue = 0.0,
    this.totalTransactions = 0,
    this.revenueByType = const {},
    this.paymentMethodTotals = const {},
    this.transactions = const [],
    this.creditSummary = const CreditSummary(),
    this.isLoading = true,
    this.error,
  });

  SalesDataSummary copyWith({
    double? totalRevenue,
    int? totalTransactions,
    Map<String, double>? revenueByType,
    Map<String, double>? paymentMethodTotals,
    List<SalesTransaction>? transactions,
    CreditSummary? creditSummary,
    bool? isLoading,
    Object? error,
  }) {
    return SalesDataSummary(
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      revenueByType: revenueByType ?? this.revenueByType,
      paymentMethodTotals: paymentMethodTotals ?? this.paymentMethodTotals,
      transactions: transactions ?? this.transactions,
      creditSummary: creditSummary ?? this.creditSummary,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
