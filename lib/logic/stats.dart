import 'dart:math' as math;

import '../models.dart';
import '../store.dart';
import '../util.dart';

/// Eine Nacht mit berechneten Kennzahlen.
class NightStat {
  final DateTime wakeDay;
  final SleepSession session;
  final double hours;
  final int interruptions;
  final int? quality;
  final int score;
  NightStat(this.wakeDay, this.session, this.hours, this.interruptions, this.quality, this.score);
}

class Insight {
  final String title;
  final String text;
  Insight(this.title, this.text);
}

class PhaseStat {
  final String phase;
  final double? sleepiness;
  final double? cataplexy;
  final int n;
  PhaseStat(this.phase, this.sleepiness, this.cataplexy, this.n);
}

class MedChangeStat {
  final String med;
  final String date;
  final String dose;
  final double? sleepBefore, sleepAfter, cataBefore, cataAfter;
  final int nBefore, nAfter;
  MedChangeStat(this.med, this.date, this.dose, this.sleepBefore, this.sleepAfter, this.cataBefore,
      this.cataAfter, this.nBefore, this.nAfter);
}

/// Narkolepsie-Statistik: wertet Schlaf, Naps, Symptome, Wecker, Zyklus und Arbeit aus.
/// Alle Auswertungen sind beschreibend – keine Therapie- oder Dosisempfehlungen.
class Stats {
  final AppStore s;
  final int days;
  late final DateTime from;
  late final DateTime to;

  Stats(this.s, {this.days = 30}) {
    to = today();
    from = addDays(to, -(days - 1));
  }

  bool _inRange(DateTime d) => !dateOnly(d).isBefore(from) && !dateOnly(d).isAfter(to);

  // ------------------------------------------------------------ Schlaf

  static int sleepScore(double hours, int interruptions, int? quality, double? bedtimeDev) {
    double sc = 0;
    // Dauer: 7–9 h ideal (40 Punkte)
    if (hours >= 7 && hours <= 9) {
      sc += 40;
    } else if (hours < 7) {
      sc += math.max(0, 40 - (7 - hours) * 12);
    } else {
      sc += math.max(0, 40 - (hours - 9) * 8);
    }
    // Unterbrechungen (25)
    sc += math.max(0, 25 - interruptions * 5);
    // Gefühlte Qualität (25), ohne Angabe neutral
    sc += quality != null ? quality * 2.5 : 12.5;
    // Regelmäßigkeit (10)
    if (bedtimeDev == null || bedtimeDev <= 45) {
      sc += 10;
    } else if (bedtimeDev <= 90) {
      sc += 5;
    }
    return math.min(100, math.max(0, sc.round()));
  }

  /// Einschlafzeit als Minuten ab 12:00 Uhr (damit Mitternacht kein Sprung ist).
  static int bedMinutes(DateTime d) {
    final m = d.hour * 60 + d.minute;
    return m < 12 * 60 ? m + 12 * 60 : m - 12 * 60;
  }

  List<NightStat> get nights {
    final ns = s.sleeps.where((x) => x.isNight && x.end != null && _inRange(x.end!)).toList()
      ..sort((a, b) => a.end!.compareTo(b.end!));
    final beds = ns.map((n) => bedMinutes(n.start)).toList()..sort();
    final median = beds.isEmpty ? null : beds[beds.length ~/ 2];
    return ns.map((n) {
      final h = n.duration.inMinutes / 60.0;
      final q = s.symptomFor(dkey(n.end!), 'morning')?.values['quality'];
      final dev = median == null ? null : (bedMinutes(n.start) - median).abs().toDouble();
      return NightStat(dateOnly(n.end!), n, h, n.interruptions.length, q, sleepScore(h, n.interruptions.length, q, dev));
    }).toList();
  }

  double? get avgSleepHours {
    final n = nights;
    return n.isEmpty ? null : mean(n.map((e) => e.hours).toList());
  }

  double? get avgInterruptions {
    final n = nights;
    return n.isEmpty ? null : mean(n.map((e) => e.interruptions).toList());
  }

  int? get avgScore {
    final n = nights;
    return n.isEmpty ? null : mean(n.map((e) => e.score).toList()).round();
  }

