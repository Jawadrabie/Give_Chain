import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/url_resolver.dart';
import '../../../core/widgets/app_back_app_bar.dart';

class MediaGalleryArgs {
  const MediaGalleryArgs({
    required this.urls,
    this.initialIndex = 0,
    this.title = 'الوسائط',
  });

  final List<String> urls;
  final int initialIndex;
  final String title;
}

class MediaGalleryScreen extends StatefulWidget {
  const MediaGalleryScreen({super.key, required this.args});
  final MediaGalleryArgs args;

  @override
  State<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends State<MediaGalleryScreen> {
  late final PageController _controller;
  late int _index;

  List<String> get _urls => widget.args.urls
      .map(UrlResolver.resolve)
      .where((value) => value.trim().isNotEmpty)
      .toSet()
      .toList();

  @override
  void initState() {
    super.initState();
    final maxIndex = widget.args.urls.isEmpty ? 0 : widget.args.urls.length - 1;
    _index = widget.args.initialIndex.clamp(0, maxIndex);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBackAppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.args.title),
        actions: [
          if (urls.isNotEmpty)
            IconButton(
              tooltip: 'فتح خارجيًا',
              onPressed: () => _open(urls[_index]),
              icon: const Icon(Icons.open_in_new),
            ),
        ],
      ),
      body: urls.isEmpty
          ? const Center(
              child: Text(
                'لا توجد وسائط متاحة.',
                style: TextStyle(color: Colors.white),
              ),
            )
          : Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: urls.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final url = urls[index];
                    if (!_isImage(url)) {
                      return _DocumentPreview(
                        url: url,
                        onOpen: () => _open(url),
                      );
                    }
                    return InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5,
                      child: Center(
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          placeholder: (_, _) =>
                              const CircularProgressIndicator(),
                          errorWidget: (_, _, _) => _DocumentPreview(
                            url: url,
                            onOpen: () => _open(url),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                PositionedDirectional(
                  bottom: 24,
                  start: 0,
                  end: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        '${_index + 1} / ${urls.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  static bool _isImage(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return const [
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
    ].any(path.endsWith);
  }

  static Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({required this.url, required this.onOpen});
  final String url;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 80,
            color: Colors.white70,
          ),
          const SizedBox(height: 16),
          const Text(
            'هذا الملف لا يدعم المعاينة داخل التطبيق.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 17),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new),
            label: const Text('فتح الملف'),
          ),
        ],
      ),
    ),
  );
}
