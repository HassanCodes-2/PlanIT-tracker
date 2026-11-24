import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/icons.dart';
import '../../core/widgets/load_error.dart';
import '../../data/db/app_database.dart' as db;
import '../../data/providers.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);
    final notes = notesAsync.value;

    if (notesAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notes')),
        body: LoadError(
          onRetry: () => ref.invalidate(notesProvider),
        ),
      );
    }

    if (notes == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? notes
        : notes
            .where((note) =>
                note.title.toLowerCase().contains(query) ||
                note.body.toLowerCase().contains(query))
            .toList();
    final pinned = filtered.where((note) => note.pinned).toList();
    final others = filtered.where((note) => !note.pinned).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/note'),
        tooltip: 'New note',
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search your notes',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyNotes(
                    searching: query.isNotEmpty,
                    onCreate: () => context.push('/note'),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                    children: [
                      if (pinned.isNotEmpty) ...[
                        _SectionLabel('PINNED'),
                        const SizedBox(height: 8),
                        _NoteGrid(
                          notes: pinned,
                          columns: 1,
                          extent: 150,
                          onTap: (note) => context.push('/note?id=${note.id}'),
                          onLongPress: (note) => _togglePin(note),
                        ),
                        if (others.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _SectionLabel('OTHERS'),
                          const SizedBox(height: 8),
                        ],
                      ],
                      if (others.isNotEmpty)
                        _NoteGrid(
                          notes: others,
                          onTap: (note) => context.push('/note?id=${note.id}'),
                          onLongPress: (note) => _togglePin(note),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePin(db.Note note) async {
    HapticFeedback.selectionClick();
    final repository = ref.read(repositoryProvider);
    await repository.updateNote(
      note,
      db.NotesCompanion(
        pinned: Value(!note.pinned),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _NoteGrid extends StatelessWidget {
  const _NoteGrid({
    required this.notes,
    required this.onTap,
    required this.onLongPress,
    this.columns = 2,
    this.extent = 164,
  });

  final List<db.Note> notes;
  final ValueChanged<db.Note> onTap;
  final ValueChanged<db.Note> onLongPress;
  final int columns;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale =
        MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.35);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: extent * scale,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        final digital = context.appStyle.isDigital;
        final accent = AppTheme.ensureVisible(
          colorFromHex(note.color),
          theme.cardTheme.color ?? theme.colorScheme.surface,
          theme.brightness,
          ratio: 3.2,
        );
        return Semantics(
          button: true,
          label:
              '${note.title.isEmpty ? 'Untitled note' : note.title}${note.pinned ? ', pinned' : ''}',
          onTap: () => onTap(note),
          onLongPress: () => onLongPress(note),
          child: Material(
          color: theme.cardTheme.color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(context.appStyle.cardRadius),
            side: BorderSide(
              color: digital
                  ? theme.colorScheme.outline
                  : accent.withValues(alpha: 0.55),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onTap(note),
            onLongPress: () => onLongPress(note),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: digital
                              ? theme.colorScheme.onSurfaceVariant
                              : accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note.title.isEmpty ? 'Untitled' : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: note.pinned ? 'Unpin note' : 'Pin note',
                        onPressed: () => onLongPress(note),
                        iconSize: 18,
                        icon: Icon(
                          note.pinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          color: note.pinned
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Text(
                      note.body.isEmpty ? 'No text yet' : note.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Text(
                    _relativeTime(note.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}

String _relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.searching, required this.onCreate});

  final bool searching;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.lightbulb_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              searching ? 'No matches' : 'No notes yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'Try a different word.'
                  : 'Ideas, plans, anything on your mind — capture it here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!searching) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Write a note'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}