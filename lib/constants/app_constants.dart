abstract class AppConstants {
  // Pagination & Limits
  static const int defaultPageSize = 20;
  static const int sessionHistoryLimit = 500;
  static const int creditTransactionLimit = 500;
  static const int maxActiveSessionHours = 24;

  // Firestore Collections
  static const String tablesCollection = 'tables';
  static const String sessionsCollection = 'sessions';
  static const String customersCollection = 'customers';
  static const String cafeOrdersCollection = 'cafe_orders';
  static const String merchandiseOrdersCollection = 'merchandise_orders';
  static const String gameMatchesCollection = 'game_matches';
  static const String stockItemsCollection = 'stock_items';
  static const String creditTransactionsSubcollection = 'credit_transactions';
  static const String usersCollection = 'users';
  static const String categoriesCollection = 'categories';
  static const String salesTransactionsCollection = 'sales_transactions';

  // Session Configuration
  static const int overtimeThresholdHours = 3;
  static const int defaultMinimumBillableMinutes = 0;

  // Credit System
  static const double defaultCreditEarningRate = 1.0;
  static const int creditCodeLength = 6;
  static const double lowCreditAlertThreshold = 100.0;

  // PTL Mode
  static const int minPTLPlayers = 1;
  static const int maxPTLPlayers = 6;

  // UI Configuration
  static const Duration shortSnackbarDuration = Duration(seconds: 2);
  static const Duration normalSnackbarDuration = Duration(seconds: 4);
  static const Duration longSnackbarDuration = Duration(seconds: 6);

  // Date/Time Formats
  static const String dateFormatPattern = 'dd MMM yyyy';
  static const String timeFormatPattern = 'hh:mm a';
  static const String dateTimeFormatPattern = 'dd MMM, hh:mm a';
  static const String shortDateFormatPattern = 'MMM dd';
}

enum OrderCategory {
  cafe('CAF'),
  merchandise('MER'),
  session('SES'),
  refund('REF');

  final String prefix;
  const OrderCategory(this.prefix);
}
