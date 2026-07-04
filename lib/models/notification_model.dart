import 'package:intl/intl.dart';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    required this.isRead,
    this.readAt,
    this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? '',
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
      isRead: json['is_read'] == true || json['is_read'] == 1,
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  String get createdAtFormatted {
    if (createdAt == null) return '';
    return DateFormat('HH:mm').format(createdAt!);
  }

  String get dateGroupLabel {
    if (createdAt == null) return 'Unknown';

    final now = DateTime.now();
    final createdDate = DateTime(
      createdAt!.year,
      createdAt!.month,
      createdAt!.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final difference = today.difference(createdDate).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';

    return DateFormat('EEEE, d MMM yyyy').format(createdAt!);
  }

  String get timeAgo {
    if (createdAt == null) return '';

    final diff = DateTime.now().difference(createdAt!);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return DateFormat('d MMM').format(createdAt!);
  }
}
