import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/db/app_database.dart';
import '../../domain/deed_schedule.dart';
import '../../domain/enums.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService.instance);

/// Schedules one local notification per deed reminder.
///
/// Best-effort by design: any platform failure is swallowed so the app
/// itself never breaks because of reminders.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Falls back to the timezone package default.
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(settings: settings);

    _ready = true;
  }

  /// Requests notification permission (Android 13+). Call after the first frame.
  Future<void> ensurePermission() async {
    if (!_ready) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (_) {
      // Permission is best-effort.
    }
  }

  /// Cancels and re-schedules every reminder for [deeds].
  Future<void> syncAll(List<Deed> deeds) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      for (final deed in deeds) {
        final time = deed.reminderTime;
        if (time == null || time.isEmpty) continue;

        final parts = time.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) continue;

        final frequency = FrequencyType.fromDb(deed.frequencyType);
        if (frequency == FrequencyType.weekdays) {
          for (final weekday in parseWeekdays(deed.weekdays)) {
            await _scheduleWeekly(deed, weekday, hour, minute);
          }
        } else {
          await _scheduleDaily(deed, hour, minute);
        }
      }
    } catch (_) {
      // Ignore reminder failures.
    }
  }

  Future<void> _scheduleDaily(Deed deed, int hour, int minute) {
    return _schedule(
      id: deed.id * 10,
      deed: deed,
      date: _nextTime(hour, minute),
      components: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeekly(
    Deed deed,
    int weekday,
    int hour,
    int minute,
  ) {
    return _schedule(
      id: deed.id * 10 + weekday,
      deed: deed,
      date: _nextWeekday(weekday, hour, minute),
      components: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> _schedule({
    required int id,
    required Deed deed,
    required tz.TZDateTime date,
    required DateTimeComponents components,
  }) {
    return _plugin.zonedSchedule(
      id: id,
      title: 'Time for ${deed.name}',
      body: 'Keep your streak going.',
      scheduledDate: date,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'deed_reminders',
          'Deed reminders',
          channelDescription: 'Reminders for your daily deeds',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: components,
      payload: '${deed.id}',
    );
  }

  tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextWeekday(int weekday, int hour, int minute) {
    var scheduled = _nextTime(hour, minute);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}