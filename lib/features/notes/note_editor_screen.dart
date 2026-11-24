import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.noteId});

  final int? noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen>
    with WidgetsBindingObserver {
  static const List<Color> _palette = [
    Color(0xFF1B6CFF),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
  ];

  static const List<String> _colorNames = [
    'Blue',
    'Emerald',
    'Amber',
    'Red',
    'Violet',
    'Rose',
  ];

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  db.Note? _existing;
  bool _loading = false;
  bool _saving = false;
  bool _dirty = false;
  int _revision = 0;
  Timer? _autosaveTimer;
  bool _pinned = false;
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleController.addListener(_onChanged);
    _bodyController.addListener(_onChanged);
    if (widget.noteId != null) _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _dirty) {
      _save(silent: true);
    }
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
    _dirty = false;
    _autosaveTimer?.cancel();
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

  void _onChanged() {
    _dirty = true;
    _revision++;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(milliseconds: 800), () {
      _save(silent: true);
    });
  }

  Future<void> _save({bool popAfter = false, bool silent = false}) async {
    while (_saving) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_existing != null && !_dirty) {
      if (popAfter && mounted) context.pop();
      return;
    }
    if (!mounted) return;
    if (_isEmpty) {
      if (_existing != null && silent) return;
      if (_existing != null && !silent) {
        final delete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Discard this note?'),
            content: const Text(
              'The note is empty. Delete it, or keep editing.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (delete != true) return;
        await ref.read(repositoryProvider).deleteNote(_existing!.id);
        _dirty = false;
        if (mounted) context.pop();
      } else if (!silent && mounted) {
        context.pop();
      }
      return;
    }

    setState(() => _saving = true);
    final revision = _revision;
    final repository = ref.read(repositoryProvider);
    try {
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
        _existing = await repository.noteById(id);
      } else {
        await repository.updateNote(_existing!, changes);
      }
      if (_revision == revision) {
        _dirty = false;
      }
      if (popAfter && mounted) {
        context.pop();
      } else if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the note. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exit() async {
    if (_isEmpty && widget.noteId == null) {
      context.pop();
      return;
    }
    await _save(popAfter: true);
  }

  Future<void> _delete() async {
    final theme = Theme.of(context);
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
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _dirty = false;
    if (_existing != null) {
      await ref.read(repositoryProvider).deleteNote(_existing!.id);
    }
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
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
            tooltip: 'Back',
            icon: const Icon(AppIcons.back),
            onPressed: _exit,
          ),
          title: Text(_existing == null ? 'New note' : 'Note'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: Text(
                  _saving
                      ? 'Saving…'
                      : (_dirty
                          ? 'Unsaved'
                          : (_existing != null ? 'Saved' : '')),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: _pinned ? 'Unpin' : 'Pin to top',
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _pinned = !_pinned);
                _onChanged();
              },
              icon: Icon(
                _pinned ? AppIcons.pin : AppIcons.pin,
                color: _pinned ? theme.colorScheme.primary : null,
              ),
            ),
            if (_existing != null)
              IconButton(
                tooltip: 'Delete note',
                onPressed: _delete,
                icon: Icon(AppIcons.delete,
                    color: theme.colorScheme.error),
              ),
          ],
        ),
        body: Column(
          children: [
            if (!context.appStyle.isDigital)
              Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(_palette.length, (index) {
                  final selected = index == _colorIndex;
                  return SizedBox(
                    width: 48,
                    height: 48,
                    child: Semantics(
                      button: true,
                      selected: selected,
                      label: 'Note color ${_colorNames[index]}',
                      child: InkResponse(
                        radius: 24,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _colorIndex = index);
                          _onChanged();
                        },
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _palette[index],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.outline,
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            child: selected
                                ? Icon(AppIcons.check,
                                    size: 16,
                                    color: AppTheme.onColor(_palette[index]))
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (context.appStyle.isDigital)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Note colors are available in Midnight.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                    onChanged: (_) => _onChanged(),
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
                    onChanged: (_) => _onChanged(),
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
