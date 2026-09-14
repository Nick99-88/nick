enum LockType {
  none,
  biometrics,
}

class LockPreference {
  final bool isEnabled;
  final LockType lockType;

  const LockPreference({
    this.isEnabled = false,
    this.lockType = LockType.none,
  });

  factory LockPreference.fromMap(Map<String, dynamic> map) {
    return LockPreference(
      isEnabled: map['is_enabled'] as bool? ?? false,
      lockType: LockType.values.firstWhere(
        (e) => e.name == map['lock_type'],
        orElse: () => LockType.none,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is_enabled': isEnabled,
      'lock_type': lockType.name,
    };
  }

  LockPreference copyWith({bool? isEnabled, LockType? lockType}) {
    return LockPreference(
      isEnabled: isEnabled ?? this.isEnabled,
      lockType: lockType ?? this.lockType,
    );
  }
}
