import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/tenant_firestore.dart';

class ExportService {
  final TenantRef _tenant;

  ExportService(this._tenant);

  Future<String> exportCustomersCsv() async {
    final snap = await _tenant.customers().orderBy('name').get();
    final buf = StringBuffer();
    buf.writeln('Name,Phone,Email,Credits,Membership,Created');
    for (final doc in snap.docs) {
      final d = doc.data();
      buf.writeln(
        '${_esc(d['name'])},'
        '${_esc(d['phoneNumber'])},'
        '${_esc(d['email'])},'
        '${d['credits'] ?? 0},'
        '${_esc(d['membershipType'])},'
        '${_tsStr(d['createdAt'])}',
      );
    }
    return buf.toString();
  }

  Future<String> exportSessionsCsv({DateTime? from, DateTime? to}) async {
    Query<Map<String, dynamic>> q =
        _tenant.sessions().orderBy('createdAt', descending: true);
    if (from != null) {
      q = q.where('createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }
    final snap = await q.limit(5000).get();
    final buf = StringBuffer();
    buf.writeln('Table,Customer,Status,Duration,Total,Created');
    for (final doc in snap.docs) {
      final d = doc.data();
      buf.writeln(
        '${_esc(d['tableName'])},'
        '${_esc(d['customerName'])},'
        '${_esc(d['status'])},'
        '${d['durationMinutes'] ?? ''},'
        '${d['total'] ?? 0},'
        '${_tsStr(d['createdAt'])}',
      );
    }
    return buf.toString();
  }

  Future<String> exportInventoryCsv() async {
    final snap = await _tenant.stockItems().orderBy('name').get();
    final buf = StringBuffer();
    buf.writeln('Name,Category,Price,Cost,Stock,Unit');
    for (final doc in snap.docs) {
      final d = doc.data();
      buf.writeln(
        '${_esc(d['name'])},'
        '${_esc(d['category'])},'
        '${d['price'] ?? 0},'
        '${d['cost'] ?? 0},'
        '${d['stock'] ?? 0},'
        '${_esc(d['unit'])}',
      );
    }
    return buf.toString();
  }

  Future<String> exportExpensesCsv() async {
    final snap = await _tenant
        .expenses()
        .orderBy('date', descending: true)
        .get();
    final buf = StringBuffer();
    buf.writeln('Date,Category,Amount,Description,Vendor,CreatedBy');
    for (final doc in snap.docs) {
      final d = doc.data();
      buf.writeln(
        '${_tsStr(d['date'])},'
        '${_esc(d['category'])},'
        '${d['amount'] ?? 0},'
        '${_esc(d['description'])},'
        '${_esc(d['vendorName'])},'
        '${_esc(d['createdBy'])}',
      );
    }
    return buf.toString();
  }

  String _esc(dynamic val) {
    if (val == null) return '';
    final s = val.toString().replaceAll('"', '""');
    return s.contains(',') || s.contains('\n') ? '"$s"' : s;
  }

  String _tsStr(dynamic val) {
    if (val is Timestamp) {
      final d = val.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    return '';
  }
}
