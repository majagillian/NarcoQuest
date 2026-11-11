import 'dart:math' as math;

/// Kleine Helfer für Datum, Zeit und deutsche Formatierung (ohne intl).
const List<String> kMonths = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni',
  'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember'
];
const List<String> kMonthsShort = [
  'Jan.', 'Feb.', 'März', 'Apr.', 'Mai', 'Juni',
  'Juli', 'Aug.', 'Sep.', 'Okt.', 'Nov.', 'Dez.'
];
const List<String> kWeekdaysShort = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
const List<String> kWeekdaysLong = [
  'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'
];

String two(int n) => n.toString().padLeft(2, '0');

/// Datums-Schlüssel 'YYYY-MM-DD' (lokale Zeit).
String dkey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Ganze Kalendertage von a nach b (sommerzeitsicher).
int daysBetween(DateTime a, DateTime b) =>
    (dateOnly(b).difference(dateOnly(a)).inHours / 24).round();

String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String fmtDate(DateTime d) => '${d.day}. ${kMonthsShort[d.month - 1]} ${d.year}';

String fmtDateShort(DateTime d) => '${d.day}. ${kMonthsShort[d.month - 1]}';

String fmtWeekdayDate(DateTime d) =>
    '${kWeekdaysShort[d.weekday - 1]}, ${d.day}. ${kMonthsShort[d.month - 1]}';

String fmtDateTime(DateTime d) => '${fmtDateShort(d)}, ${hm(d)}';

String fmtDuration(Duration d) {
  final h = d.inMinutes ~/ 60;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return '$h h ${two(m)} min';
}

/// Zahl mit deutschem Komma.
String de(num v, [int digits = 1]) => v.toStringAsFixed(digits).replaceAll('.', ',');

double mean(List<num> xs) =>
    xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b) / xs.length;

double stddev(List<num> xs) {
  if (xs.length < 2) return 0;
  final m = mean(xs);
  final v = xs.fold<double>(0, (a, b) => a + (b - m) * (b - m)) / (xs.length - 1);
  return math.sqrt(v);
}

List<double> _ranks(List<num> xs) {
  final idx = List<int>.generate(xs.length, (i) => i);
  idx.sort((a, b) => xs[a].compareTo(xs[b]));
  final r = List<double>.filled(xs.length, 0);
  int i = 0;
  while (i < idx.length) {
    int j = i;
    while (j + 1 < idx.length && xs[idx[j + 1]] == xs[idx[i]]) {
      j++;
    }
    final avg = (i + j) / 2.0 + 1;
    for (int k = i; k <= j; k++) {
      r[idx[k]] = avg;
    }
    i = j + 1;
  }
  return r;
}

/// Spearman-Rangkorrelation (robust für 0–10-Skalen).
double spearman(List<num> a, List<num> b) {
  if (a.length != b.length || a.length < 3) return 0;
  final ra = _ranks(a), rb = _ranks(b);
  final ma = mean(ra), mb = mean(rb);
  double num = 0, da = 0, db = 0;
  for (int i = 0; i < ra.length; i++) {
    num += (ra[i] - ma) * (rb[i] - mb);
    da += (ra[i] - ma) * (ra[i] - ma);
    db += (rb[i] - mb) * (rb[i] - mb);
  }
  if (da == 0 || db == 0) return 0;
  return num / math.sqrt(da * db);
}

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}${math.Random().nextInt(9999)}';
