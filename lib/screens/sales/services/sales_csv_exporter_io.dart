import 'dart:io';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

import '../../../firestore/tenant_firestore.dart';
import '../../../models/sales_transaction.dart';
import '../../../utils/app_logger.dart';

class SalesCsvExporter {
  static Future<String?> export(
    SalesDataSummary summary, {
    required TenantRef tenant,
  }) async {
    try {
      final List<List<dynamic>> rows = [];
      final currencyFormat = NumberFormat.simpleCurrency(
        locale: 'en_IN',
        decimalDigits: 0,
      );
      final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

      // 1. HEADER SECTION
      rows.add(['SALES REPORT']);
      rows.add(['Generated on:', dateFormat.format(DateTime.now())]);
      rows.add([]);

      // 2. SUMMARY SECTION
      rows.add(['SUMMARY']);
      rows.add(['Total Revenue:', currencyFormat.format(summary.totalRevenue)]);
      rows.add(['Total Transactions:', summary.totalTransactions.toString()]);
      rows.add([
        'Average Transaction Value:',
        currencyFormat.format(
          summary.totalTransactions > 0
              ? summary.totalRevenue / summary.totalTransactions
              : 0,
        ),
      ]);
      rows.add([]);

      // 3. REVENUE BREAKDOWN BY TYPE
      rows.add(['REVENUE BY TYPE']);
      rows.add(['Type', 'Amount', 'Transaction Count', 'Average Value']);

      // Calculate transaction counts by type
      final Map<String, int> transactionCountsByType = {
        'Table Charges': summary.transactions
            .where((t) => t.tableCharges > 0)
            .length,
        'Cafe': summary.transactions.where((t) => t.cafeCharges > 0).length,
        'Merchandise': summary.transactions
            .where((t) => t.merchandiseCharges > 0)
            .length,
        'Credit Top-up': summary.transactions
            .where((t) => t.type == TransactionType.credit)
            .length,
      };

      summary.revenueByType.forEach((type, amount) {
        final count = transactionCountsByType[type] ?? 0;
        final avg = count > 0 ? amount / count : 0;
        rows.add([
          type,
          currencyFormat.format(amount),
          count.toString(),
          currencyFormat.format(avg),
        ]);
      });
      rows.add([]);

      // 4. PAYMENT METHOD BREAKDOWN
      rows.add(['PAYMENT METHOD BREAKDOWN']);
      rows.add(['Method', 'Amount', 'Transaction Count', 'Average Value']);

      // Calculate transaction counts by payment method
      final Map<String, int> transactionCountsByMethod = {};
      for (final tx in summary.transactions) {
        transactionCountsByMethod.update(
          tx.paymentMethod,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      summary.paymentMethodTotals.forEach((method, amount) {
        final count = transactionCountsByMethod[method] ?? 0;
        final avg = count > 0 ? amount / count : 0;
        rows.add([
          method.toUpperCase(),
          currencyFormat.format(amount),
          count.toString(),
          currencyFormat.format(avg),
        ]);
      });
      rows.add([]);

      // 5. CREDIT TOPUP REPORT
      rows.add(['CREDIT TOPUP REPORT']);
      rows.add(['Metric', 'Value', 'Details']);
      rows.add([
        'Total Credit Sold Worth',
        currencyFormat.format(summary.creditSummary.totalCreditsSold),
        '${summary.creditSummary.topUpCount} top-up transactions',
      ]);
      rows.add([
        'Total Credits Allotted Worth',
        currencyFormat.format(summary.creditSummary.totalCreditsAllotted),
        'From memberships & promotions',
      ]);

      // Build details string for net spent showing refund breakdown
      String netSpentDetails =
          '${summary.creditSummary.spendCount} spend transactions';
      if (summary.creditSummary.refundCount > 0) {
        netSpentDetails +=
            ' minus ${summary.creditSummary.refundCount} refunds (${currencyFormat.format(summary.creditSummary.totalCreditsRefunded)})';
      }
      rows.add([
        'Net Credits Spent by Customers',
        currencyFormat.format(summary.creditSummary.totalCreditsSpent),
        netSpentDetails,
      ]);
      if (summary.creditSummary.refundCount > 0) {
        rows.add([
          '  - Gross Credits Spent',
          currencyFormat.format(summary.creditSummary.grossCreditsSpent),
          '${summary.creditSummary.spendCount} debit transactions',
        ]);
        rows.add([
          '  - Credits Refunded',
          currencyFormat.format(summary.creditSummary.totalCreditsRefunded),
          '${summary.creditSummary.refundCount} refund transactions',
        ]);
      }
      rows.add([
        'Total Credit Balance',
        currencyFormat.format(summary.creditSummary.totalCreditBalance),
        'Current balance across all customers',
      ]);
      rows.add([]);

      // 6. DETAILED TRANSACTIONS
      rows.add(['DETAILED TRANSACTIONS']);
      rows.add([
        'Date & Time',
        'Transaction ID',
        'Type',
        'Customer',
        'Membership ID',
        'Payment Method',
        'Table Charges',
        'Cafe Charges',
        'Merchandise',
        'Credits Used',
        'Total Amount',
        'Items',
      ]);

      // Fetch membership IDs
      final customerIds = summary.transactions
          .where((t) => t.customerId != null && t.customerId!.isNotEmpty)
          .map((t) => t.customerId!)
          .toSet();

      final Map<String, String?> membershipMap = {};
      for (final cid in customerIds) {
        try {
          final doc = await tenant.customers().doc(cid).get();
          membershipMap[cid] = doc.data()?['membershipId'] as String?;
        } catch (e, st) {
          AppLogger.debug(
            'CSV export: membership lookup failed for $cid: $e\n$st',
            tag: 'SalesCsv',
          );
          membershipMap[cid] = null;
        }
      }

      // Add transaction details
      for (final tx in summary.transactions) {
        final membershipId = tx.customerId != null
            ? (membershipMap[tx.customerId!] ?? '')
            : '';
        final itemsStr = tx.items
            .map((e) => '${e.name} x${e.quantity} @${e.price}')
            .join(' | ');

        rows.add([
          dateFormat.format(tx.date),
          tx.id,
          tx.type.name,
          tx.customerName ?? 'Walk-in',
          membershipId,
          tx.paymentMethod.toUpperCase(),
          currencyFormat.format(tx.tableCharges),
          currencyFormat.format(tx.cafeCharges),
          currencyFormat.format(tx.merchandiseCharges),
          currencyFormat.format(tx.creditsUsed),
          currencyFormat.format(tx.total),
          itemsStr,
        ]);
      }

      const converter = ListToCsvConverter();
      final csvString = converter.convert(rows);

      final fileName =
          'sales_report_${DateTime.now().millisecondsSinceEpoch}.csv';

      // Determine directory
      Directory dir;
      if (Platform.isAndroid || Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      } else {
        dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      }

      // Ensure permission on Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) return null;
      }

      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvString);

      await OpenFilex.open(file.path);

      return file.path;
    } catch (e) {
      AppLogger.warning('CSV export failed: $e', tag: 'CSVExporter');
      return null;
    }
  }
}