  /// Streuung der Einschlafzeit in Minuten.
  double? get bedtimeSpread {
    final n = nights;
    if (n.length < 3) return null;
    return stddev(n.map((e) => bedMinutes(e.session.start)).toList());
  }

  List<SleepSession> get naps =>
      s.sleeps.where((x) => !x.isNight && x.end != null && _inRange(x.start)).toList();

  double get napsPerDay => naps.length / days;

  double? get unplannedNapShare {
    final n = naps;
    if (n.isEmpty) return null;
    return n.where((x) => !x.planned).length / n.length;
  }

  // ------------------------------------------------------------ Symptome

  List<SymptomEntry> entries(String period) => s.symptoms
      .where((e) => e.period == period && _inRange(parseKey(e.date)))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  double? avgValue(String period, String key) {
    final v = entries(period).map((e) => e.values[key]).whereType<int>().toList();
    return v.isEmpty ? null : mean(v);
  }

  /// Kataplexien pro Tag: Maximum aus Abend-Angabe und Schnellerfassungen.
  int? cataOn(DateTime d) {
    final ev = s.symptomFor(dkey(d), 'evening')?.values['cata'];
    final q = s.quickCountOn('cataplexy', d);
    if (ev == null && q == 0) return null;
    return math.max(ev ?? 0, q);
  }

  double? get cataPerDay {
    final v = <int>[];
    for (var d = from; !d.isAfter(to); d = addDays(d, 1)) {
      final c = cataOn(d);
      if (c != null) v.add(c);
    }
    return v.isEmpty ? null : mean(v);
  }

  int get attacks => s.quickEvents.where((q) => q.type == 'attack' && _inRange(q.at)).length;

  /// Häufigkeit der Häkchen (z. B. Schlafparalyse) in %.
  Map<String, int> flagCounts(String period) {
    final m = <String, int>{};
    for (final e in entries(period)) {
      for (final f in e.flags) {
        m[f] = (m[f] ?? 0) + 1;
      }
    }
    return m;
  }

  Map<String, int> get cataTriggers {
    final m = <String, int>{};
    for (final q in s.quickEvents.where((q) => q.type == 'cataplexy' && _inRange(q.at) && q.trigger != null)) {
      m[q.trigger!] = (m[q.trigger!] ?? 0) + 1;
    }
    return m;
  }

  /// Tagesschläfrigkeit der letzten [n] Tage (null = kein Eintrag).
  List<(DateTime, int?)> sleepinessSeries(int n) {
    final out = <(DateTime, int?)>[];
    for (int i = n - 1; i >= 0; i--) {
      final d = addDays(to, -i);
      out.add((d, s.symptomFor(dkey(d), 'evening')?.values['sleepy']));
    }
    return out;
  }

  // ------------------------------------------------------------ Medikamente

  double? get adherence {
    int planned = 0, taken = 0;
    for (final m in s.meds.where((m) => m.active)) {
      final start = parseKey(m.start.isEmpty ? dkey(from) : m.start);
      for (var d = from; !d.isAfter(to); d = addDays(d, 1)) {
        if (d.isBefore(start)) continue;
        for (final t in m.times) {
          if (d == to && _timeAfterNow(t)) continue;
          planned++;
          if (s.isTaken(m.id, dkey(d), t)) taken++;
        }
      }
    }
    return planned == 0 ? null : taken / planned;
  }

  bool _timeAfterNow(String hhmm) {
    final p = hhmm.split(':');
    final now = DateTime.now();
    return int.parse(p[0]) * 60 + int.parse(p[1]) > now.hour * 60 + now.minute;
  }

