import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../data/media_repository.dart';
import 'media_gallery_screen.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class MediaManagerArgs {
  const MediaManagerArgs({
    required this.ownerType,
    required this.ownerId,
    required this.title,
  });

  final int ownerType;
  final String ownerId;
  final String title;
}

class MediaManagerScreen extends StatefulWidget {
  const MediaManagerScreen({super.key, required this.args});
  final MediaManagerArgs args;

  @override
  State<MediaManagerScreen> createState() => _MediaManagerScreenState();
}

class _MediaManagerScreenState extends State<MediaManagerScreen> {
  late Future<List<MediaFile>> _future;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MediaFile>> _load() => context.read<MediaRepository>().byOwner(
    ownerType: widget.args.ownerType,
    ownerId: widget.args.ownerId,
  );

  void _reload() => setState(() => _future = _load());

  Future<void> _upload() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: false,
    );
    final files =
        result?.files
            .map((file) => file.path)
            .whereType<String>()
            .where((path) => path.isNotEmpty)
            .take(8)
            .toList() ??
        const <String>[];
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      await context.read<MediaRepository>().upload(
        ownerType: widget.args.ownerType,
        ownerId: widget.args.ownerId,
        files: files,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم رفع المرفقات بنجاح.')));
      _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(MediaFile item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المرفق؟'),
        content: const Text('لن تتمكن من استعادة الملف بعد الحذف.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<MediaRepository>().delete(item.id);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBackAppBar(title: Text(widget.args.title)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _uploading ? null : _upload,
      icon: _uploading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_file_outlined),
      label: Text(_uploading ? 'جارٍ الرفع...' : 'إضافة مرفقات'),
    ),
    body: FutureBuilder<List<MediaFile>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            snapshot.data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError && snapshot.data == null) {
          return ErrorRetry(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final items = snapshot.data ?? const <MediaFile>[];
        if (items.isEmpty) {
          return const EmptyView(
            message: 'لا توجد مرفقات بعد. استخدم زر الإضافة لرفع ملف.',
          );
        }
        final urls = items.map((item) => item.url).toList();
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: InkWell(
                  onTap: () => context.push(
                    '/media-gallery',
                    extra: MediaGalleryArgs(
                      urls: urls,
                      initialIndex: index,
                      title: widget.args.title,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Container(
                          color: AppTheme.softOf(context),
                          child: item.mediaType == 0
                              ? Image.network(
                                  item.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.insert_drive_file_outlined,
                                    size: 48,
                                  ),
                                )
                              : const Icon(
                                  Icons.insert_drive_file_outlined,
                                  size: 48,
                                  color: AppTheme.primary,
                                ),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        title: Text(
                          item.isPrimary ? 'الصورة الرئيسية' : 'مرفق',
                        ),
                        trailing: IconButton(
                          tooltip: 'حذف',
                          onPressed: () => _delete(item),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
