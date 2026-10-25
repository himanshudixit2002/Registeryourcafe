class FirestoreCollections {
  FirestoreCollections._();

  /// Root collection for multi-tenant company documents.
  static const String companies = 'companies';

  /// Opt-in public listing for anonymous landing (`publicVenues/{companyId}`).
  static const String publicVenues = 'publicVenues';

  /// Public-safe live table mirror (`companies/{cid}/public_floor/{tableId}`).
  static const String publicFloor = 'public_floor';

  /// Public menu rows (`companies/{cid}/public_menu_items/{id}`).
  static const String publicMenuItems = 'public_menu_items';

  /// Guest booking requests for live floor (`companies/{cid}/floor_booking_requests/{id}`).
  static const String floorBookingRequests = 'floor_booking_requests';

  /// Public-safe approved time holds (`companies/{cid}/public_booking_slots/{id}`).
  static const String publicBookingSlots = 'public_booking_slots';

  /// Guest-submitted menu orders from public landing (`companies/{cid}/guest_cafe_orders/{id}`).
  static const String guestCafeOrders = 'guest_cafe_orders';

  static const String customers = 'customers';
  static const String tables = 'tables';

  /// Tenant-defined labels/icons for table categories (`SnookerTable.type` stores [id]).
  static const String tableTypeDefinitions = 'table_type_definitions';
  static const String sessions = 'sessions';
  static const String cafeOrders = 'cafe_orders';
  static const String merchandiseOrders = 'merchandise_orders';
  static const String stockItems = 'stock_items';
  static const String categories = 'categories';
  static const String users = 'users';
  static const String creditTransactions = 'credit_transactions';
  static const String orderCounters = 'order_counters';
  static const String membershipCounters = 'membership_counters';
  static const String membershipTypeDefinitions = 'membership_type_definitions';
  static const String leaderboardSettings = 'leaderboard_settings';
  static const String gameMatches = 'game_matches';
  static const String salesTransactions = 'sales_transactions';
  static const String tournaments = 'tournaments';
  static const String tournamentParticipants = 'tournament_participants';
  static const String tournamentMatches = 'tournament_matches';
  static const String loyaltyConversions = 'loyalty_conversions';
  static const String loyaltySettings = 'loyalty_settings';
  static const String vendors = 'vendors';
  static const String stockReceipts = 'stock_receipts';
  static const String membershipPayments = 'membership_payments';

  /// Top-level under each company (sibling of [tournaments]).
  static const String tournamentRegistrations = 'tournament_registrations';

  static const String transactions = 'transactions';
  static const String pointAdjustments = 'point_adjustments';
  static const String leaderboardResets = 'leaderboard_resets';

  /// Role templates with permission ids (`companies/{cid}/permissionRoles/{roleId}`).
  static const String permissionRoles = 'permissionRoles';

  /// In-app notifications (`companies/{cid}/notifications/{id}`).
  static const String notifications = 'notifications';

  static const String expenses = 'expenses';
  static const String reservations = 'reservations';

  static const String feedback = 'feedback';
  static const String promotions = 'promotions';
  static const String invoices = 'invoices';
  static const String auditLog = 'auditLog';

  static const String messageTemplates = 'messageTemplates';

  static const String receipts = 'receipts';
  static const String shifts = 'shifts';

  static const String preOrders = 'preOrders';
  static const String tips = 'tips';
  static const String orderModifications = 'orderModifications';
  static const String splitBills = 'splitBills';
  static const String customerPreferences = 'customerPreferences';
  static const String referrals = 'referrals';
  static const String waitlist = 'waitlist';
  static const String customerSegments = 'customerSegments';
  static const String campaigns = 'campaigns';

  static const String tableMaintenance = 'tableMaintenance';
  static const String walkInQueue = 'walkInQueue';
  static const String recipes = 'recipes';
  static const String foodWaste = 'foodWaste';
  static const String dailySpecials = 'dailySpecials';
  static const String priceHistory = 'priceHistory';
  static const String purchaseOrders = 'purchaseOrders';
  static const String expiryRecords = 'expiryRecords';
  static const String supplierScores = 'supplierScores';

  static const String commissions = 'commissions';
  static const String trainingModules = 'trainingModules';
  static const String leaveRequests = 'leaveRequests';
  static const String staffGoals = 'staffGoals';
  static const String staffDocuments = 'staffDocuments';
  static const String cashRegister = 'cashRegister';
  static const String pettyCash = 'pettyCash';
  static const String budgets = 'budgets';
  static const String vendorPayments = 'vendorPayments';

  static const String giftCards = 'giftCards';
  static const String marketingCampaigns = 'marketingCampaigns';
  static const String marketingBudgets = 'marketingBudgets';
  static const String staffChat = 'staffChat';
  static const String autoReminders = 'autoReminders';
  static const String communicationLog = 'communicationLog';
}

class FirestoreFields {
  FirestoreFields._();

  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String status = 'status';
  static const String isRefunded = 'isRefunded';
  static const String isBilled = 'isBilled';
  static const String performedById = 'performedById';
  static const String performedByName = 'performedByName';
  static const String performedByRole = 'performedByRole';
  static const String customerId = 'customerId';
  static const String customerName = 'customerName';
  static const String credits = 'credits';
  static const String sessionId = 'sessionId';
  static const String tableId = 'tableId';
  static const String tableName = 'tableName';
  static const String items = 'items';
  static const String total = 'total';
  static const String paymentMethod = 'paymentMethod';
  static const String paymentBreakdown = 'paymentBreakdown';
  static const String creditsUsed = 'creditsUsed';
}
