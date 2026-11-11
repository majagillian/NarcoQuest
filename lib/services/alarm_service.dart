import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

/// Verfügbare Wecktöne (selbst erzeugt, lizenzfrei).
class SoundOption {
  final String id;
  final String label;
  final String group;
  const SoundOption(this.id, this.label, this.group);
  String get asset => 'assets/sounds/$id.wav';
}

const List<SoundOption> kSounds = [
  SoundOption('alarm_classic', 'Klassik-Alarm', 'Laut'),
  SoundOption('siren', 'Sirene', 'Laut'),
  SoundOption('chiptune', '8-Bit-Melodie', 'Melodisch'),
  SoundOption('melody', 'Sanfte Melodie', 'Melodisch'),
  SoundOption('piano', 'Klavier', 'Melodisch'),
  SoundOption('birds', 'Vogelgezwitscher', 'Natur'),
  SoundOption('stream', 'Bach', 'Natur'),
  SoundOption('ocean', 'Meeresrauschen', 'Natur'),
];

SoundOption soundById(String id) =>
    kSounds.firstWhere((s) => s.id == id, orElse: () => kSounds.first);

/// Plant Wecker über das alarm-Paket (exakter Android-Wecker mit Vollbild).
class AlarmService {
  AlarmService._();
  static final AlarmService instance = AlarmService._();

  static const int napIdBase = 5000;

  Future<void> init() async {
    await Alarm.init();
  }

  DateTime nextOccurrence(AlarmConfig a, [DateTime? from]) {
    final now = from ?? DateTime.now();
    for (int i = 0; i <= 7; i++) {
      final d = DateTime(now.year, now.month, now.day + i, a.hour, a.minute);
      if (!d.isAfter(now)) continue;
      if (a.weekdays.isEmpty || a.weekdays.contains(d.weekday)) return d;
    }
    return DateTime(now.year, now.month, now.day + 1, a.hour, a.minute);
  }

  AlarmSettings _settings(int id, DateTime at, {required bool nap, String label = ''}) {
    final s = store.settings;
    return AlarmSettings(
      id: id,
      dateTime: at,
      assetAudioPath: soundById(s.sound).asset,
      loopAudio: true,
      vibrate: true,
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
      androidStopAlarmOnTermination: false,
      volumeSettings: s.fadeIn
          ? VolumeSettings.fade(volume: 0.9, fadeDuration: Duration(seconds: 25))
          : VolumeSettings.fixed(volume: 0.9),
      notificationSettings: NotificationSettings(
        title: nap ? 'Nap vorbei' : (label.isEmpty ? 'Guten Morgen!' : label),
        body: 'Tippe hier und löse die Aufgabe, um den Wecker auszuschalten.',
        androidStopAlarmOnDismiss: false,
      ),
      payload: jsonEncode({'nap': nap, 'label': label}),
    );
  }

  Future<void> schedule(AlarmConfig a) async {
    if (!a.enabled) {
      await cancel(a.id);
      return;
    }
    try {
      await Alarm.set(alarmSettings: _settings(a.id, nextOccurrence(a), nap: a.isNap, label: a.label));
    } catch (e) {
      debugPrint('Wecker konnte nicht gestellt werden: $e');
    }
  }

  Future<void> syncAll() async {
    for (final a in store.alarms) {
      await schedule(a);
    }
  }

  Future<void> cancel(int id) async {
    try {
      await Alarm.stop(id);
    } catch (e) {
      debugPrint('Stop fehlgeschlagen: $e');
    }
  }

  Future<int> scheduleNap(int minutes) async {
    final id = napIdBase + (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 4000;
    await Alarm.set(
      alarmSettings: _settings(id, DateTime.now().add(Duration(minutes: minutes)), nap: true),
    );
    return id;
  }

  bool isNapAlarm(AlarmSettings s) {
    if (s.id >= napIdBase) return true;
    final cfg = store.alarms.where((a) => a.id == s.id);
    return cfg.isNotEmpty && cfg.first.isNap;
  }

  String labelOf(AlarmSettings s) {
    final cfg = store.alarms.where((a) => a.id == s.id);
    if (cfg.isNotEmpty && cfg.first.label.isNotEmpty) return cfg.first.label;
    return isNapAlarm(s) ? 'Nap-Wecker' : 'Wecker';
  }

  /// Snooze: aktuellen Ton stoppen und in [minutes] erneut klingeln lassen.
  Future<void> snooze(AlarmSettings s, int minutes) async {
    await Alarm.stop(s.id);
    await Alarm.set(alarmSettings: s.copyWith(dateTime: DateTime.now().add(Duration(minutes: minutes))));
  }

  /// Wecker endgültig ausschalten und – falls wiederkehrend – neu planen.
  Future<void> dismiss(AlarmSettings s) async {
    await Alarm.stop(s.id);
    final cfg = store.alarms.where((a) => a.id == s.id).toList();
    if (cfg.isEmpty) return;
    final a = cfg.first;
    if (a.weekdays.isEmpty) {
      a.enabled = false;
      store.changed();
    } else {
      await schedule(a);
    }
  }

  /// Nächster aktiver Wecker (für die Startseite).
  (AlarmConfig, DateTime)? nextAlarm() {
    (AlarmConfig, DateTime)? best;
    for (final a in store.alarms.where((a) => a.enabled && !a.isNap)) {
      final n = nextOccurrence(a);
      if (best == null || n.isBefore(best.$2)) best = (a, n);
    }
    return best;
  }
}
