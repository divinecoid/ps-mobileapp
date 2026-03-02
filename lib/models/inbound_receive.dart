import 'package:intl/intl.dart';

/// Model untuk detail barcode dalam inbound receive
class InboundReceiveDetail {
  final String barcode;
  final String? rack;
  final String? model;
  final String? color;
  final String? size;
  final String? serialNumber;
  final int qty;

  InboundReceiveDetail({
    required this.barcode,
    this.rack,
    this.model,
    this.color,
    this.size,
    this.serialNumber,
    this.qty = 1,
  });

  factory InboundReceiveDetail.fromJson(Map<String, dynamic> json) {
    return InboundReceiveDetail(
      barcode: json['barcode'] as String,
      rack: json['rack'] as String?,
      model: json['model'] as String?,
      color: json['color'] as String?,
      size: json['size'] as String?,
      serialNumber: json['serial_number'] as String?,
      qty: json['qty'] as int? ?? 1,
    );
  }
}

/// Model untuk ringkasan item dalam inbound
class InboundSummary {
  final String? model;
  final String? color;
  final String? size;
  final String? serialNumber;
  final int totalQty;

  InboundSummary({
    this.model,
    this.color,
    this.size,
    this.serialNumber,
    required this.totalQty,
  });

  factory InboundSummary.fromJson(Map<String, dynamic> json) {
    return InboundSummary(
      model: json['model'] as String?,
      color: json['color'] as String?,
      size: json['size'] as String?,
      serialNumber: json['serial_number'] as String?,
      totalQty: json['total_qty'] as int? ?? 0,
    );
  }

  String get displayName {
    final parts = [
      if (model != null && model!.isNotEmpty) model,
      if (color != null && color!.isNotEmpty) color,
      if (size != null && size!.isNotEmpty) size,
    ];
    return parts.isEmpty ? 'Unknown Item' : parts.join(' - ');
  }
}

/// Model untuk CMT information
class CmtInfo {
  final String code;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? address;

  CmtInfo({
    required this.code,
    required this.name,
    this.contactPerson,
    this.phone,
    this.address,
  });

  factory CmtInfo.fromJson(Map<String, dynamic> json) {
    return CmtInfo(
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
    );
  }
}

/// Model untuk Inbound Receive (penerimaan barang)
class InboundReceive {
  final String id;
  final String? warehouseId;
  final String? warehouseName;
  final String userName;
  final DateTime receivedDate;
  final String? notes;
  final CmtInfo? cmtInfo;
  final List<InboundReceiveDetail> details;
  final List<InboundSummary> summary;

  InboundReceive({
    required this.id,
    this.warehouseId,
    this.warehouseName,
    required this.userName,
    required this.receivedDate,
    this.notes,
    this.cmtInfo,
    required this.details,
    this.summary = const [],
  });

  factory InboundReceive.fromJson(Map<String, dynamic> json) {
    // Parse warehouse
    final warehouse = json['warehouse'] as Map<String, dynamic>?;
    final warehouseName = warehouse?['name'] as String?;

    // Parse user
    final user = json['user'] as Map<String, dynamic>?;
    final userName = user?['name'] as String? ?? 'Unknown';

    // Parse CMT from request
    final request = json['request'] as Map<String, dynamic>?;
    final cmtData = request?['cmt'] as Map<String, dynamic>?;
    final cmtInfo = cmtData != null ? CmtInfo.fromJson(cmtData) : null;

    // Parse details
    final detailsList = json['details'] as List<dynamic>? ?? [];
    final details = detailsList
        .map((detail) => InboundReceiveDetail.fromJson(detail as Map<String, dynamic>))
        .toList();

    // Parse summary
    final summaryList = json['summary'] as List<dynamic>? ?? [];
    final summary = summaryList
        .map((s) => InboundSummary.fromJson(s as Map<String, dynamic>))
        .toList();

    return InboundReceive(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String?,
      warehouseName: warehouseName,
      userName: userName,
      receivedDate: DateTime.parse(json['received_date'] as String),
      notes: json['notes'] as String?,
      cmtInfo: cmtInfo,
      details: details,
      summary: summary,
    );
  }

  /// Format tanggal untuk display (e.g., "24 Jan 2026, 10:30")
  String get formattedDate {
    return DateFormat('dd MMM yyyy, HH:mm').format(receivedDate);
  }

  /// Format tanggal pendek (e.g., "24 Jan 2026")
  String get formattedDateShort {
    return DateFormat('dd MMM yyyy').format(receivedDate);
  }

  /// Format waktu (e.g., "10:30")
  String get formattedTime {
    return DateFormat('HH:mm').format(receivedDate);
  }

  /// Total items count
  int get totalItems => details.length;

  /// CMT code untuk display
  String get cmtCode => cmtInfo?.code ?? '-';

  /// CMT name untuk display
  String get cmtName => cmtInfo?.name ?? '-';

  /// Display name: "CMT01 - CMT Bandung"
  String get cmtDisplayName {
    if (cmtInfo != null) {
      if (cmtInfo!.code.isEmpty && cmtInfo!.name.isEmpty) {
        return 'Mutation / No CMT';
      }
      return '${cmtInfo!.code} - ${cmtInfo!.name}'.replaceAll(RegExp(r'^ - | - $'), '');
    }
    return '-';
  }
}
