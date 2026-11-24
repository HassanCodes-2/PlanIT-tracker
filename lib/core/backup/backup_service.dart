import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/repositories/deed_repository.dart';

final backupServiceProvider =
    Provider<BackupService>((ref) => BackupService());

/// Exports every category, deed and log to a JSON file
/// and opens the Android share sheet so it can be saved anywhere.
class BackupService {
  Future<void> shareBackup(DeedRepository repository) async {
    final categories = await repository.allCategories();
    final deeds = await repository.allDeedsIncludingArchived();
    final logs =
        await repository.logsBetween(DateTime(2000), DateTime(2100));
    final notes = await (repository.watchNotes().first);

    final payload = {
      'app': 'planit',
      'version': 2,
      'exportedAt': DateTime.now().toIso8601String(),
      'categories': categories
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'icon': c.icon,
                'color': c.color,
                'sortOrder': c.sortOrder,
              })
          .toList(),
      'deeds': deeds
          .map((d) => {
                'id': d.id,
                'categoryId': d.categoryId,
                'parentId': d.parentId,
                'name': d.name,
                'icon': d.icon,
                'frequencyType': d.frequencyType,
                'weekdays': d.weekdays,
                'timesPerPeriod': d.timesPerPeriod,
                'reasonsEnabled': d.reasonsEnabled,
                'reminderTime': d.reminderTime,
                'sortOrder': d.sortOrder,
              })
          .toList(),
      'logs': logs
          .map((l) => {
                'deedId': l.deedId,
                'date': DateFormat('yyyy-MM-dd').format(l.day),
                'status': l.status,
                'reason': l.reason,
              })
          .toList(),
      'notes': notes
          .map((n) => {
                'title': n.title,
                'body': n.body,
                'color': n.color,
                'pinned': n.pinned,
                'createdAt': n.createdAt.toIso8601String(),
                'updatedAt': n.updatedAt.toIso8601String(),
              })
          .toList(),
    };

    final dir = await getTemporaryDirectory();
    final fileName =
        'planit-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';
    final file = File('${dir.path}/$fileName');
    await file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: 'PlanIT backup',
        text: 'Your PlanIT deeds and history.',
      ),
    );
  }
}