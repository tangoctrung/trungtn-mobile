import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../shared/ui.dart';
import 'item_viewer_screen.dart';
import 'note_editor_screen.dart';
import 'vault_models.dart';
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                            ?.copyWith(fontWeight: FontWeight.bold),
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
                IconButton(
                  key: const Key('add-folder'),
                  tooltip: 'Thêm thư mục',
                  onPressed: _importing ? null : _createFolder,
                  icon: const Icon(Icons.create_new_folder_outlined),
                ),
                if (folder != null)
                  IconButton.filled(
                    key: const Key('add-content'),
                    tooltip: 'Thêm nội dung',
                    onPressed: _importing ? null : _addContent,
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
              ],
            ),
            if (folder != null) ...[
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                        avatar: Icon(action.$2, size: 22),
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
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Đang nhập tệp…'),
            ],
            if (folders.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Nhấn đúp để mở thư mục',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) => GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: (constraints.maxWidth / 160).floor().clamp(
                      2,
                      5,
                    ),
                    mainAxisExtent: MediaQuery.textScalerOf(context).scale(180),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final entry = folders[index];
                    final selected = entry.id == _selectedId;
                    final count =
                        repository.itemsIn(entry.id).length +
                        repository.foldersIn(entry.id).length;
                    return FolderTile(
                      folder: entry,
                      count: count,
                      selected: selected,
                      onSelect: () => setState(() => _selectedId = entry.id),
                      onOpen: () => openFolder(entry),
                    );
                  },
                ),
              ),
            ],
            if (items.isNotEmpty) ...[
              SectionTitle(folder == null ? 'Gần đây' : 'Nội dung'),
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
  });
  final VaultFolder folder;
  final int count;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Thư mục ${folder.name}, $count nội dung',
      onTap: onOpen,
      child: Material(
        color: selected ? colors.primary : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(
            color: selected
                ? colors.primary
                : colors.outlineVariant.withValues(alpha: .5),
          ),
        ),
        child: InkWell(
          key: ValueKey('folder-${folder.id}'),
          borderRadius: BorderRadius.circular(28),
          onTap: onSelect,
          onDoubleTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 42,
                      color: selected ? Colors.white : colors.primary,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: selected
                          ? Colors.white60
                          : colors.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  folder.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 17,
                    color: selected ? Colors.white : colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count nội dung',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: selected ? Colors.white70 : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    leading: item.type == VaultItemType.image && repository != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              repository!.fileFor(item),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.square(
                dimension: 48,
                child: Icon(Icons.image_outlined),
              ),
            ),
          )
        : CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(itemIcon(item.type), size: 22),
          ),
    title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${folderName == null ? itemTypeLabel(item.type) : folderName!} · ${formatBytes(item.size)}\n'
      '${item.isNote && item.text.trim().isNotEmpty ? item.text.trim().replaceAll('\n', ' ') : formatDate(item.updatedAt)}',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
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
