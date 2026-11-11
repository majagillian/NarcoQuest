import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'logic/cycle.dart';
import 'models.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'util.dart';

/// Zentraler Datenspeicher. Alle Daten liegen als JSON-Datei im privaten
/// App-Verzeichnis auf dem Gerät. Jede Änderung wird automatisch gespeichert.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  static const int dataVersion = 1;

  Profile profile = Profile();
  List<Medication> meds = [];
  List<MedIntake> intakes = [];
  List<AlarmConfig> alarms = [];
  List<AlarmLog> alarmLogs = [];
  List<SleepSession> sleeps = [];
  List<SymptomEntry> symptoms = [];
  List<QuickEvent> quickEvents = [];
  Map<String, CycleLog> cycleLogs = {};
  CycleSettings cycle = CycleSettings();
  List<CalEvent> events = [];
  List<SickLeave> sickLeaves = [];
  List<XpEntry> xpLog = [];
  Set<String> badges = {};
  AppSettings settings = AppSettings();
  RingState? ringState;
  bool loaded = false;

  File? _file;
  Timer? _saveTimer;

  // ---------------------------------------------------------------- Laden/Speichern

  Future<void> load() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/narcoquest_data.json');
    if (await _file!.exists()) {
      try {
        final j = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _fromJson(j);
      } catch (e) {
        debugPrint('Laden fehlgeschlagen: $e');
        // Beschädigte Datei sichern, statt sie zu überschreiben.
        await _file!.copy('${dir.path}/narcoquest_data_defekt_${DateTime.now().millisecondsSinceEpoch}.json');
      }
    }
    loaded = true;
    notifyListeners();
  }

  void _fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (j[key] as List? ?? []).map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    profile = j['profile'] is Map ? Profile.fromJson(Map<String, dynamic>.from(j['profile'])) : Profile();
    meds = list('meds', Medication.fromJson);
    intakes = list('intakes', MedIntake.fromJson);
    alarms = list('alarms', AlarmConfig.fromJson);
    alarmLogs = list('alarmLogs', AlarmLog.fromJson);
    sleeps = list('sleeps', SleepSession.fromJson);
    symptoms = list('symptoms', SymptomEntry.fromJson);
    quickEvents = list('quickEvents', QuickEvent.fromJson);
    cycleLogs = {
      for (final l in list('cycleLogs', CycleLog.fromJson)) l.date: l,
    };
    cycle = j['cycle'] is Map ? CycleSettings.fromJson(Map<String, dynamic>.from(j['cycle'])) : CycleSettings();
    events = list('events', CalEvent.fromJson);
    sickLeaves = list('sickLeaves', SickLeave.fromJson);
    xpLog = list('xpLog', XpEntry.fromJson);
    badges = (j['badges'] as List? ?? []).map((e) => e.toString()).toSet();
    settings = j['settings'] is Map ? AppSettings.fromJson(Map<String, dynamic>.from(j['settings'])) : AppSettings();
    ringState = j['ringState'] is Map ? RingState.fromJson(Map<String, dynamic>.from(j['ringState'])) : null;
  }

  Map<String, dynamic> toJson({bool includeSecrets = true}) {
    final s = settings.toJson();
    if (!includeSecrets) s['webdavPass'] = '';
    return {
      'app': 'NarcoQuest',
      'version': dataVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile.toJson(),
      'meds': meds.map((e) => e.toJson()).toList(),
      'intakes': intakes.map((e) => e.toJson()).toList(),
      'alarms': alarms.map((e) => e.toJson()).toList(),
      'alarmLogs': alarmLogs.map((e) => e.toJson()).toList(),
      'sleeps': sleeps.map((e) => e.toJson()).toList(),
      'symptoms': symptoms.map((e) => e.toJson()).toList(),
      'quickEvents': quickEvents.map((e) => e.toJson()).toList(),
      'cycleLogs': cycleLogs.values.map((e) => e.toJson()).toList(),
      'cycle': cycle.toJson(),
      'events': events.map((e) => e.toJson()).toList(),
      'sickLeaves': sickLeaves.map((e) => e.toJson()).toList(),
      'xpLog': xpLog.map((e) => e.toJson()).toList(),
      'badges': badges.toList(),
      'settings': s,
      'ringState': ringState?.toJson(),
    };
  }

  /// Daten aus einer Sicherung übernehmen (ersetzt alle aktuellen Daten).
  Future<void> importJson(Map<String, dynamic> j) async {
    if (j['app'] != 'NarcoQuest') {
      throw const FormatException('Das ist keine NarcoQuest-Sicherung.');
    }
    final keepPass = settings.webdavPass;
    _fromJson(j);
    if (settings.webdavPass.isEmpty) settings.webdavPass = keepPass;
    ringState = null;
    await saveNow();
    notifyListeners();
    await AlarmService.instance.syncAll();
    await NotificationService.instance.refreshAll();
  }

  void changed({bool reschedule = false}) {
    _checkBadges();
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), saveNow);
    if (reschedule) {
      NotificationService.instance.refreshAll();
    }
  }

  Future<void> saveNow() async {
    _saveTimer?.cancel();
    if (_file == null) return;
    final tmp = File('${_file!.path}.tmp');
    await tmp.writeAsString(jsonEncode(toJson()), flush: true);
    await tmp.rename(_file!.path);
  }

  Future<void> deleteAll() async {
    for (final a in alarms) {
      await AlarmService.instance.cancel(a.id);
    }
    profile = Profile();
    meds = [];
    intakes = [];
    alarms = [];
    alarmLogs = [];
    sleeps = [];
    symptoms = [];
    quickEvents = [];
    cycleLogs = {};
    cycle = CycleSettings();
    events = [];
    sickLeaves = [];
    xpLog = [];
    badges = {};
    settings = AppSettings();
    ringState = null;
    await saveNow();
    await NotificationService.instance.cancelAll();
    notifyListeners();
  }

  // ---------------------------------------------------------------- Punkte

  int get xp => xpLog.fold(0, (a, b) => a + b.points);
  int get level => xp ~/ 100 + 1;
  int get xpInLevel => xp % 100;

  void addXp(int points, String reason) {
    xpLog.add(XpEntry(DateTime.now(), points, reason));
  }

  /// Punkte nur einmal pro Tag und Grund vergeben.
  void addXpOncePerDay(int points, String reason) {
    final k = dkey(DateTime.now());
    if (xpLog.any((e) => e.reason == reason && dkey(e.at) == k)) return;
    addXp(points, reason);
  }

  void _checkBadges() {
    void award(String key, bool cond) {
      if (cond && !badges.contains(key)) {
        badges.add(key);
        addXp(20, 'Abzeichen: $key');
      }
    }

    final nights = sleeps.where((s) => s.isNight && !s.running).length;
    award('Erste Nacht erfasst', nights >= 1);
    award('7 Nächte erfasst', nights >= 7);
    award('30 Nächte erfasst', nights >= 30);
    award('100 Nächte erfasst', nights >= 100);
    award('Erster Arztbericht', xpLog.any((e) => e.reason == 'Arztbericht'));
    award('Erster Abend-Check', symptoms.any((s) => s.period == 'evening'));
    award('Ohne Snooze aufgestanden', alarmLogs.any((l) => !l.isNap && l.snoozes == 0));
    if (cycle.enabled) {
      final cm = cycleModel;
      award('Erster Zyklus komplett', cm.lens.isNotEmpty);
    }
    award('Woche durchgetrackt', trackedDaysLast7 >= 7);
  }

  int get trackedDaysLast7 {
    final t = today();
    int n = 0;
    for (int i = 0; i < 7; i++) {
      final d = dkey(addDays(t, -i));
      if (symptoms.any((s) => s.date == d) ||
          sleeps.any((s) => s.end != null && dkey(s.end!) == d)) {
        n++;
      }
    }
    return n;
  }

  int eveningChecksThisWeek() {
    final t = today();
    final monday = addDays(t, -(t.weekday - 1));
    return symptoms
        .where((s) => s.period == 'evening' && !parseKey(s.date).isBefore(monday))
        .length;
  }

  // ---------------------------------------------------------------- Schlaf

  SleepSession? get activeNight {
    for (final s in sleeps) {
      if (s.isNight && s.running) return s;
    }
    return null;
  }

  SleepSession? get activeNap {
    for (final s in sleeps) {
      if (!s.isNight && s.running) return s;
    }
    return null;
  }

  void startSleep() {
    sleeps.add(SleepSession(id: newId(), type: 'night', start: DateTime.now()));
    changed();
  }

  void addInterruption() {
    activeNight?.interruptions.add(DateTime.now());
    changed();
  }

  SleepSession? endSleep([DateTime? at]) {
    final s = activeNight;
    if (s == null) return null;
    s.end = at ?? DateTime.now();
    addXp(10, 'Schlaf erfasst');
    changed(reschedule: true);
    return s;
  }

  void cancelActiveSleep() {
    final s = activeNight;
    if (s != null) sleeps.remove(s);
    changed();
  }

  void addManualNight(DateTime start, DateTime end, int interruptions) {
    final mid = start.add(end.difference(start) ~/ 2);
    sleeps.add(SleepSession(
      id: newId(),
      type: 'night',
      start: start,
      end: end,
      manual: true,
      interruptions: List.generate(interruptions, (_) => mid),
    ));
    addXp(5, 'Nacht nachgetragen');
    changed(reschedule: true);
  }

  /// Nacht, die am angegebenen Tag endete (Aufwachtag).
  SleepSession? nightEndingOn(DateTime day) {
    final k = dkey(day);
    for (final s in sleeps.reversed) {
      if (s.isNight && s.end != null && dkey(s.end!) == k) return s;
    }
    return null;
  }

  bool get lastNightMissing {
    final now = DateTime.now();
    if (now.hour < 5) return false;
    if (activeNight != null) return false;
    return nightEndingOn(today()) == null;
  }

  Future<SleepSession> startNap(int minutes, {required bool planned}) async {
    final id = await AlarmService.instance.scheduleNap(minutes);
    final s = SleepSession(
      id: newId(),
      type: 'nap',
      start: DateTime.now(),
      planned: planned,
      napAlarmId: id,
    );
    sleeps.add(s);
    changed();
    return s;
  }

  void addPastNap(DateTime start, DateTime end, {required bool planned}) {
    sleeps.add(SleepSession(id: newId(), type: 'nap', start: start, end: end, planned: planned, manual: true));
    addXp(5, 'Nap erfasst');
    changed();
  }

  Future<void> endNap({int? refreshed, bool? dreamt}) async {
    final s = activeNap;
    if (s == null) return;
    s.end = DateTime.now();
    s.refreshed = refreshed;
    s.dreamt = dreamt;
    if (s.napAlarmId != null) {
      await AlarmService.instance.cancel(s.napAlarmId!);
    }
    addXp(5, 'Nap erfasst');
    changed();
  }

  void deleteSleep(SleepSession s) {
    sleeps.remove(s);
    changed();
  }

  // ---------------------------------------------------------------- Symptome

  SymptomEntry? symptomFor(String date, String period) {
    for (final s in symptoms) {
      if (s.date == date && s.period == period) return s;
    }
    return null;
  }

  void saveSymptoms(SymptomEntry e) {
    final existing = symptomFor(e.date, e.period);
    if (existing != null) {
      existing.values = e.values;
      existing.flags = e.flags;
    } else {
      symptoms.add(e);
      addXp(10, e.period == 'morning' ? 'Morgen-Check' : 'Abend-Check');
    }
    changed();
  }

  void addQuickEvent(String type, {String? severity, String? trigger, DateTime? at}) {
    quickEvents.add(QuickEvent(id: newId(), type: type, at: at ?? DateTime.now(), severity: severity, trigger: trigger));
    addXpOncePerDay(2, 'Schnellerfassung');
    changed();
  }

  int quickCountOn(String type, DateTime day) {
    final k = dkey(day);
    return quickEvents.where((q) => q.type == type && dkey(q.at) == k).length;
  }

  // ---------------------------------------------------------------- Medikamente

  void saveMed(Medication m) {
    final i = meds.indexWhere((x) => x.id == m.id);
    if (i >= 0) {
      final old = meds[i];
      if (old.dose != m.dose || old.unit != m.unit) {
        m.history.add(DoseChange(dkey(DateTime.now()), '${m.dose} ${m.unit}'));
      }
      meds[i] = m;
    } else {
      m.history.add(DoseChange(m.start, '${m.dose} ${m.unit}'));
      meds.add(m);
    }
    changed(reschedule: true);
  }

  void deleteMed(Medication m) {
    meds.removeWhere((x) => x.id == m.id);
    changed(reschedule: true);
  }

  bool isTaken(String medId, String date, String time) =>
      intakes.any((i) => i.medId == medId && i.date == date && i.time == time);

  void toggleIntake(String medId, String date, String time) {
    final i = intakes.indexWhere((x) => x.medId == medId && x.date == date && x.time == time);
    if (i >= 0) {
      intakes.removeAt(i);
    } else {
      intakes.add(MedIntake(medId, date, time, DateTime.now()));
      addXp(2, 'Medikament genommen');
    }
    changed();
  }

  // ---------------------------------------------------------------- Wecker

  int _nextAlarmId() {
    int id = 1;
    while (alarms.any((a) => a.id == id)) {
      id++;
    }
    return id;
  }

  AlarmConfig newAlarm() => AlarmConfig(id: _nextAlarmId(), hour: 7, minute: 0, weekdays: [1, 2, 3, 4, 5]);

  Future<void> saveAlarm(AlarmConfig a) async {
    final i = alarms.indexWhere((x) => x.id == a.id);
    if (i >= 0) {
      alarms[i] = a;
    } else {
      alarms.add(a);
    }
    changed();
    await AlarmService.instance.schedule(a);
  }

  Future<void> deleteAlarm(AlarmConfig a) async {
    alarms.removeWhere((x) => x.id == a.id);
    changed();
    await AlarmService.instance.cancel(a.id);
  }

  void logAlarm(AlarmLog l) {
    alarmLogs.add(l);
    if (!l.isNap && l.snoozes == 0) addXp(5, 'Ohne Snooze aufgestanden');
    ringState = null;
    changed();
  }

  // ---------------------------------------------------------------- Zyklus

  CycleModel get cycleModel => CycleModel(cycleLogs, cycle.baseLen, cycle.basePeriod);

  CycleLog cycleLogFor(DateTime d) => cycleLogs[dkey(d)] ?? CycleLog(date: dkey(d));

  void saveCycleLog(CycleLog l) {
    if (l.isEmpty) {
      cycleLogs.remove(l.date);
    } else {
      final isNew = !cycleLogs.containsKey(l.date);
      cycleLogs[l.date] = l;
      if (isNew) addXpOncePerDay(3, 'Zyklus-Eintrag');
    }
    changed(reschedule: true);
  }

  /// Periode ab [start] für [days] Tage eintragen (nur bis heute).
  void logPeriod(DateTime start, int days) {
    final t = today();
    for (int i = 0; i < days; i++) {
      final d = addDays(start, i);
      if (d.isAfter(t)) break;
      final l = cycleLogFor(d);
      l.flow = i < 2 ? 'stark' : (i < 3 ? 'mittel' : 'leicht');
      cycleLogs[l.date] = l;
    }
    addXpOncePerDay(3, 'Zyklus-Eintrag');
    changed(reschedule: true);
  }

  // ---------------------------------------------------------------- Kalender & Krankmeldungen

  void saveEvent(CalEvent e) {
    final i = events.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      events[i] = e;
    } else {
      events.add(e);
    }
    changed();
  }

  void deleteEvent(CalEvent e) {
    events.removeWhere((x) => x.id == e.id);
    changed();
  }

  void saveSickLeave(SickLeave s) {
    final i = sickLeaves.indexWhere((x) => x.id == s.id);
    if (i >= 0) {
      sickLeaves[i] = s;
    } else {
      sickLeaves.add(s);
    }
    changed();
  }

  void deleteSickLeave(SickLeave s) {
    sickLeaves.removeWhere((x) => x.id == s.id);
    changed();
  }

  int sickDays(SickLeave s, {int? year}) {
    final a = parseKey(s.start), b = parseKey(s.end);
    int n = 0;
    for (var d = a; !d.isAfter(b); d = addDays(d, 1)) {
      if (year == null || d.year == year) n++;
    }
    return n;
  }
}

final store = AppStore.instance;
