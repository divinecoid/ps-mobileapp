import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../state/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  late final ScrollController _scrollController;

  static const _brandBlue = Color(0xFF1565D8);
  static const _brandBlueDark = Color(0xFF0D47A1);
  static const _bg = Color(0xFFF7F5FB);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 200.0;

    final provider = context.read<NotificationProvider>();
    if (currentScroll >= maxScroll - threshold &&
        provider.hasMore &&
        !provider.isLoadingMore) {
      provider.loadMoreNotifications();
    }
  }

  Future<void> _load() async {
    final provider = context.read<NotificationProvider>();
    await provider.fetchNotifications(refresh: true);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final grouped = _groupNotifications(provider.notifications);

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(provider),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : provider.notifications.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: _brandBlue,
                    onRefresh: () => context
                        .read<NotificationProvider>()
                        .fetchNotifications(refresh: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount:
                          grouped.length + (provider.isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= grouped.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final group = grouped[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(
                                top: index == 0 ? 0 : 16,
                                bottom: 10,
                                left: 4,
                              ),
                              child: Text(
                                group.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black54,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            ...group.notifications.map(
                              (n) => _buildNotificationCard(context, n),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(NotificationProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandBlueDark, _brandBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20,
        left: 16,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Notifikasi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!_loading && provider.unreadCount > 0)
            GestureDetector(
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                await context.read<NotificationProvider>().markAllAsRead();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Semua notifikasi ditandai dibaca'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Tandai semua',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: _brandBlue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              size: 40,
              color: _brandBlue,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada notifikasi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Notifikasi baru akan muncul di sini',
            style: TextStyle(fontSize: 13, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotification notification,
  ) {
    final style = _styleForType(notification.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(notification.id),
        direction: notification.isRead
            ? DismissDirection.none
            : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: _brandBlue,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.check, color: Colors.white),
        ),
        confirmDismiss: (_) async {
          await context.read<NotificationProvider>().markAsRead(
            notification.id,
          );
          return false;
        },
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              if (!notification.isRead) {
                await context.read<NotificationProvider>().markAsRead(
                  notification.id,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: notification.isRead
                    ? null
                    : Border.all(
                        color: style.color.withOpacity(0.25),
                        width: 1.2,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: style.color,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: style.color.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(style.icon, color: Colors.white, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.bold,
                                  fontSize: 14.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (!notification.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6, top: 4),
                                decoration: BoxDecoration(
                                  color: style.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: Colors.black38,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              notification.timeAgo,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Mirrors the drawer's color-coded menu (Outbound, Inbound, Checker, Mutasi, Reject)
  ({IconData icon, Color color}) _styleForType(String type) {
    switch (type.toLowerCase()) {
      case 'outbound':
        return (icon: Icons.logout_rounded, color: const Color(0xFFE15B5B));
      case 'inbound':
        return (icon: Icons.login_rounded, color: const Color(0xFF4FA3E3));
      case 'checker':
        return (icon: Icons.fact_check_rounded, color: const Color(0xFFE3A23C));
      case 'mutasi':
        return (icon: Icons.swap_horiz_rounded, color: const Color(0xFF5CAE6E));
      case 'reject':
        return (icon: Icons.close_rounded, color: const Color(0xFFE0B43C));
      case 'order':
      case 'order_placed':
        return (
          icon: Icons.shopping_bag_rounded,
          color: const Color(0xFFB05CD9),
        );
      case 'low_stock':
      case 'stock':
        return (
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFFE3902C),
        );
      default:
        return (icon: Icons.notifications_rounded, color: _brandBlue);
    }
  }

  List<_NotificationGroup> _groupNotifications(
    List<AppNotification> notifications,
  ) {
    final groups = <_NotificationGroup>[];
    for (final notification in notifications) {
      final label = notification.dateGroupLabel;
      if (groups.isEmpty || groups.last.label != label) {
        groups.add(_NotificationGroup(label, []));
      }
      groups.last.notifications.add(notification);
    }
    return groups;
  }
}

class _NotificationGroup {
  final String label;
  final List<AppNotification> notifications;

  _NotificationGroup(this.label, this.notifications);
}
