import '../models.dart';
import '../util.dart';

/// Berechnet Zyklus-Kennzahlen und Vorhersagen.
/// Startwerte (baseLen/basePeriod) gelten, bis echte Daten vorliegen:
/// Zykluslänge ab dem ersten vollständig erfassten Zyklus,
/// Periodenlänge ab der ersten abgeschlossenen Periode.
class CycleModel {
  final Map<String, CycleLog> logs;
  final int baseLen;
  final int basePeriod;

  late final List<DateTime> starts;
  late final List<int> lens;
  late final int avgLen;
  late final int avgPeriod;
  late final bool lenFromData;
  late final bool periodFromData;
  late final DateTime? lastStart;
  late final DateTime? nextStart;
  final Set<String> fertile = {};
  final Set<String> ovulation = {};
  final Set<String> predicted = {};
  late final List<DateTime> _allStarts;

  CycleModel(this.logs, this.baseLen, this.basePeriod) {
    final t = today();
    final flowDays = logs.values.where((l) => l.isPeriod).map((l) => parseKey(l.date)).toList()
      ..sort();
    starts = flowDays.where((d) => !isFlow(addDays(d, -1)) && !d.isAfter(t)).toList();
    final ls = <int>[];
    for (int i = 1; i < starts.length; i++) {
      final l = daysBetween(starts[i - 1], starts[i]);
      if (l >= 15 && l <= 60) ls.add(l);
    }
    lens = ls;
    lenFromData = ls.isNotEmpty;
    avgLen = ls.isNotEmpty ? mean(ls).round() : baseLen;
    final pls = <int>[];
    for (final s in starts) {
      int n = 0;
      while (isFlow(addDays(s, n))) {
        n++;
      }
      if (addDays(s, n).isBefore(t) || addDays(s, n) == t) pls.add(n);
    }
    periodFromData = pls.isNotEmpty;
    avgPeriod = pls.isNotEmpty ? mean(pls).round() : basePeriod;
    if (starts.isEmpty) {
      lastStart = null;
      nextStart = null;
      _allStarts = [];
      return;
    }
    lastStart = starts.last;
    nextStart = addDays(lastStart!, avgLen);
    _allStarts = [
      ...starts,
      nextStart!,
      addDays(nextStart!, avgLen),
      addDays(nextStart!, 2 * avgLen),
    ];
    for (int i = 1; i < _allStarts.length; i++) {
      final ov = addDays(_allStarts[i], -14);
      ovulation.add(dkey(ov));
      for (int d = -5; d <= 1; d++) {
        fertile.add(dkey(addDays(ov, d)));
      }
    }
    for (final s in [nextStart!, addDays(nextStart!, avgLen), addDays(nextStart!, 2 * avgLen)]) {
      for (int d = 0; d < avgPeriod; d++) {
        final day = addDays(s, d);
        if (day.isAfter(t)) predicted.add(dkey(day));
      }
    }
  }

  bool get hasData => starts.isNotEmpty;

  bool isFlow(DateTime d) => logs[dkey(d)]?.isPeriod ?? false;

  int? cycleDayOf(DateTime d) {
    if (_allStarts.isEmpty) return null;
    DateTime? s;
    for (final x in _allStarts) {
      if (!x.isAfter(d)) s = x;
    }
    if (s == null) return null;
    return daysBetween(s, d) + 1;
  }

  /// Phase eines Tages: Menstruation, Follikel, Eisprung, Luteal (oder null).
  String? phaseOf(DateTime d) {
    if (_allStarts.isEmpty) return null;
    if (isFlow(d)) return 'Menstruation';
    DateTime? s, next;
    for (int i = 0; i < _allStarts.length; i++) {
      if (!_allStarts[i].isAfter(d)) {
        s = _allStarts[i];
        next = i + 1 < _allStarts.length ? _allStarts[i + 1] : null;
      }
    }
    if (s == null || next == null) return null;
    final ov = addDays(next, -14);
    final diff = daysBetween(ov, d);
    if (diff.abs() <= 1) return 'Eisprung';
    if (d.isBefore(ov)) {
      final cd = daysBetween(s, d) + 1;
      return cd <= avgPeriod ? 'Menstruation' : 'Follikel';
    }
    return 'Luteal';
  }

  String get basisText => lenFromData
      ? 'Vorhersage basiert auf ${lens.length} ${lens.length == 1 ? 'erfasstem Zyklus' : 'erfassten Zyklen'}.'
      : 'Vorhersage basiert auf deinen Startwerten ($baseLen / $basePeriod Tage). '
          'Ab dem ersten vollständig erfassten Zyklus rechnet die App mit deinen Daten.';
}
