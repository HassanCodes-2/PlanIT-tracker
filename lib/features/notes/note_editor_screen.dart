import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.noteId});

  final int? noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  static const List<Color> _palette = [
    Color(0xFF1B6CFF),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  db.Note? _existing;
  bool _loading = false;
  bool _saved = false;
  bool _pinned = false;
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.noteId != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final note = await ref.read(repositoryProvider).noteById(widget.noteId!);
    if (!mounted) return;
    if (note != null) {
      _existing = note;
      _titleController.text = note.title;
      _bodyController.text = note.body;
      _pinned = note.pinned;
      final match = _palette.indexWhere(
        (color) =>
            color.toARGB32() ==
            (colorFromHexSafe(note.color)?.toARGB32() ?? 0),
      );
      _colorIndex = match == -1 ? 0 : match;
    }
    setState(() => _loading = false);
  }

  Color? colorFromHexSafe(String hex) {
    final value = hex.replaceAll('#', '');
    if (value.length != 6) return null;
    return Color(int.parse('FF$value', radix: 16));
  }

  Color get _selectedColor => _palette[_colorIndex];

  bool get _isEmpty =>
      _titleController.text.trim().isEmpty &&
      _bodyController.text.trim().isEmpty;

  Future<void> _save({bool popAfter = true}) async {
    if (_saved) return;
    _saved = true;
    final repository = ref.read(repositoryProvider);

    if (_isEmpty) {
      if (_existing != null) await repository.deleteNote(_existing!.id);
    } else {
      final changes = db.NotesCompanion(
        title: Value(_titleController.text.trim()),
        body: Value(_bodyController.text.trim()),
        color: Value(
          '#${_selectedColor.toARGB32().toRadixString(16).substring(2, 8).toUpperCase()}',
        ),
        pinned: Value(_pinned),
        updatedAt: Value(DateTime.now()),
      );
      if (_existing == null) {
        final id = await repository.createNote(changes);
        _existing =
            await repository.noteById(id);
      } else {
        await repository.updateNote(_existing!, changes);
      }
    }
    if (popAfter && mounted) context.pop();
  }

  Future<void> _exit() async {
    // Save without popping here — this method owns the single pop.
    await _save(popAfter: false);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _saved = true;
    if (_existing != null) {
      await ref.read(repositoryProvider).deleteNote(_existing!.id);
    }
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _exit,
          ),
          title: Text(_existing == null ? 'New note' : 'Note'),
          actions: [
            IconButton(
              tooltip: _pinned ? 'Unpin' : 'Pin to top',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _pinned = !_pinned);
              },
              icon: Icon(
                _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                color: _pinned ? theme.colorScheme.primary : null,
              ),
            ),
            if (_existing != null)
              IconButton(
                tooltip: 'Delete note',
                onPressed: _delete,
                icon: Icon(Icons.delete_outline_rounded,
                    color: theme.colorScheme.error),
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_palette.length, (index) {
                  final selected = index == _colorIndex;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _colorIndex = index);
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: _palette[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white)
                      : null,
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  TextField(
                    controller: _titleController,
                    autofocus: widget.noteId == null,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (_) => _saved = false,
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _bodyController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    minLines: 12,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'Start writing… ideas, plans, anything.',
                      border: InputBorder.none,
                      filled: false,
                    ),
                    onChanged: (_) => _saved = false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}