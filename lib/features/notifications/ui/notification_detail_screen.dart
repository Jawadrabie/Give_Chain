import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({super.key, required this.notification});
  final AppNotification notification;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  late AppNotification _item;

  @override
  void initState() {
    super.initState();
    _item = widget.notification;
    if (!_item.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
    }
  }

  Future<void> _markRead() async {
    try {
      await context.read<NotificationRepository>().markRead(_item.id);
      if (mounted) setState(() => _item = _item.copyWith(isRead: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: const Text('تفاصيل الإشعار')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _item.isRead
                  ? [Colors.blueGrey.shade600, Colors.blueGrey.shade400]
                  : [AppTheme.primary, AppTheme.primaryLight],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(
                _item.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                size: 54,
                color: Colors.white,
              ),
              const SizedBox(height: 14),
              Text(
                _item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat(
                  'yyyy-MM-dd • HH:mm',
                ).format(_item.createdAt.toLocal()),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _item.body,
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),
          ),
        ),
        if (_item.referenceId?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          Card(
            color: AppTheme.softOf(context),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.link_outlined, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text(
                        'مرجع مرتبط',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(_item.referenceId!),
                  const SizedBox(height: 8),
                  const Text(
                    'لم يحدد عقد الخادم نوع هذا المرجع لكل NotificationType؛ لذلك لا ينتقل التطبيق تلقائيًا إلى شاشة قد تكون خاطئة.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
