import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../store.dart';
import '../util.dart';

/// Erinnerungen: fehlender Schlaf-Eintrag, Morgen-/Abend-Check,
/// Medikamente und anstehende Periode.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const int idMissingSleep = 100;
  static const int idMorning = 101;
  static const int idEvening = 102;
  static const int idPeriod = 103;
  static const int idMedBase = 200; // 200..299

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'erinnerungen',
      'Erinnerungen',
      channelDescription: 'Erinnerungen an Einträge und Medikamente',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(_guessLocation());
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Benachrichtigungen nicht verfügbar: $e');
    }
  }

  /// Zeitzone anhand des aktuellen UTC-Offsets bestimmen (Europe/Berlin bevorzugt).
  tz.Location _guessLocation() {
    final offset = DateTime.now().timeZoneOffset.inMilliseconds;
    const preferred = ['Europe/Berlin', 'Europe/Vienna', 'Europe/Zurich', 'Europe/London', 'UTC'];
    for (final name in preferred) {
      final loc = tz.getLocation(name);
      if (tz.TZDateTime.now(loc).timeZoneOffset.inMilliseconds == offset) return loc;
    }
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(loc).timeZoneOffset.inMilliseconds == offset) return loc;
    }
    return tz.UTC;
  }

  tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  Future<void> _daily(int id, String title, String body, String hhmm) async {
    final p = hhmm.split(':');
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextTime(int.parse(p[0]), int.parse(p[1])),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _once(int id, String title, String body, DateTime at) async {
    if (!at.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(at, tz.local),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Alle Erinnerungen neu planen (nach jeder relevanten Änderung).
  Future<void> refreshAll() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final s = store.settings;

      // Fehlender Nachtschlaf: heute um X Uhr, falls noch kein Eintrag – sonst morgen.
      if (s.missingReminder && store.profile.onboarded) {
        final t = today();
        var day = store.nightEndingOn(t) == null && store.activeNight == null ? t : addDays(t, 1);
        var at = DateTime(day.year, day.month, day.day, s.missingReminderHour);
        if (!at.isAfter(DateTime.now())) {
          day = addDays(t, 1);
          at = DateTime(day.year, day.month, day.day, s.missingReminderHour);
        }
        await _once(idMissingSleep, 'Schlaf nachtragen?',
            'Für letzte Nacht fehlt noch dein Schlaf-Eintrag. Tippe hier, um ihn nachzutragen.', at);
      }
      if (s.morningReminder) {
        await _daily(idMorning, 'Morgen-Check', 'Wie war deine Nacht? Das dauert nur 30 Sekunden.', s.morningTime);
      }
      if (s.eveningReminder) {
        await _daily(idEvening, 'Abend-Check', 'Wie war dein Tag? Trage deine Symptome ein.', s.eveningTime);
      }
      int i = 0;
      for (final m in store.meds.where((m) => m.active && m.remind)) {
        for (final time in m.times) {
          if (i >= 99) break;
          await _daily(idMedBase + i, 'Medikament: ${m.label}', 'Geplant um $time Uhr. Tippe in der App auf „Genommen“.', time);
          i++;
        }
      }
      if (store.cycle.enabled && store.cycle.reminder) {
        final cm = store.cycleModel;
        if (cm.nextStart != null) {
          final d = addDays(cm.nextStart!, -2);
          await _once(idPeriod, 'Periode in 2 Tagen', 'Laut Vorhersage beginnt deine Periode bald.',
              DateTime(d.year, d.month, d.day, 9));
        }
      }
    } catch (e) {
      debugPrint('Erinnerungen konnten nicht geplant werden: $e');
    }
  }
}
