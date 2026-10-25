import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';
import '../utils/firestore_utils.dart';

/// Service to manage recently used/selected customers locally
/// Provides instant access to recently interacted customers without Firestore queries
class RecentCustomersService {
  static const String _recentCustomerIdsKey = 'recent_customer_ids';
  static const String _recentCustomerDataKey = 'recent_customer_data';
  static const int _maxRecentCustomers = 10;

  static SharedPreferences? _prefs;

  /// Initialize the service - call this early in app startup
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get SharedPreferences instance
  static Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Record a customer as recently used (call when customer is selected)
  static Future<void> recordRecentCustomer(RecentCustomerData customer) async {
    final prefs = await _preferences;

    // Get existing IDs
    final existingIds = prefs.getStringList(_recentCustomerIdsKey) ?? [];
    final existingData = prefs.getString(_recentCustomerDataKey);

    Map<String, dynamic> dataMap = {};
    if (existingData != null) {
      try {
        final decoded = jsonDecode(existingData);
        dataMap = Map<String, dynamic>.from(decoded as Map);
      } catch (e, st) {
        AppLogger.debug(
          'Recent customers: reset corrupt JSON cache: $e\n$st',
          tag: 'RecentCustomers',
        );
        dataMap = {};
      }
    }

    // Remove if already exists (to move to front)
    existingIds.remove(customer.id);

    // Add to front
    existingIds.insert(0, customer.id);

    // Trim to max size
    if (existingIds.length > _maxRecentCustomers) {
      final removedIds = existingIds.sublist(_maxRecentCustomers);
      existingIds.removeRange(_maxRecentCustomers, existingIds.length);
      // Clean up data for removed IDs
      for (final id in removedIds) {
        dataMap.remove(id);
      }
    }

    // Store customer data
    dataMap[customer.id] = customer.toJson();

    // Save
    await prefs.setStringList(_recentCustomerIdsKey, existingIds);
    await prefs.setString(_recentCustomerDataKey, jsonEncode(dataMap));
  }

  /// Get list of recent customer IDs (most recent first)
  static Future<List<String>> getRecentCustomerIds() async {
    final prefs = await _preferences;
    return prefs.getStringList(_recentCustomerIdsKey) ?? [];
  }

  /// Get recent customers data (for instant display before Firestore fetch)
  static Future<List<RecentCustomerData>> getRecentCustomers() async {
    final prefs = await _preferences;
    final ids = prefs.getStringList(_recentCustomerIdsKey) ?? [];
    final dataString = prefs.getString(_recentCustomerDataKey);

    if (dataString == null || ids.isEmpty) return [];

    try {
      final dataMap = Map<String, dynamic>.from(
        jsonDecode(dataString) as Map,
      );
      return ids
          .where((id) => dataMap.containsKey(id))
          .map(
            (id) => RecentCustomerData.fromJson(
              Map<String, dynamic>.from(dataMap[id]! as Map),
            ),
          )
          .toList();
    } catch (e, st) {
      AppLogger.debug(
        'Recent customers: decode failed, returning empty: $e\n$st',
        tag: 'RecentCustomers',
      );
      return [];
    }
  }

  /// Clear all recent customers
  static Future<void> clearRecentCustomers() async {
    final prefs = await _preferences;
    await prefs.remove(_recentCustomerIdsKey);
    await prefs.remove(_recentCustomerDataKey);
  }

  /// Remove a specific customer from recent list
  static Future<void> removeRecentCustomer(String customerId) async {
    final prefs = await _preferences;
    final ids = prefs.getStringList(_recentCustomerIdsKey) ?? [];
    final dataString = prefs.getString(_recentCustomerDataKey);

    ids.remove(customerId);

    if (dataString != null) {
      try {
        final dataMap = Map<String, dynamic>.from(
          jsonDecode(dataString) as Map,
        );
        dataMap.remove(customerId);
        await prefs.setString(_recentCustomerDataKey, jsonEncode(dataMap));
      } catch (e, st) {
        AppLogger.warning(
          'removeRecentCustomer: corrupt local cache for $customerId: $e\n$st',
          tag: 'RecentCustomers',
        );
      }
    }

    await prefs.setStringList(_recentCustomerIdsKey, ids);
  }
}

/// Lightweight customer data for local storage
class RecentCustomerData {
  final String id;
  final String name;
  final String phoneNumber;
  final String? membershipId;
  final double credits;
  final DateTime lastUsed;

  RecentCustomerData({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.membershipId,
    required this.credits,
    required this.lastUsed,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
    'membershipId': membershipId,
    'credits': credits,
    'lastUsed': lastUsed.millisecondsSinceEpoch,
  };

  factory RecentCustomerData.fromJson(Map<String, dynamic> json) {
    return RecentCustomerData(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      membershipId: json['membershipId'] as String?,
      credits: parseFirestoreDouble(json['credits']),
      lastUsed: DateTime.fromMillisecondsSinceEpoch(json['lastUsed'] as int),
    );
  }
}
