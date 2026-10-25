enum TableStatus { available, occupied, maintenance }

extension TableStatusExtension on TableStatus {
  String get displayName {
    switch (this) {
      case TableStatus.available:
        return 'Available';
      case TableStatus.occupied:
        return 'Occupied';
      case TableStatus.maintenance:
        return 'Maintenance';
    }
  }

  String get storageValue => name.toLowerCase();

  static TableStatus fromStorageValue(String? value) {
    if (value == null || value.isEmpty) return TableStatus.available;
    return TableStatus.values.firstWhere(
      (e) => e.storageValue == value.toLowerCase(),
      orElse: () => TableStatus.available,
    );
  }

  bool get isAvailable => this == TableStatus.available;
  bool get isInUse => this == TableStatus.occupied;
  bool get isUnderMaintenance => this == TableStatus.maintenance;
}
