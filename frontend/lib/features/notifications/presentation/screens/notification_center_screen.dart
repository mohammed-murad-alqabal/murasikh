import 'package:flutter/material.dart';
import '../../../../services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'ambient':
        return Icons.hearing;
      case 'face':
        return Icons.face;
      case 'daily':
        return Icons.calendar_today;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notificationService.notifications;
    final unreadCount = _notificationService.unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز الإشعارات'),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'تحديد الكل كمقروء',
              onPressed: () => _notificationService.markAllAsRead(),
            ),
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'مسح الكل',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('مسح الإشعارات'),
                    content: const Text('هل أنت متأكد من مسح جميع الإشعارات السابقة؟'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () {
                          _notificationService.clearAll();
                          Navigator.pop(context);
                        },
                        child: const Text('مسح', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد إشعارات حالياً',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isUnread = !notification.isRead;
                return Dismissible(
                  key: Key(notification.id),
                  direction: DismissDirection.startToEnd,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) {
                    _notificationService.deleteNotification(notification.id);
                  },
                  child: InkWell(
                    onTap: () {
                      if (isUnread) {
                        _notificationService.markAsRead(notification.id);
                      }
                      // إظهار تفاصيل إضافية في نافذة
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(notification.title),
                          content: Text(notification.body, style: const TextStyle(height: 1.5)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('إغلاق'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      color: isUnread ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isUnread ? AppColors.primary : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIconForType(notification.type),
                              color: isUnread ? Colors.white : Colors.grey.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.title,
                                        style: TextStyle(
                                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 16,
                                          color: isUnread ? AppColors.primary : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      timeago.format(notification.timestamp, locale: 'ar'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  notification.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
