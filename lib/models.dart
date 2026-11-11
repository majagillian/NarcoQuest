// Datenmodelle von NarcoQuest. Alle Modelle lassen sich als JSON speichern.

List<String> _strList(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

int? _intOrNull(dynamic v) => v is num ? v.toInt() : null;

double? _doubleOrNull(dynamic v) => v is num ? v.toDouble() : null;

DateTime? _dtOrNull(dynamic v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

class Profile {
  String name;
  String? birthDate; // YYYY-MM-DD
  String gender; // weiblich, männlich, divers, keine Angabe
  String narcoType; // typ1, typ2, undiagnosed
  int? diagnosisYear;
  List<String> comorbidities;
  bool onboarded;

  Profile({
    this.name = '',
    this.birthDate,
    this.gender = 'keine Angabe',
    this.narcoType = 'typ1',
    this.diagnosisYear,
    List<String>? comorbidities,
    this.onboarded = false,
  }) : comorbidities = comorbidities ?? [];

  Map<String, dynamic> toJson() => {
        'name': name,
        'birthDate': birthDate,
        'gender': gender,
        'narcoType': narcoType,
        'diagnosisYear': diagnosisYear,
        'comorbidities': comorbidities,
        'onboarded': onboarded,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] ?? '',
        birthDate: j['birthDate'],
        gender: j['gender'] ?? 'keine Angabe',
        narcoType: j['narcoType'] ?? 'typ1',
        diagnosisYear: _intOrNull(j['diagnosisYear']),
        comorbidities: _strList(j['comorbidities']),
        onboarded: j['onboarded'] == true,
      );

  String get typeLabel => narcoType == 'typ1'
      ? 'Narkolepsie Typ 1'
      : narcoType == 'typ2'
          ? 'Narkolepsie Typ 2'
          : 'Narkolepsie (nicht diagnostiziert)';
}

class DoseChange {
  String date; // YYYY-MM-DD
  String dose;
  DoseChange(this.date, this.dose);
  Map<String, dynamic> toJson() => {'date': date, 'dose': dose};
  factory DoseChange.fromJson(Map<String, dynamic> j) =>
      DoseChange(j['date'] ?? '', j['dose'] ?? '');
}

class Medication {
  String id;
  String name;
  String ingredient;
  String dose; // z. B. "18"
  String unit; // mg, g, ml, Tablette
  List<String> times; // HH:MM
  String start; // YYYY-MM-DD
  bool active;
  bool remind;
  List<DoseChange> history;

  Medication({
    required this.id,
    required this.name,
    this.ingredient = '',
    this.dose = '',
    this.unit = 'mg',
    List<String>? times,
    required this.start,
    this.active = true,
    this.remind = true,
    List<DoseChange>? history,
  })  : times = times ?? [],
        history = history ?? [];

  String get label => '$name ${dose.isEmpty ? '' : '$dose $unit'}'.trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ingredient': ingredient,
        'dose': dose,
        'unit': unit,
        'times': times,
        'start': start,
        'active': active,
        'remind': remind,
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        ingredient: j['ingredient'] ?? '',
        dose: j['dose'] ?? '',
        unit: j['unit'] ?? 'mg',
        times: _strList(j['times']),
        start: j['start'] ?? '',
        active: j['active'] != false,
        remind: j['remind'] != false,
        history: (j['history'] as List? ?? [])
            .map((e) => DoseChange.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class MedIntake {
  String medId;
  String date; // YYYY-MM-DD
  String time; // geplante Zeit HH:MM
  DateTime takenAt;
  MedIntake(this.medId, this.date, this.time, this.takenAt);
  Map<String, dynamic> toJson() => {
        'medId': medId,
        'date': date,
        'time': time,
        'takenAt': takenAt.toIso8601String(),
      };
  factory MedIntake.fromJson(Map<String, dynamic> j) => MedIntake(
        j['medId'] ?? '',
        j['date'] ?? '',
        j['time'] ?? '',
        _dtOrNull(j['takenAt']) ?? DateTime.now(),
      );
}

class AlarmConfig {
  int id;
  int hour;
  int minute;
  List<int> weekdays; // 1=Mo..7=So, leer = einmalig
  String label;
  bool enabled;
  bool isNap;

  AlarmConfig({
    required this.id,
    required this.hour,
    required this.minute,
    List<int>? weekdays,
    this.label = '',
    this.enabled = true,
    this.isNap = false,
  }) : weekdays = weekdays ?? [];

  String get timeLabel => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays,
        'label': label,
        'enabled': enabled,
        'isNap': isNap,
      };

  factory AlarmConfig.fromJson(Map<String, dynamic> j) => AlarmConfig(
        id: _intOrNull(j['id']) ?? 1,
        hour: _intOrNull(j['hour']) ?? 7,
        minute: _intOrNull(j['minute']) ?? 0,
        weekdays: (j['weekdays'] as List? ?? []).map((e) => (e as num).toInt()).toList(),
        label: j['label'] ?? '',
        enabled: j['enabled'] != false,
        isNap: j['isNap'] == true,
      );
}

class AlarmLog {
  int alarmId;
  bool isNap;
  DateTime firstRang;
  DateTime dismissedAt;
  int snoozes;
  String task;
  int solveSeconds;
  int errors;
  int? wakeFeeling; // 1–5

  AlarmLog({
    required this.alarmId,
    required this.isNap,
    required this.firstRang,
    required this.dismissedAt,
    required this.snoozes,
    required this.task,
    required this.solveSeconds,
    required this.errors,
    this.wakeFeeling,
  });

  Map<String, dynamic> toJson() => {
        'alarmId': alarmId,
        'isNap': isNap,
        'firstRang': firstRang.toIso8601String(),
        'dismissedAt': dismissedAt.toIso8601String(),
        'snoozes': snoozes,
        'task': task,
        'solveSeconds': solveSeconds,
        'errors': errors,
        'wakeFeeling': wakeFeeling,
      };

  factory AlarmLog.fromJson(Map<String, dynamic> j) => AlarmLog(
        alarmId: _intOrNull(j['alarmId']) ?? 0,
        isNap: j['isNap'] == true,
        firstRang: _dtOrNull(j['firstRang']) ?? DateTime.now(),
        dismissedAt: _dtOrNull(j['dismissedAt']) ?? DateTime.now(),
        snoozes: _intOrNull(j['snoozes']) ?? 0,
        task: j['task'] ?? '',
        solveSeconds: _intOrNull(j['solveSeconds']) ?? 0,
        errors: _intOrNull(j['errors']) ?? 0,
        wakeFeeling: _intOrNull(j['wakeFeeling']),
      );
}

class SleepSession {
  String id;
  String type; // night, nap
  DateTime start;
  DateTime? end;
  List<DateTime> interruptions;
  bool manual;
  bool planned; // nur Naps: geplant oder Schlafattacke
  int? refreshed; // 1–5
  bool? dreamt;
  int? napAlarmId;

  SleepSession({
    required this.id,
    required this.type,
    required this.start,
    this.end,
    List<DateTime>? interruptions,
    this.manual = false,
    this.planned = true,
    this.refreshed,
    this.dreamt,
    this.napAlarmId,
  }) : interruptions = interruptions ?? [];

  bool get isNight => type == 'night';
  bool get running => end == null;
  Duration get duration => (end ?? DateTime.now()).difference(start);

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'interruptions': interruptions.map((e) => e.toIso8601String()).toList(),
        'manual': manual,
        'planned': planned,
        'refreshed': refreshed,
        'dreamt': dreamt,
        'napAlarmId': napAlarmId,
      };

  factory SleepSession.fromJson(Map<String, dynamic> j) => SleepSession(
        id: j['id'] ?? '',
        type: j['type'] ?? 'night',
        start: _dtOrNull(j['start']) ?? DateTime.now(),
        end: _dtOrNull(j['end']),
        interruptions: (j['interruptions'] as List? ?? [])
            .map((e) => DateTime.tryParse(e.toString()))
            .whereType<DateTime>()
            .toList(),
        manual: j['manual'] == true,
        planned: j['planned'] != false,
        refreshed: _intOrNull(j['refreshed']),
        dreamt: j['dreamt'] is bool ? j['dreamt'] : null,
        napAlarmId: _intOrNull(j['napAlarmId']),
      );
}

class SymptomEntry {
  String date; // YYYY-MM-DD
  String period; // morning, evening
  Map<String, int> values;
  List<String> flags;

  SymptomEntry({
    required this.date,
    required this.period,
    Map<String, int>? values,
    List<String>? flags,
  })  : values = values ?? {},
        flags = flags ?? [];

  Map<String, dynamic> toJson() =>
      {'date': date, 'period': period, 'values': values, 'flags': flags};

  factory SymptomEntry.fromJson(Map<String, dynamic> j) => SymptomEntry(
        date: j['date'] ?? '',
        period: j['period'] ?? 'morning',
        values: (j['values'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        flags: _strList(j['flags']),
      );
}

class QuickEvent {
  String id;
  String type; // cataplexy, attack
  DateTime at;
  String? severity; // leicht (Gesicht), mittel (Knie), schwer (Sturz)
  String? trigger;

  QuickEvent({required this.id, required this.type, required this.at, this.severity, this.trigger});

  Map<String, dynamic> toJson() =>
      {'id': id, 'type': type, 'at': at.toIso8601String(), 'severity': severity, 'trigger': trigger};

  factory QuickEvent.fromJson(Map<String, dynamic> j) => QuickEvent(
        id: j['id'] ?? '',
        type: j['type'] ?? 'cataplexy',
        at: _dtOrNull(j['at']) ?? DateTime.now(),
        severity: j['severity'],
        trigger: j['trigger'],
      );
}

class CycleLog {
  String date;
  String flow; // keine, Schmierblutung, leicht, mittel, stark
  List<String> sym;
  List<String> mood;
  String dis;
  double? temp;
  bool pill;

  CycleLog({
    required this.date,
    this.flow = 'keine',
    List<String>? sym,
    List<String>? mood,
    this.dis = '',
    this.temp,
    this.pill = false,
  })  : sym = sym ?? [],
        mood = mood ?? [];

  bool get isPeriod => flow == 'leicht' || flow == 'mittel' || flow == 'stark';

  bool get isEmpty =>
      flow == 'keine' && sym.isEmpty && mood.isEmpty && dis.isEmpty && temp == null && !pill;

  Map<String, dynamic> toJson() => {
        'date': date,
        'flow': flow,
        'sym': sym,
        'mood': mood,
        'dis': dis,
        'temp': temp,
        'pill': pill,
      };

  factory CycleLog.fromJson(Map<String, dynamic> j) => CycleLog(
        date: j['date'] ?? '',
        flow: j['flow'] ?? 'keine',
        sym: _strList(j['sym']),
        mood: _strList(j['mood']),
        dis: j['dis'] ?? '',
        temp: _doubleOrNull(j['temp']),
        pill: j['pill'] == true,
      );
}

class CycleSettings {
  bool enabled;
  bool setupDone;
  int baseLen;
  int basePeriod;
  String mode;
  bool reminder;

  CycleSettings({
    this.enabled = false,
    this.setupDone = false,
    this.baseLen = 28,
    this.basePeriod = 5,
    this.mode = 'Zyklus verfolgen',
    this.reminder = true,
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'setupDone': setupDone,
        'baseLen': baseLen,
        'basePeriod': basePeriod,
        'mode': mode,
        'reminder': reminder,
      };

  factory CycleSettings.fromJson(Map<String, dynamic> j) => CycleSettings(
        enabled: j['enabled'] == true,
        setupDone: j['setupDone'] == true,
        baseLen: _intOrNull(j['baseLen']) ?? 28,
        basePeriod: _intOrNull(j['basePeriod']) ?? 5,
        mode: j['mode'] ?? 'Zyklus verfolgen',
        reminder: j['reminder'] != false,
      );
}

class CalEvent {
  String id;
  String title;
  String type; // doctor, private
  DateTime start;
  String status; // planned, done, cancelled, moved
  bool? narco;
  String? reason;
  String note;

  CalEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.start,
    this.status = 'planned',
    this.narco,
    this.reason,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'start': start.toIso8601String(),
        'status': status,
        'narco': narco,
        'reason': reason,
        'note': note,
      };

  factory CalEvent.fromJson(Map<String, dynamic> j) => CalEvent(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        type: j['type'] ?? 'private',
        start: _dtOrNull(j['start']) ?? DateTime.now(),
        status: j['status'] ?? 'planned',
        narco: j['narco'] is bool ? j['narco'] : null,
        reason: j['reason'],
        note: j['note'] ?? '',
      );
}

class SickLeave {
  String id;
  String start; // YYYY-MM-DD
  String end;
  bool narco;
  String reason;
  bool certificate;

  SickLeave({
    required this.id,
    required this.start,
    required this.end,
    this.narco = false,
    this.reason = '',
    this.certificate = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'start': start,
        'end': end,
        'narco': narco,
        'reason': reason,
        'certificate': certificate,
      };

  factory SickLeave.fromJson(Map<String, dynamic> j) => SickLeave(
        id: j['id'] ?? '',
        start: j['start'] ?? '',
        end: j['end'] ?? '',
        narco: j['narco'] == true,
        reason: j['reason'] ?? '',
        certificate: j['certificate'] != false,
      );
}

class XpEntry {
  DateTime at;
  int points;
  String reason;
  XpEntry(this.at, this.points, this.reason);
  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'points': points, 'reason': reason};
  factory XpEntry.fromJson(Map<String, dynamic> j) =>
      XpEntry(_dtOrNull(j['at']) ?? DateTime.now(), _intOrNull(j['points']) ?? 0, j['reason'] ?? '');
}

class AppSettings {
  int maxSnooze;
  int snoozeMin;
  String task;
  String difficulty; // leicht, mittel
  String sound;
  bool fadeIn;
  bool missingReminder;
  int missingReminderHour;
  bool morningReminder;
  String morningTime;
  bool eveningReminder;
  String eveningTime;
  String storage; // local, webdav
  String webdavUrl;
  String webdavUser;
  String webdavPass;
  String? lastSync;

  AppSettings({
    this.maxSnooze = 3,
    this.snoozeMin = 9,
    this.task = 'Rechnen',
    this.difficulty = 'leicht',
    this.sound = 'birds',
    this.fadeIn = true,
    this.missingReminder = true,
    this.missingReminderHour = 11,
    this.morningReminder = false,
    this.morningTime = '09:00',
    this.eveningReminder = true,
    this.eveningTime = '20:30',
    this.storage = 'local',
    this.webdavUrl = '',
    this.webdavUser = '',
    this.webdavPass = '',
    this.lastSync,
  });

  Map<String, dynamic> toJson() => {
        'maxSnooze': maxSnooze,
        'snoozeMin': snoozeMin,
        'task': task,
        'difficulty': difficulty,
        'sound': sound,
        'fadeIn': fadeIn,
        'missingReminder': missingReminder,
        'missingReminderHour': missingReminderHour,
        'morningReminder': morningReminder,
        'morningTime': morningTime,
        'eveningReminder': eveningReminder,
        'eveningTime': eveningTime,
        'storage': storage,
        'webdavUrl': webdavUrl,
        'webdavUser': webdavUser,
        'webdavPass': webdavPass,
        'lastSync': lastSync,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        maxSnooze: _intOrNull(j['maxSnooze']) ?? 3,
        snoozeMin: _intOrNull(j['snoozeMin']) ?? 9,
        task: j['task'] ?? 'Rechnen',
        difficulty: j['difficulty'] ?? 'leicht',
        sound: j['sound'] ?? 'birds',
        fadeIn: j['fadeIn'] != false,
        missingReminder: j['missingReminder'] != false,
        missingReminderHour: _intOrNull(j['missingReminderHour']) ?? 11,
        morningReminder: j['morningReminder'] == true,
        morningTime: j['morningTime'] ?? '09:00',
        eveningReminder: j['eveningReminder'] != false,
        eveningTime: j['eveningTime'] ?? '20:30',
        storage: j['storage'] ?? 'local',
        webdavUrl: j['webdavUrl'] ?? '',
        webdavUser: j['webdavUser'] ?? '',
        webdavPass: j['webdavPass'] ?? '',
        lastSync: j['lastSync'],
      );
}

/// Zustand eines gerade klingelnden/gesnoozten Weckers (übersteht App-Neustarts).
class RingState {
  int alarmId;
  DateTime firstRang;
  int snoozes;
  RingState(this.alarmId, this.firstRang, this.snoozes);
  Map<String, dynamic> toJson() =>
      {'alarmId': alarmId, 'firstRang': firstRang.toIso8601String(), 'snoozes': snoozes};
  factory RingState.fromJson(Map<String, dynamic> j) => RingState(
      _intOrNull(j['alarmId']) ?? 0, _dtOrNull(j['firstRang']) ?? DateTime.now(), _intOrNull(j['snoozes']) ?? 0);
}
