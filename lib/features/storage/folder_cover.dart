import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../shared/ui.dart';
import 'default_folder_cover.dart';
import 'vault_models.dart';
import 'vault_repository.dart';

Future<void> chooseFolderCover(
  BuildContext context,
  VaultRepository repository,
  VaultFolder folder,
) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: false,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Ảnh đại diện thư mục',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: const Text('Chọn ảnh từ máy'),
            onTap: () => Navigator.pop(context, 'pick'),
          ),
          if (folder.coverRelativePath != null)
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Dùng ảnh mặc định'),
              onTap: () => Navigator.pop(context, 'reset'),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  if (action == null) return;
  try {
    if (action == 'reset') {
      await repository.resetFolderCover(folder.id);
    } else {
      final image = await FilePicker.pickFile(type: FileType.image);
      if (image == null) return;
      final path = image.path;
      if (path == null) throw const FileSystemException('No local image');
      await repository.setFolderCover(
        folderId: folder.id,
        source: File(path),
        name: image.name,
      );
    }
    if (context.mounted) showMessage(context, 'Đã cập nhật ảnh đại diện.');
  } catch (_) {
    if (context.mounted) {
      showMessage(
        context,
        'Không cập nhật được ảnh đại diện. Vui lòng thử lại.',
      );
    }
  }
}

class FolderCoverImage extends StatelessWidget {
  const FolderCoverImage({super.key, required this.folder, this.repository});
  final VaultFolder folder;
  final VaultRepository? repository;

  @override
  Widget build(BuildContext context) {
    File? image;
    try {
      image = repository?.folderCoverFile(folder);
    } catch (_) {
      /* Use the default cover. */
    }
    Widget fallback() => const DefaultFolderCover();
    return image == null
        ? fallback()
        : Image.file(
            image,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            gaplessPlayback: true,
            frameBuilder: (_, child, frame, _) =>
                frame == null ? fallback() : child,
            errorBuilder: (_, _, _) => fallback(),
          );
  }
}
