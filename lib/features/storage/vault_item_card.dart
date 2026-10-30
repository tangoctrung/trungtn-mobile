import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../shared/app_theme.dart';
import '../../shared/ui.dart';
import 'vault_models.dart';
import 'vault_repository.dart';
import 'selection_badge.dart';

class VaultItemCard extends StatelessWidget {
  const VaultItemCard({
    super.key,
    required this.item,
    required this.repository,
    required this.onOpen,
    this.onMore,
    this.selectionMode = false,
    this.selected = false,
  });
  final VaultItem item;
  final VaultRepository repository;
  final VoidCallback onOpen;
  final VoidCallback? onMore;
  final bool selectionMode;
  final bool selected;

  Future<void> _copyText(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: item.text));
      if (context.mounted) {
        showMessage(context, 'Đã sao chép nội dung.');
      }
    } catch (_) {
      if (context.mounted) {
        showMessage(context, 'Chưa sao chép được. Hãy thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    checked: selectionMode ? selected : null,
    selected: selected,
    child: Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppTheme.ink : const Color(0xFFE3E3E3),
          width: selected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: onOpen,
            onLongPress: onMore,
            child: IgnorePointer(
              ignoring: selectionMode,
              child: item.isNote ? _note(context) : _attachment(context),
            ),
          ),
          if (selectionMode)
            Positioned(
              right: 6,
              top: 6,
              child: SelectionBadge(selected: selected),
            )
          else if (onMore != null)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                key: ValueKey('item-actions-${item.id}'),
                tooltip: 'Tùy chọn ${item.name}',
                onPressed: onMore,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.ink,
                  minimumSize: const Size(32, 32),
                  padding: const EdgeInsets.all(6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.more_horiz, size: 20),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _note(BuildContext context) {
    final theme = Theme.of(context);
    final preview = item.text.trim();
    final style = theme.textTheme.bodyMedium!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final painter = TextPainter(
            text: TextSpan(text: preview, style: style),
            maxLines: 3,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final truncated = painter.didExceedMaxLines;
          painter.dispose();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(itemIcon(item.type), size: 19),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.type == VaultItemType.richText ? 'Editor' : 'Text',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (onMore != null) const SizedBox(width: 28),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                preview.isEmpty ? 'Chưa có nội dung' : preview,
                key: ValueKey('note-preview-${item.id}'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
              if (truncated && !selectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InkWell(
                    key: ValueKey('read-more-${item.id}'),
                    onTap: onOpen,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        'Xem thêm',
                        style: theme.textTheme.labelLarge?.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('dd/MM · HH:mm')
                          .format(item.updatedAt.toLocal()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (selectionMode)
                    const SizedBox(width: 32, height: 32)
                  else
                    IconButton(
                      key: ValueKey('copy-text-${item.id}'),
                      tooltip: 'Sao chép nội dung',
                      onPressed: item.text.isEmpty
                          ? null
                          : () => _copyText(context),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        padding: const EdgeInsets.all(6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.content_copy_rounded, size: 18),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _attachment(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: item.type == VaultItemType.image
                ? _image()
                : _filePreview(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${itemTypeLabel(item.type)} · ${formatBytes(item.size)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.north_east, size: 16, color: AppTheme.muted),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _image() {
    try {
      return Image.file(
        repository.fileFor(item),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        frameBuilder: (_, child, frame, _) =>
            frame == null ? _placeholder() : child,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() => const ColoredBox(
    color: AppTheme.soft,
    child: Center(
      child: Icon(Icons.image_outlined, size: 36, color: AppTheme.muted),
    ),
  );

  Widget _filePreview(BuildContext context) {
    final extension = p
        .extension(item.name)
        .replaceFirst('.', '')
        .toUpperCase();
    return ColoredBox(
      color: AppTheme.soft,
      child: Stack(
        children: [
          Center(
            child: Icon(
              item.type == VaultItemType.video
                  ? Icons.play_circle_outline
                  : Icons.insert_drive_file_outlined,
              size: 44,
              color: AppTheme.muted,
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                extension.isEmpty ? 'FILE' : extension,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
