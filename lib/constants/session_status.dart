enum SessionStatus { active, completed, cancelled }

extension SessionStatusExtension on SessionStatus {
  String get displayName {
    switch (this) {
      case SessionStatus.active:
        return 'Active';
      case SessionStatus.completed:
        return 'Completed';
      case SessionStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get storageValue => name.toLowerCase();

  static SessionStatus fromStorageValue(String? value) {
    if (value == null || value.isEmpty) return SessionStatus.completed;
    return SessionStatus.values.firstWhere(
      (e) => e.storageValue == value.toLowerCase(),
      orElse: () => SessionStatus.completed,
    );
  }

  bool get isActive => this == SessionStatus.active;
  bool get hasEnded => this != SessionStatus.active;
}
