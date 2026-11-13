import '../core/utils/helpers.dart';

class RfidCard {
  final String uid;
  final String? label;
  final DateTime? addedAt;

  RfidCard({
    required this.uid,
    this.label,
    this.addedAt,
  });

  String get formattedUid => Helpers.formatRfidUid(uid);

  String get displayName => (label != null && label!.trim().isNotEmpty) ? label!.trim() : 'RFID Tag';

  bool get hasCustomLabel => label != null && label!.trim().isNotEmpty;

  RfidCard copyWith({String? uid, String? label, DateTime? addedAt}) {
    return RfidCard(
      uid: uid ?? this.uid,
      label: label ?? this.label,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'label': label,
      'added_at': addedAt?.toIso8601String(),
    };
  }

  factory RfidCard.fromJson(Map<String, dynamic> json) {
    return RfidCard(
      uid: json['uid'] as String,
      label: json['label'] as String?,
      addedAt: json['added_at'] != null ? DateTime.tryParse(json['added_at'] as String) : null,
    );
  }
}
