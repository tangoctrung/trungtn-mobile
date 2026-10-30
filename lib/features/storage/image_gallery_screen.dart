import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../shared/edge_back_gesture.dart';
import '../../shared/ui.dart';
import 'vault_models.dart';
import 'vault_repository.dart';

class ImageGalleryScreen extends StatefulWidget {
  const ImageGalleryScreen({
    super.key,
    required this.repository,
    required this.initialItem,
  });

  final VaultRepository repository;
  final VaultItem initialItem;

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen> {
  late final List<VaultItem> _images;
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _images = widget.repository
        .itemsIn(widget.initialItem.folderId)
        .where((item) => item.type == VaultItemType.image)
        .toList();
    _index = _images.indexWhere((item) => item.id == widget.initialItem.id);
    if (_index < 0) {
      _images.insert(0, widget.initialItem);
      _index = 0;
    }
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openExternally(VaultItem item) async {
    try {
      final result = await OpenFilex.open(widget.repository.fileFor(item).path);
      if (mounted && result.type != ResultType.done) {
        showMessage(context, 'Không mở được ảnh bằng ứng dụng khác.');
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không tìm thấy ứng dụng phù hợp để mở ảnh.');
      }
    }
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _images[_index].name,
        key: const Key('gallery-image-name'),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          tooltip: 'Mở bằng ứng dụng khác',
          onPressed: () => _openExternally(_images[_index]),
          icon: const Icon(Icons.open_in_new_rounded),
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        children: [
          PhotoViewGallery.builder(
            key: const Key('folder-image-gallery'),
            pageController: _controller,
            itemCount: _images.length,
            scrollPhysics: const ClampingScrollPhysics(),
            backgroundDecoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            loadingBuilder: (_, _) =>
                const Center(child: CircularProgressIndicator()),
            onPageChanged: (index) => setState(() => _index = index),
            builder: (context, index) => PhotoViewGalleryPageOptions(
              imageProvider: FileImage(
                widget.repository.fileFor(_images[index]),
              ),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 5,
              errorBuilder: (_, _, _) => EmptyState(
                icon: Icons.broken_image_outlined,
                title: 'Chưa xem được ảnh',
                message: 'Ảnh có thể đã bị xóa hoặc định dạng chưa được hỗ trợ. Bạn vẫn có thể chuyển sang ảnh khác.',
                action: TextButton(
                  onPressed: () => _openExternally(_images[index]),
                  child: const Text('Mở bằng ứng dụng khác'),
                ),
              ),
            ),
          ),
          // Reserve the same left-edge back gesture as the rest of the app.
          // Horizontal drags across the image itself belong to the gallery.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 24 + MediaQuery.paddingOf(context).left,
            child: EdgeBackGesture(
              onBack: () async {
                await Navigator.of(context).maybePop();
              },
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_images.length > 1)
              IconButton(
                key: const Key('gallery-previous'),
                tooltip: 'Ảnh trước',
                onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${_index + 1} / ${_images.length}',
                key: const Key('gallery-image-count'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (_images.length > 1)
              IconButton(
                key: const Key('gallery-next'),
                tooltip: 'Ảnh tiếp theo',
                onPressed: _index < _images.length - 1
                    ? () => _goTo(_index + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
          ],
        ),
      ),
    ),
  );
}
