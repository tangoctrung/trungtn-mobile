import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../shared/ui.dart';
import '../../shared/app_theme.dart';
import 'vault_models.dart';
import 'vault_repository.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.repository,
    required this.folderId,
    required this.richText,
    this.item,
  });
  final VaultRepository repository;
  final String folderId;
  final bool richText;
  final VaultItem? item;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _text;
  late final quill.QuillController _editor;
  late final String _initialTitle;
  late final String _initialText;
  late final String _initialDelta;
  late final StreamSubscription<quill.DocChange> _documentChanges;
  bool _documentDirty = false;
  bool _dirty = false;
  bool _saving = false;
  bool _allowPop = false;
  bool _confirmingDiscard = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item?.name ?? '');
    _text = TextEditingController(text: widget.item?.text ?? '');
    _editor = quill.QuillController.basic();
    final delta = widget.item?.delta;
    if (delta != null) _editor.document = quill.Document.fromJson(delta);
    _initialTitle = _title.text;
    _initialText = _text.text;
    _initialDelta = jsonEncode(_editor.document.toDelta().toJson());
    _title.addListener(_updateDirty);
    _text.addListener(_updateDirty);
    _documentChanges = _editor.document.changes.listen((_) {
      _documentDirty =
          jsonEncode(_editor.document.toDelta().toJson()) != _initialDelta;
      _updateDirty();
    });
  }

  void _updateDirty() {
    final dirty =
        _title.text != _initialTitle ||
        (widget.richText ? _documentDirty : _text.text != _initialText);
    if (mounted && dirty != _dirty) setState(() => _dirty = dirty);
  }

  @override
  void dispose() {
    unawaited(_documentChanges.cancel());
    _title.dispose();
    _text.dispose();
    _editor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.repository.saveNote(
        folderId: widget.folderId,
        id: widget.item?.id,
        name: _title.text,
        text: widget.richText ? _editor.document.toPlainText() : _text.text,
        richText: widget.richText,
        delta: widget.richText ? _editor.document.toDelta().toJson() : null,
      );
      if (!mounted) return;
      setState(() {
        _allowPop = true;
        _dirty = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (_) {
      if (mounted) {
        showMessage(
          context,
          'Chưa lưu được ghi chú. Nội dung vẫn được giữ ở đây, hãy thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDiscard() async {
    if (_saving || _confirmingDiscard) return;
    _confirmingDiscard = true;
    final discard = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ thay đổi chưa lưu?'),
        content: const Text(
          'Nhấn Lưu để giữ lại nội dung trước khi rời khỏi ghi chú.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Tiếp tục viết'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bỏ thay đổi'),
          ),
        ],
      ),
    );
    _confirmingDiscard = false;
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && (!_dirty || _allowPop),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmDiscard();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.richText ? 'Trình soạn thảo' : 'Văn bản thường'),
        actions: [
          TextButton.icon(
            key: const Key('save-note'),
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check_rounded),
            label: Text(_saving ? 'Đang lưu…' : 'Lưu'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: TextField(
                key: const Key('note-title'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.headlineSmall,
                decoration: const InputDecoration(
                  hintText: 'Tiêu đề ghi chú',
                  border: InputBorder.none,
                ),
              ),
            ),
            if (widget.richText) ...[
              quill.QuillSimpleToolbar(
                controller: _editor,
                config: quill.QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,
                  showFontFamily: false,
                  showFontSize: false,
                  showSearchButton: false,
                  showInlineCode: false,
                  showCodeBlock: false,
                  buttonOptions: quill.QuillSimpleToolbarButtonOptions(
                    base: quill.QuillToolbarBaseButtonOptions(
                      iconTheme: quill.QuillIconTheme(
                        iconButtonSelectedData: quill.IconButtonData(
                          color: Colors.white,
                          style: IconButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: AppTheme.ink,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        iconButtonUnselectedData: quill.IconButtonData(
                          color: AppTheme.ink,
                          style: IconButton.styleFrom(
                            foregroundColor: AppTheme.ink,
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: widget.richText
                    ? quill.QuillEditor.basic(
                        controller: _editor,
                        config: const quill.QuillEditorConfig(
                          placeholder: 'Bắt đầu viết…',
                          expands: true,
                        ),
                      )
                    : TextField(
                        key: const Key('note-body'),
                        controller: _text,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Viết nội dung ở đây…',
                          border: InputBorder.none,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
