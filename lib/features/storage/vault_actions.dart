import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../shared/ui.dart';
import 'folder_cover.dart';
import 'item_viewer_screen.dart';
import 'vault_models.dart';
import 'vault_repository.dart';

Future<void> showFolderEditor(
  BuildContext context,
  VaultRepository repository, {
  String? parentId,
  VaultFolder? folder,
}) => showDialog<void>(
  context: context,
  useRootNavigator: false,
  builder: (_) => _NameDialog(
    title: folder == null ? 'Thêm thư mục' : 'Đổi tên thư mục',
    initialName: folder?.name ?? '',
    fieldKey: const Key('folder-name'),
    label: 'Tên thư mục',
    creating: folder == null,
    onSave: (name) async {
      if (folder == null) {
        await repository.createFolder(name, parentId: parentId);
      } else {
        await repository.renameFolder(folder.id, name);
      }
    },
  ),
);

Future<String?> _chooseAction(
  BuildContext context,
  String title,
  List<(String, IconData, String)> actions,
) => showModalBottomSheet<String>(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(height: 12),
            for (final action in actions)
              ListTile(
                leading: Icon(action.$2),
                title: Text(action.$3),
                onTap: () => Navigator.pop(context, action.$1),
              ),
          ],
        ),
      ),
    ),
  ),
);

Future<void> _delete(
  BuildContext context,
  String name, {
  required bool folder,
  required Future<void> Function() onDelete,
}) async {
  await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (_) => _DeleteDialog(
      title: folder ? 'Xóa thư mục?' : 'Xóa nội dung?',
      message: folder
          ? '“$name” cùng mọi thư mục con và nội dung bên trong sẽ bị xóa khỏi máy.'
          : '“$name” sẽ bị xóa khỏi kho lưu trữ trên máy.',
      onDelete: onDelete,
    ),
  );
}

Future<bool> confirmBulkDelete(
  BuildContext context,
  VaultRepository repository, {
  required Set<String> folderIds,
  required Set<String> itemIds,
}) async {
  final folders = Set<String>.of(folderIds);
  final items = Set<String>.of(itemIds);
  final plan = repository.planDeletion(folderIds: folders, itemIds: items);
  if (plan.isEmpty) return false;
  final counts = [
    if (plan.folderIds.isNotEmpty) '${plan.folderIds.length} thư mục',
    if (plan.itemIds.isNotEmpty) '${plan.itemIds.length} nội dung',
  ].join(' và ');
  return await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (_) => _DeleteDialog(
          title: 'Xóa các mục đã chọn?',
          message:
              '$counts sẽ bị xóa khỏi máy.${folders.isNotEmpty ? ' Bao gồm toàn bộ thư mục con và nội dung bên trong.' : ''}',
          onDelete: () =>
              repository.deleteMany(folderIds: folders, itemIds: items),
        ),
      ) ??
      false;
}

Future<void> showFolderActions(
  BuildContext context,
  VaultRepository repository,
  VaultFolder folder, {
  VoidCallback? onSelect,
}) async {
  final action = await _chooseAction(context, folder.name, [
    ('rename', Icons.drive_file_rename_outline, 'Đổi tên thư mục'),
    ('cover', Icons.add_photo_alternate_outlined, 'Đổi ảnh đại diện'),
    if (onSelect != null) ('select', Icons.checklist_rounded, 'Chọn nhiều'),
    ('delete', Icons.delete_outline, 'Xóa thư mục'),
  ]);
  if (!context.mounted) return;
  switch (action) {
    case 'select':
      onSelect?.call();
    case 'rename':
      await showFolderEditor(context, repository, folder: folder);
    case 'cover':
      await chooseFolderCover(context, repository, folder);
    case 'delete':
      await _delete(
        context,
        folder.name,
        folder: true,
        onDelete: () => repository.deleteFolder(folder.id),
      );
  }
}

Future<void> showItemActions(
  BuildContext context,
  VaultRepository repository,
  VaultItem item, {
  VoidCallback? onSelect,
}) async {
  final action = await _chooseAction(context, item.name, [
    if (item.isNote) ('edit', Icons.edit_outlined, 'Chỉnh sửa nội dung'),
    ('rename', Icons.drive_file_rename_outline, 'Đổi tên'),
    if (onSelect != null) ('select', Icons.checklist_rounded, 'Chọn nhiều'),
    if (!item.isNote)
      (
        'replace',
        Icons.swap_horiz,
        'Thay ${itemTypeLabel(item.type).toLowerCase()} từ máy',
      ),
    ('delete', Icons.delete_outline, 'Xóa nội dung'),
  ]);
  if (!context.mounted) return;
  switch (action) {
    case 'select':
      onSelect?.call();
    case 'edit':
      await openVaultItem(context, repository, item);
    case 'rename':
      await showDialog<void>(
        context: context,
        useRootNavigator: false,
        builder: (_) => _NameDialog(
          title: 'Đổi tên',
          label: 'Tên nội dung',
          initialName: item.name,
          fieldKey: const Key('item-name'),
          onSave: (name) async {
            await repository.renameItem(item.id, name);
          },
        ),
      );
    case 'replace':
      try {
        final file = await FilePicker.pickFile(
          type: switch (item.type) {
            VaultItemType.image => FileType.image,
            VaultItemType.video => FileType.video,
            _ => FileType.any,
          },
        );
        if (file == null) return;
        if (file.path == null) throw const FileSystemException('Missing file');
        await repository.importFile(
          folderId: item.folderId,
          source: File(file.path!),
          name: file.name,
          replaceItemId: item.id,
        );
        if (context.mounted) {
          showMessage(context, 'Đã thay tệp và lưu trên máy.');
        }
      } catch (_) {
        if (context.mounted) {
          showMessage(
            context,
            'Chưa thay được tệp. Dữ liệu cũ vẫn được giữ lại.',
          );
        }
      }
    case 'delete':
      await _delete(
        context,
        item.name,
        folder: false,
        onDelete: () => repository.deleteItem(item.id),
      );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initialName,
    required this.label,
    required this.fieldKey,
    required this.onSave,
    this.creating = false,
  });
  final String title, initialName, label;
  final Key fieldKey;
  final bool creating;
  final Future<void> Function(String) onSave;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_controller.text);
      if (mounted) Navigator.pop(context);
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = e.message.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa lưu được. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: true,
        maxLength: 180,
        enabled: !_saving,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(labelText: widget.label, errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _saving
                ? 'Đang lưu…'
                : widget.creating
                ? 'Tạo'
                : 'Lưu',
          ),
        ),
      ],
    ),
  );
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({
    required this.title,
    required this.message,
    required this.onDelete,
  });
  final String title;
  final String message;
  final Future<void> Function() onDelete;
  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa xóa được. Hãy thử lại.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_deleting,
    child: AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!)],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('confirm-delete'),
          onPressed: _deleting ? null : _delete,
          child: Text(_deleting ? 'Đang xóa…' : 'Xóa'),
        ),
      ],
    ),
  );
}
