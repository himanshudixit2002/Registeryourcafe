import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import 'tenant_provider.dart';

final cafeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(const []);

  return tenant
      .categories()
      .where('isMerchandise', isEqualTo: false)
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((e) => Category.fromFirestore(e)).toList(),
      );
});

final merchandiseCategoriesProvider = StreamProvider<List<Category>>((ref) {
  ref.keepAlive();

  final tenant = ref.watch(tenantRefProvider);
  if (tenant == null) return Stream.value(const []);

  return tenant
      .categories()
      .where('isMerchandise', isEqualTo: true)
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((e) => Category.fromFirestore(e)).toList(),
      );
});

final addCategoryProvider =
    FutureProvider.family<String, (String name, bool isMerchandise)>((
      ref,
      tuple,
    ) async {
      final (name, isMerchandise) = tuple;
      final tenant = ref.watch(tenantRefProvider);
      if (tenant == null) throw StateError('No company');
      final doc = await tenant.categories().add({
        'name': name.trim(),
        'isMerchandise': isMerchandise,
      });
      return doc.id;
    });