  List<MedChangeStat> get medChanges {
    final out = <MedChangeStat>[];
    for (final m in s.meds) {
      for (int i = 1; i < m.history.length; i++) {
        final h = m.history[i];
        final d = parseKey(h.date);
        final before = <int>[], after = <int>[], cb = <int>[], ca = <int>[];
        for (int k = 1; k <= 14; k++) {
          final b = addDays(d, -k), a = addDays(d, k - 1);
          final sb = s.symptomFor(dkey(b), 'evening')?.values['sleepy'];
          final sa = s.symptomFor(dkey(a), 'evening')?.values['sleepy'];
          if (sb != null) before.add(sb);
          if (sa != null) after.add(sa);
          final xb = cataOn(b), xa = cataOn(a);
          if (xb != null) cb.add(xb);
          if (xa != null) ca.add(xa);
        }
        out.add(MedChangeStat(
          m.name,
          h.date,
          h.dose,
          before.isEmpty ? null : mean(before),
          after.isEmpty ? null : mean(after),
          cb.isEmpty ? null : mean(cb),
          ca.isEmpty ? null : mean(ca),
          before.length,
          after.length,
        ));
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  // ------------------------------------------------------------ Wecker

  List<AlarmLog> get morningAlarms =>
      s.alarmLogs.where((l) => !l.isNap && _inRange(l.dismissedAt)).toList();

  double? get avgSnoozes {
    final l = morningAlarms;
    return l.isEmpty ? null : mean(l.map((e) => e.snoozes).toList());
  }

  double? get avgSolveSeconds {
    final l = morningAlarms;
    return l.isEmpty ? null : mean(l.map((e) => e.solveSeconds).toList());
  }

  double? get avgTaskErrors {
    final l = morningAlarms;
    return l.isEmpty ? null : mean(l.map((e) => e.errors).toList());
  }

  // ------------------------------------------------------------ Arbeit

  int sickDaysYear(int year, {bool? narco}) => s.sickLeaves
      .where((x) => narco == null || x.narco == narco)
      .fold(0, (a, b) => a + s.sickDays(b, year: year));

  int get narcoCancellations => s.events
      .where((e) => (e.status == 'cancelled' || e.status == 'moved') && e.narco == true && _inRange(e.start))
      .length;

  // ------------------------------------------------------------ Zyklus

  List<PhaseStat> get phaseStats {
    if (!s.cycle.enabled) return [];
    final cm = s.cycleModel;
    if (!cm.hasData) return [];
    final buckets = <String, List<int>>{};
    final cbuckets = <String, List<int>>{};
    // Längerer Zeitraum für Zyklusvergleich: 120 Tage
    final start = addDays(to, -119);
    for (var d = start; !d.isAfter(to); d = addDays(d, 1)) {
      final ph = cm.phaseOf(d);
      if (ph == null) continue;
      final v = s.symptomFor(dkey(d), 'evening')?.values['sleepy'];
      if (v != null) (buckets[ph] ??= []).add(v);
      final c = cataOn(d);
      if (c != null) (cbuckets[ph] ??= []).add(c);
    }
    return ['Menstruation', 'Follikel', 'Eisprung', 'Luteal'].map((p) {
      final b = buckets[p] ?? [];
      final c = cbuckets[p] ?? [];
      return PhaseStat(p, b.isEmpty ? null : mean(b), c.isEmpty ? null : mean(c), b.length);
    }).toList();
  }

  // ------------------------------------------------------------ Zusammenhänge

  List<Insight> get insights {
    final out = <Insight>[];
    const hint = ' Besprich das bei Gelegenheit mit deiner Ärztin oder deinem Arzt.';

    // Schlafdauer -> Schläfrigkeit am Folgetag
    final xs = <num>[], ys = <num>[];
    for (final n in nights) {
      final v = s.symptomFor(dkey(n.wakeDay), 'evening')?.values['sleepy'];
      if (v != null) {
        xs.add(n.hours);
        ys.add(v);
      }
    }
    if (xs.length >= 10) {
      final r = spearman(xs, ys);
      if (r <= -0.3) {
        out.add(Insight('Schlaf und Tagesmüdigkeit',
            'Nach längeren Nächten warst du tagsüber meist weniger schläfrig (Zusammenhang ${de(r, 2)}, ${xs.length} Tage).'));
      } else if (r >= 0.3) {
        out.add(Insight('Schlaf und Tagesmüdigkeit',
            'Ungewöhnlich: Nach längeren Nächten warst du eher schläfriger (Zusammenhang ${de(r, 2)}, ${xs.length} Tage).$hint'));
      } else {
        out.add(Insight('Schlaf und Tagesmüdigkeit',
            'Zwischen Schlafdauer und Tagesmüdigkeit zeigt sich bisher kaum ein Zusammenhang (${xs.length} Tage).'));
      }
    }

    // Unterbrechungen
    final ints = <num>[], ys2 = <num>[];
    for (final n in nights) {
      final v = s.symptomFor(dkey(n.wakeDay), 'evening')?.values['sleepy'];
      if (v != null) {
        ints.add(n.interruptions);
        ys2.add(v);
      }
    }
    if (ints.length >= 10) {
      final r = spearman(ints, ys2);
      if (r >= 0.3) {
        out.add(Insight('Unruhige Nächte',
            'Nach Nächten mit mehr Unterbrechungen warst du tagsüber schläfriger (Zusammenhang ${de(r, 2)}).'));
      }
    }

    // Zyklusphasen
    final ph = phaseStats.where((p) => p.sleepiness != null && p.n >= 4).toList();
    if (ph.length >= 2) {
      ph.sort((a, b) => b.sleepiness!.compareTo(a.sleepiness!));
      final diff = ph.first.sleepiness! - ph.last.sleepiness!;
      if (diff >= 1.0) {
        out.add(Insight('Zyklus',
            'In der Phase „${ph.first.phase}“ lag deine Tagesschläfrigkeit im Schnitt ${de(diff)} Punkte höher als in „${ph.last.phase}“.$hint'));
      }
    }

    // Medikamente vorher/nachher
    for (final m in medChanges.take(3)) {
      if (m.sleepBefore != null && m.sleepAfter != null && m.nBefore >= 5 && m.nAfter >= 5) {
        out.add(Insight('Medikation: ${m.med}',
            'Seit der Änderung auf ${m.dose} am ${fmtDateShort(parseKey(m.date))}: Tagesschläfrigkeit im Schnitt ${de(m.sleepBefore!)} → ${de(m.sleepAfter!)}'
                '${m.cataBefore != null && m.cataAfter != null ? ', Kataplexien pro Tag ${de(m.cataBefore!)} → ${de(m.cataAfter!)}' : ''}.'));
      }
    }

    // Wochentage
    final byWd = <int, List<int>>{};
    for (final e in entries('evening')) {
      final v = e.values['sleepy'];
      if (v != null) (byWd[parseKey(e.date).weekday] ??= []).add(v);
    }
    final wdAvg = byWd.entries.where((e) => e.value.length >= 3).map((e) => (e.key, mean(e.value))).toList();
    if (wdAvg.length >= 4) {
      wdAvg.sort((a, b) => b.$2.compareTo(a.$2));
      if (wdAvg.first.$2 - wdAvg.last.$2 >= 1.5) {
        out.add(Insight('Wochentage',
            'Am ${kWeekdaysLong[wdAvg.first.$1 - 1]} warst du im Schnitt am schläfrigsten (${de(wdAvg.first.$2)}), am ${kWeekdaysLong[wdAvg.last.$1 - 1]} am wachsten (${de(wdAvg.last.$2)}).'));
      }
    }

    // Koffein / Stress
    for (final flag in ['Stress', 'Koffein', 'Alkohol']) {
      final withF = <int>[], without = <int>[];
      for (final e in entries('evening')) {
        final c = cataOn(parseKey(e.date));
        if (c == null) continue;
        (e.flags.contains(flag) ? withF : without).add(c);
      }
      if (withF.length >= 4 && without.length >= 4) {
        final d = mean(withF) - mean(without);
        if (d >= 0.8) {
          out.add(Insight('$flag und Kataplexien',
              'An Tagen mit „$flag“ hattest du im Schnitt ${de(d)} Kataplexien mehr.'));
        }
      }
    }

    // Wecker
    final a = avgSnoozes;
    if (a != null && morningAlarms.length >= 7 && a >= 2) {
      out.add(Insight('Aufwachen', 'Du snoozt im Schnitt ${de(a)}-mal. Das kann auf starke Schlaftrunkenheit hindeuten.$hint'));
    }
    return out;
  }
}
