import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../shared/ui.dart';
import '../../shared/app_theme.dart';
import 'item_viewer_screen.dart';
import 'folder_cover.dart';
import 'note_editor_screen.dart';
import 'vault_models.dart';
import 'vault_item_card.dart';
import 'vault_repository.dart';

class StorageScreen extends StatefulWidget {
  const StorageScreen({
    super.key,
    required this.repository,
    this.isActive = true,
  });
  final VaultRepository repository;
  final bool isActive;

  @override
  State<StorageScreen> createState() => StorageScreenState();
}

class StorageScreenState extends State<StorageScreen> {
  String? _folderId;
  String? _selectedId;
  bool _importing = false;

  void openFolder(VaultFolder folder) => setState(() {
    _folderId = folder.id;
    _selectedId = null;
  });

  void _back() => setState(() {
    _folderId = widget.repository.folder(_folderId!).parentId;
    _selectedId = null;
  });

  Future<void> _createFolder() async {
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (_) =>
          _FolderDialog(repository: widget.repository, parentId: _folderId),
    );
  }

  Future<void> _addContent() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: false,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Thêm vào thư mục',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final option in [
                  ('text', Icons.notes_rounded, 'Văn bản thường'),
                  ('richText', Icons.edit_note_rounded, 'Văn bản có định dạng'),
                  ('image', Icons.add_photo_alternate_outlined, 'Hình ảnh'),
                  ('video', Icons.video_library_outlined, 'Video'),
                  ('file', Icons.attach_file_rounded, 'Tệp khác'),
                ])
                  ListTile(
                    leading: Icon(option.$2),
                    title: Text(option.$3),
                    onTap: () => Navigator.pop(context, option.$1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    await _performAdd(action);
  }

  Future<void> _performAdd(String action) async {
    if (_importing || _folderId == null) return;
    if (action == 'text' || action == 'richText') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            repository: widget.repository,
            folderId: _folderId!,
            richText: action == 'richText',
          ),
        ),
      );
    } else {
      await _importFiles(switch (action) {
        'image' => FileType.image,
        'video' => FileType.video,
        _ => FileType.any,
      });
    }
  }

  Future<void> _importFiles(FileType type) async {
    if (_importing) return;
    final folderId = _folderId!;
    setState(() => _importing = true);
    try {
      final files = await FilePicker.pickFiles(type: type);
      int imported = 0;
      int failed = 0;
      for (final file in files) {
        try {
          final sourcePath = file.path;
          if (sourcePath == null) {
            throw const FileSystemException('No local file');
          }
          await widget.repository.importFile(
            folderId: folderId,
            source: File(sourcePath),
            name: file.name,
          );
          imported++;
        } catch (_) {
          failed++;
        }
      }
      if (mounted && files.isNotEmpty) {
        showMessage(
          context,
          failed == 0
              ? 'Đã thêm $imported tệp vào thư mục.'
              : 'Đã thêm $imported tệp, $failed tệp chưa nhập được. Hãy thử lại.',
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Không mở được trình chọn tệp. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final repository = widget.repository;
      if (repository.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (repository.error != null) {
        return Center(
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Chưa tải được lưu trữ',
            message: repository.error!,
            action: TextButton(
              onPressed: repository.load,
              child: const Text('Tải lại'),
            ),
          ),
        );
      }
      final folders = repository.foldersIn(_folderId);
      final items = _folderId == null
          ? repository.recentItems.take(3).toList()
          : repository.itemsIn(_folderId!);
      final folder = _folderId == null ? null : repository.folder(_folderId!);
      return PopScope(
        canPop: !widget.isActive || _folderId == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && widget.isActive && _folderId != null) _back();
        },
        child: ListView(
          key: const PageStorageKey('storage-list'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                if (folder != null)
                  IconButton(
                    tooltip: 'Thư mục cha',
                    onPressed: _back,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder?.name ?? 'Kho của bạn',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        folder == null
                            ? '${repository.folders.length} thư mục · ${repository.items.length} nội dung'
                            : '${folders.length} thư mục · ${items.length} nội dung',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (folder != null)
                  IconButton(
                    key: const Key('change-folder-cover'),
                    tooltip: 'Đổi ảnh đại diện',
                    onPressed: _importing
                        ? null
                        : () => chooseFolderCover(context, repository, folder),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                IconButton(
                  key: const Key('add-folder'),
                  tooltip: 'Thêm thư mục',
                  onPressed: _importing ? null : _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
                if (folder != null)
                  IconButton(
                    key: const Key('add-content'),
                    tooltip: 'Thêm nội dung',
                    onPressed: _importing ? null : _addContent,
                    icon: const Icon(Icons.add_circle_outline, size: 24),
                  ),
              ],
            ),
            if (folder != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final action in [
                    (
                      'text',
                      Icons.note_add_outlined,
                      'Text',
                      'Thêm văn bản thường',
                    ),
                    (
                      'richText',
                      Icons.post_add_rounded,
                      'Editor',
                      'Thêm text editor',
                    ),
                    (
                      'image',
                      Icons.add_photo_alternate_outlined,
                      'Ảnh',
                      'Thêm ảnh',
                    ),
                    ('file', Icons.upload_file_outlined, 'File', 'Thêm file'),
                    ('video', Icons.video_call_outlined, 'Video', 'Thêm video'),
                  ])
                    Tooltip(
                      message: action.$4,
                      child: ActionChip(
                        key: ValueKey('quick-add-${action.$1}'),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        avatar: Icon(action.$2, size: 20),
                        label: Text(action.$3),
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onPressed: _importing
                            ? null
                            : () => _performAdd(action.$1),
                      ),
                    ),
                ],
              ),
            ],
            if (_importing) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Đang nhập tệp…'),
            ],
            if (folders.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Nhấn đúp để mở thư mục',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 170).floor().clamp(
                    2,
                    5,
                  );
                  final tileWidth =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent:
                          tileWidth * 9 / 16 +
                          MediaQuery.textScalerOf(context).scale(52),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: folders.length,
                    itemBuilder: (context, index) {
                      final entry = folders[index];
                      final count =
                          repository.itemsIn(entry.id).length +
                          repository.foldersIn(entry.id).length;
                      return FolderTile(
                        folder: entry,
                        count: count,
                        selected: entry.id == _selectedId,
                        repository: repository,
                        onChangeCover: () =>
                            chooseFolderCover(context, repository, entry),
                        onSelect: () => setState(() => _selectedId = entry.id),
                        onOpen: () => openFolder(entry),
                      );
                    },
                  );
                },
              ),
            ],
            if (items.isNotEmpty) ...[
              SectionTitle(folder == null ? 'Gần đây' : 'Nội dung'),
              if (folder == null)
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final item in items)
                        VaultItemTile(
                          item: item,
                          repository: repository,
                          onTap: () => openVaultItem(context, repository, item),
                        ),
                    ],
                  ),
                )
              else
                GridView.builder(
                  key: const Key('folder-content-grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: MediaQuery.textScalerOf(context).scale(240),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) => VaultItemCard(
                    key: ValueKey('content-card-${items[index].id}'),
                    item: items[index],
                    repository: repository,
                    onOpen: () =>
                        openVaultItem(context, repository, items[index]),
                  ),
                ),
            ],
            if (folders.isEmpty && items.isEmpty)
              EmptyState(
                icon: folder == null
                    ? Icons.folder_copy_outlined
                    : Icons.folder_open_rounded,
                title: folder == null
                    ? 'Bắt đầu với một thư mục'
                    : 'Thư mục đang trống',
                message: folder == null
                    ? 'Tạo nơi lưu ghi chú, ảnh, video và những tệp quan trọng của bạn.'
                    : 'Thêm văn bản, hình ảnh, video hoặc tệp từ thiết bị.',
                action: TextButton.icon(
                  onPressed: _importing
                      ? null
                      : folder == null
                      ? _createFolder
                      : _addContent,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    folder == null ? 'Tạo thư mục đầu tiên' : 'Thêm nội dung',
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class FolderTile extends StatelessWidget {
  const FolderTile({
    super.key,
    required this.folder,
    required this.count,
    required this.onSelect,
    required this.onOpen,
    this.selected = false,
    this.repository,
    this.onChangeCover,
  });
  final VaultFolder folder;
  final int count;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;
  final VaultRepository? repository;
  final VoidCallback? onChangeCover;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Thư mục ${folder.name}, $count nội dung',
    onTap: onOpen,
    child: Stack(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            key: ValueKey('folder-${folder.id}'),
            borderRadius: BorderRadius.circular(8),
            onTap: onSelect,
            onDoubleTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FolderCoverImage(
                            folder: folder,
                            repository: repository,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.ink,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.playlist_play,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (selected)
                          const Positioned(
                            left: 6,
                            top: 6,
                            child: Icon(
                              Icons.check_circle,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '$count nội dung',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        // Keep the cover control outside the folder's double-tap recognizer.
        if (onChangeCover != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              key: ValueKey('folder-cover-${folder.id}'),
              tooltip: 'Đổi ảnh đại diện ${folder.name}',
              onPressed: onChangeCover,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                minimumSize: const Size(32, 32),
                padding: const EdgeInsets.all(6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
      ],
    ),
  );
}

class VaultItemTile extends StatelessWidget {
  const VaultItemTile({
    super.key,
    required this.item,
    required this.onTap,
    this.folderName,
    this.repository,
  });
  final VaultItem item;
  final VoidCallback onTap;
  final String? folderName;
  final VaultRepository? repository;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(vertical: 2),
    horizontalTitleGap: 12,
    minLeadingWidth: 88,
    leading: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 88,
        height: 50,
        child: item.type == VaultItemType.image && repository != null
            ? Image.file(
                repository!.fileFor(item),
                fit: BoxFit.cover,
                frameBuilder: (_, child, frame, _) =>
                    frame == null ? _placeholder() : child,
                errorBuilder: (_, _, _) => _placeholder(),
              )
            : _placeholder(),
      ),
    ),
    title: Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${folderName ?? itemTypeLabel(item.type)} · ${formatBytes(item.size)}\n'
      '${item.isNote && item.text.trim().isNotEmpty ? item.text.trim().replaceAll('\n', ' ') : formatDate(item.updatedAt)}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: const Icon(Icons.chevron_right, size: 20),
    onTap: onTap,
  );

  Widget _placeholder() => ColoredBox(
    color: AppTheme.soft,
    child: Center(
      child: Icon(
        item.type == VaultItemType.video
            ? Icons.play_circle_outline
            : itemIcon(item.type),
        size: 28,
        color: AppTheme.muted,
      ),
    ),
  );
}

class _FolderDialog extends StatefulWidget {
  const _FolderDialog({required this.repository, this.parentId});
  final VaultRepository repository;
  final String? parentId;
  @override
  State<_FolderDialog> createState() => _FolderDialogState();
}

class _FolderDialogState extends State<_FolderDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _saving = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.createFolder(
        _controller.text,
        parentId: widget.parentId,
      );
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _error = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa tạo được thư mục. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Thêm thư mục'),
    content: TextField(
      key: const Key('folder-name'),
      controller: _controller,
      autofocus: true,
      maxLength: 80,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => _create(),
      decoration: InputDecoration(labelText: 'Tên thư mục', errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _saving ? null : _create,
        child: Text(_saving ? 'Đang tạo…' : 'Tạo'),
      ),
    ],
  );
}
