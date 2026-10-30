import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:video_player/video_player.dart';

import '../../shared/ui.dart';
import 'image_gallery_screen.dart';
import 'note_editor_screen.dart';
import 'vault_models.dart';
import 'vault_repository.dart';

Future<void> openVaultItem(
  BuildContext context,
  VaultRepository repository,
  VaultItem item,
) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => item.isNote
          ? NoteEditorScreen(
              repository: repository,
              folderId: item.folderId,
              richText: item.type == VaultItemType.richText,
              item: item,
            )
          : item.type == VaultItemType.image
          ? ImageGalleryScreen(repository: repository, initialItem: item)
          : ItemViewerScreen(repository: repository, item: item),
    ),
  );
}

class ItemViewerScreen extends StatefulWidget {
  const ItemViewerScreen({
    super.key,
    required this.repository,
    required this.item,
  });
  final VaultRepository repository;
  final VaultItem item;

  @override
  State<ItemViewerScreen> createState() => _ItemViewerScreenState();
}

class _ItemViewerScreenState extends State<ItemViewerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  File? _file;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      _file = widget.repository.fileFor(widget.item);
      if (!await _file!.exists()) {
        throw const FileSystemException('Missing file');
      }
      if (widget.item.type == VaultItemType.video) {
        final video = VideoPlayerController.file(_file!);
        _video = video;
        await video.initialize();
      }
    } catch (_) {
      _error = 'Không xem được tệp này trong ứng dụng. Bạn có thể thử mở bằng ứng dụng khác.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_video?.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_video?.dispose());
    super.dispose();
  }

  Future<void> _openExternally() async {
    try {
      final file = widget.repository.fileFor(widget.item);
      final result = await OpenFilex.open(file.path);
      if (mounted && result.type != ResultType.done) {
        showMessage(
          context,
          'Không mở được tệp. Hãy cài ứng dụng hỗ trợ định dạng này.',
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không tìm thấy ứng dụng phù hợp để mở tệp.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(item.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Mở bằng ứng dụng khác',
            onPressed: _openExternally,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: EmptyState(
                icon: Icons.error_outline,
                title: 'Chưa có bản xem trước',
                message: _error!,
                action: TextButton(
                  onPressed: _openExternally,
                  child: const Text('Mở bằng ứng dụng khác'),
                ),
              ),
            )
          : item.type == VaultItemType.video
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _video!,
                  builder: (context, value, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AspectRatio(
                        aspectRatio: value.aspectRatio,
                        child: VideoPlayer(_video!),
                      ),
                      const SizedBox(height: 16),
                      VideoProgressIndicator(
                        _video!,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      IconButton.filled(
                        tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát video',
                        iconSize: 36,
                        onPressed: () =>
                            value.isPlaying ? _video!.pause() : _video!.play(),
                        icon: Icon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      if (value.hasError)
                        const Text(
                          'Không phát được video. Hãy thử mở bằng ứng dụng khác.',
                        ),
                    ],
                  ),
                ),
              ),
            )
          : Center(
              child: EmptyState(
                icon: itemIcon(item.type),
                title: item.name,
                message:
                    '${formatBytes(item.size)}\nĐã lưu ${formatDate(item.createdAt)}',
                action: FilledButton.icon(
                  onPressed: _openExternally,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mở tệp'),
                ),
              ),
            ),
    );
  }
}
