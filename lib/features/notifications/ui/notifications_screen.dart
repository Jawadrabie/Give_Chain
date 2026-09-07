import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/skeleton_card.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = 20;
  final _scrollController = ScrollController();
  final _items = <AppNotification>[];
  int _page = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _refresh();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 320) _loadMore();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 0;
      _hasMore = true;
    });
    try {
      final repository = context.read<NotificationRepository>();
      final result = await repository.list(page: 1, pageSize: _pageSize);
      await repository.refreshUnreadCount();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = 1;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = await context.read<NotificationRepository>().list(
        page: next,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      final existing = _items.map((item) => item.id).toSet();
      setState(() {
        _items.addAll(result.items.where((item) => existing.add(item.id)));
        _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _page = next;
        _hasMore = result.hasMore;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _markAll() async {
    try {
      await context.read<NotificationRepository>().markAllRead();
      if (!mounted) return;
      setState(() {
        for (var index = 0; index < _items.length; index++) {
          _items[index] = _items[index].copyWith(isRead: true);
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) {
      return Column(
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _items.any((item) => !item.isRead) ? _markAll : null,
              icon: const Icon(Icons.done_all),
              label: const Text('تحديد الكل كمقروء'),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      appBar: AppBackAppBar(
        title: const Text('الإشعارات'),
        actions: [
          TextButton(
            onPressed: _items.any((item) => !item.isRead) ? _markAll : null,
            child: const Text('قراءة الكل'),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const SkeletonList(count: 5);
    }
    if (_error != null && _items.isEmpty) {
      return ErrorRetry(message: _error!, onRetry: _refresh);
    }
    if (_items.isEmpty) return const EmptyView(message: 'لا توجد إشعارات.');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final item = _items[index];
          return Card(
            color: item.isRead ? null : AppTheme.softOf(context),
            child: ListTile(
              leading: Icon(
                item.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
                color: AppTheme.primary,
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w900,
                ),
              ),
              subtitle: Text(
                '${item.body}\n${DateFormat('yyyy-MM-dd HH:mm').format(item.createdAt.toLocal())}',
              ),
              isThreeLine: true,
              onTap: () => _open(index),
            ),
          );
        },
      ),
    );
  }

  Future<void> _open(int index) async {
    final item = _items[index];
    if (!item.isRead) {
      try {
        await context.read<NotificationRepository>().markRead(item.id);
        if (mounted) {
          setState(() => _items[index] = item.copyWith(isRead: true));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    await context.push('/notifications/detail', extra: _items[index]);
  }
}
