import 'package:intl/intl.dart';

class MutationDetail {
  final String barcode;
  final String? rackId;
  final String? rackName;

  MutationDetail({
    required this.barcode,
    this.rackId,
    this.rackName,
  });

  factory MutationDetail.fromJson(Map<String, dynamic> json) {
    return MutationDetail(
      barcode: json['barcode'] as String,
      rackId: json['rack_id'] as String?,
      rackName: json['rack']?['name'] as String?,
    );
  }
}

class MutationRecord {
  final String id;
  final String userName;
  final DateTime mutationDate;
  final String? notes;
  final List<MutationDetail> details;

  MutationRecord({
    required this.id,
    required this.userName,
    required this.mutationDate,
    this.notes,
    required this.details,
  });

  factory MutationRecord.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? 'Unknown';

    final detailsList = json['details'] as List<dynamic>? ?? [];
    final details = detailsList
        .map((detail) => MutationDetail.fromJson(detail as Map<String, dynamic>))
        .toList();

    return MutationRecord(
      id: json['id'] as String,
      userName: userName,
      mutationDate: DateTime.parse(json['created_at'] as String), // or mutation_date
      notes: json['notes'] as String?,
      details: details,
    );
  }

  String get formattedDate {
    return DateFormat('dd MMM yyyy, HH:mm').format(mutationDate);
  }

  String get formattedDateShort {
    return DateFormat('dd MMM yyyy').format(mutationDate);
  }

  String get formattedTime {
    return DateFormat('HH:mm').format(mutationDate);
  }

  int get totalItems => details.length;
}
