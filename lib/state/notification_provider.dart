import 'package:flutter/material.dart';
import '../api/notification_service.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  int _currentPage = 1;
  final int _perPage = 25;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  List<AppNotification> get notifications => _notifications;
  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (!_hasMore && !refresh) {
      return;
    }

    final page = refresh ? 1 : _currentPage;
    final res = await NotificationService.getNotifications(
      perPage: _perPage,
      page: page,
    );

    if (res['success'] == true && res['data'] is List) {
      final data = res['data'] as List;
      final notifications = data
          .map((e) => AppNotification.fromJson(e))
          .toList();

      if (refresh) {
        _notifications = notifications;
      } else {
        _notifications.addAll(notifications);
      }

      _notifications.sort(
        (a, b) => b.createdAt?.compareTo(a.createdAt ?? DateTime(0)) ?? 0,
      );

      if (res['pagination'] is Map<String, dynamic>) {
        final pagination = Map<String, dynamic>.from(res['pagination']);
        final currentPage = pagination['current_page'] is int
            ? pagination['current_page'] as int
            : page;
        final lastPage = pagination['last_page'] is int
            ? pagination['last_page'] as int
            : page;
        _hasMore = currentPage < lastPage;
        _currentPage = currentPage + 1;
      } else {
        _hasMore = notifications.length >= _perPage;
        if (_hasMore) {
          _currentPage = page + 1;
        }
      }

      notifyListeners();
    }
  }

  Future<void> loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    await fetchNotifications(refresh: false);

    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> fetchLowStockAndSync() async {
    final res = await NotificationService.getLowStock();
    if (res['success'] == true) {
      // backend stores notifications; fetch list after low-stock check
      await fetchNotifications();
    }
  }

  Future<void> markAsRead(String id) async {
    final res = await NotificationService.markAsRead(id);
    if (res['success'] == true) {
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        final updated = AppNotification(
          id: _notifications[idx].id,
          title: _notifications[idx].title,
          message: _notifications[idx].message,
          type: _notifications[idx].type,
          data: _notifications[idx].data,
          isRead: true,
          readAt: DateTime.now(),
          createdAt: _notifications[idx].createdAt,
        );
        _notifications[idx] = updated;
        notifyListeners();
      } else {
        // fallback: refetch
        await fetchNotifications();
      }
    }
  }

  Future<void> markAllAsRead() async {
    final unreadIds = _notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();
    if (unreadIds.isEmpty) {
      return;
    }

    for (final id in unreadIds) {
      final res = await NotificationService.markAsRead(id);
      if (res['success'] == true) {
        final idx = _notifications.indexWhere((n) => n.id == id);
        if (idx != -1) {
          _notifications[idx] = AppNotification(
            id: _notifications[idx].id,
            title: _notifications[idx].title,
            message: _notifications[idx].message,
            type: _notifications[idx].type,
            data: _notifications[idx].data,
            isRead: true,
            readAt: DateTime.now(),
            createdAt: _notifications[idx].createdAt,
          );
        }
      }
    }

    notifyListeners();
  }
}
