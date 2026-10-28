import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'vault_models.dart';

// Offline fixtures with real media files. Existing user entries are preserved.
Future<({List<VaultFolder> folders, List<VaultItem> items})> installVaultDemo(
  Directory directory,
  List<VaultFolder> existingFolders,
  List<VaultItem> existingItems,
) async {
  final folders = [...existingFolders];
  final items = [...existingItems];
  final now = DateTime.now();
  const media = [
    (asset: 'owl.jpg', name: 'Chú cú.jpg', type: VaultItemType.image),
    (asset: 'welcome.pdf', name: 'Tài liệu mẫu.pdf', type: VaultItemType.file),
    (asset: 'butterfly.mp4', name: 'Cánh bướm.mp4', type: VaultItemType.video),
  ];
  final sizes = <VaultItemType, int>{};
  for (final sample in media) {
    final bytes = await rootBundle.load('assets/demo/${sample.asset}');
    final target = File(p.join(directory.path, 'demo', sample.asset));
    await target.parent.create(recursive: true);
    await target.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    sizes[sample.type] = bytes.lengthInBytes;
  }

  const specifications = [
    (
      id: 'personal',
      name: 'Cá nhân',
      text: 'Dành một chút thời gian cho bản thân.\nGhi lại điều khiến bạn thấy vui hôm nay.',
    ),
    (
      id: 'work',
      name: 'Công việc',
      text: 'Hoàn thành công việc ưu tiên.\nChuẩn bị nội dung trao đổi.\nSắp xếp lại tài liệu.',
    ),
    (
      id: 'ideas',
      name: 'Ý tưởng',
      text: 'Một ý tưởng mới bắt đầu từ một dòng ghi chú.\nViết ra điều bạn muốn thử.',
    ),
    (
      id: 'documents',
      name: 'Tài liệu',
      text: 'Nơi lưu những tài liệu cần dùng.\nThử mở file PDF mẫu trong thư mục này.',
    ),
    (
      id: 'photos',
      name: 'Hình ảnh',
      text: 'Lưu những khoảnh khắc yêu thích.\nNhấn vào ảnh mẫu để xem và phóng to.',
    ),
    (
      id: 'videos',
      name: 'Video',
      text: 'Bộ sưu tập video của bạn.\nMở video cánh bướm để thử phát, tạm dừng và tua.',
    ),
  ];
  for (final (index, specification) in specifications.indexed) {
    final stableId = 'demo-folder-${specification.id}';
    final candidates = folders.where(
      (folder) =>
          folder.id == stableId ||
          (folder.parentId == null &&
              folder.name == specification.name &&
              existingItems.any(
                (item) =>
                    item.folderId == folder.id &&
                    item.text.contains(
                      'Đây là nội dung mẫu, bạn có thể chỉnh sửa.',
                    ),
              )),
    );
    late final VaultFolder folder;
    if (candidates.isNotEmpty) {
      folder = candidates.first;
    } else {
      var name = specification.name;
      var suffix = 1;
      while (folders.any(
        (folder) => folder.parentId == null && folder.name == name,
      )) {
        name = '${specification.name} (Mẫu ${suffix++})';
      }
      folder = VaultFolder(id: stableId, name: name, createdAt: now);
      folders.add(folder);
    }
    final date = now.subtract(Duration(hours: index));
    for (final type in [VaultItemType.text, VaultItemType.richText]) {
      if (items.any(
        (item) => item.folderId == folder.id && item.type == type,
      )) {
        continue;
      }
      final rich = type == VaultItemType.richText;
      final title = rich
          ? 'Text editor · ${specification.name}'
          : 'Ghi chú · ${specification.name}';
      final text =
          '${specification.text}\n\nĐây là nội dung mẫu, bạn có thể chỉnh sửa.\n';
      items.add(
        VaultItem(
          id: 'demo-${folder.id}-${type.name}',
          folderId: folder.id,
          name: title,
          type: type,
          text: text,
          size: utf8.encode(text).length,
          delta: rich
              ? [
                  {
                    'insert': '${specification.name}\n',
                    'attributes': {'bold': true},
                  },
                  {'insert': text},
                ]
              : null,
          createdAt: date,
          updatedAt: date,
        ),
      );
    }
    for (final sample in media) {
      if (items.any(
        (item) => item.folderId == folder.id && item.type == sample.type,
      )) {
        continue;
      }
      items.add(
        VaultItem(
          id: 'demo-${folder.id}-${sample.type.name}',
          folderId: folder.id,
          name: sample.name,
          type: sample.type,
          relativePath: p.join('demo', sample.asset),
          size: sizes[sample.type]!,
          createdAt: date,
          updatedAt: date,
        ),
      );
    }
  }
  return (folders: folders, items: items);
}
