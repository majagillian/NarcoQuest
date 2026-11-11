import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';

const _typeLabels = {'doctor': 'Arzttermin', 'private': 'Privat', 'work': 'Arbeit'};

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int monthOffset = 0;
  DateTime selected = today();

  bool _isSick(DateTime d) {
    final k = dkey(d);
    return store.sickLeaves.any((s) => s.start.compareTo(k) <= 0 && s.end.compareTo(k) >= 0);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final year = DateTime.now().year;
        final sickYear = store.sickLeaves.fold<int>(0, (a, s) => a + store.sickDays(s, year: year));
        final sickNarco = store.sickLeaves.where((s) => s.narco).fold<int>(0, (a, s) => a + store.sickDays(s, year: year));
        final dayEvents = store.events.where((e) => dateOnly(e.start) == selected).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
        final upcoming = store.events.where((e) => !e.start.isBefore(today()) && e.status == 'planned').toList()
          ..sort((a, b) => a.start.compareTo(b.start));
        return Scaffold(
          backgroundColor: C.bg,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addMenu(context),
            icon: const Icon(Icons.add),
            label: const Text('Neu'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Card(
                color: C.navy,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SickLeaveScreen())),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Label('Krankheitstage $year', color: C.softBorder),
                          const SizedBox(height: 4),
                          Text('$sickYear Tage · davon $sickNarco wegen Narkolepsie',
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _month(),
              const SizedBox(height: 14),
              Text(fmtWeekdayDate(selected), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_isSick(selected))
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Muted('An diesem Tag krankgeschrieben.'),
                ),
              if (dayEvents.isEmpty) const Muted('Keine Termine an diesem Tag.'),
              for (final e in dayEvents) _EventCard(e: e),
              const SizedBox(height: 18),
              const Label('Nächste Termine'),
              const SizedBox(height: 8),
              if (upcoming.isEmpty) const Muted('Keine geplanten Termine.'),
              for (final e in upcoming.take(8)) _EventCard(e: e),
            ],
          ),
        );
      },
    );
  }

  Widget _month() {
    final t = today();
    final base = DateTime(t.year, t.month + monthOffset, 1);
    final lead = base.weekday - 1;
    final dim = DateTime(base.year, base.month + 1, 0).day;
    return Section(
      child: Column(children: [
        Row(children: [
          IconButton(tooltip: 'Vorheriger Monat', onPressed: () => setState(() => monthOffset--), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Text('${kMonths[base.month - 1]} ${base.year}',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          IconButton(tooltip: 'Nächster Monat', onPressed: () => setState(() => monthOffset++), icon: const Icon(Icons.chevron_right)),
        ]),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final w in kWeekdaysShort) Center(child: Muted(w, size: 12)),
            for (int i = 0; i < lead; i++) const SizedBox(),
            for (int d = 1; d <= dim; d++) _dayCell(DateTime(base.year, base.month, d), t),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(spacing: 12, children: const [
          _Dot(color: C.navy, label: 'Arzt'),
          _Dot(color: C.off, label: 'Privat/Arbeit'),
          _Dot(color: Color(0xFFE5484D), label: 'Krank'),
        ]),
      ]),
    );
  }

  Widget _dayCell(DateTime day, DateTime t) {
    final evs = store.events.where((e) => dateOnly(e.start) == day).toList();
    final sick = _isSick(day);
    final sel = day == selected;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => setState(() => selected = day),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: sel ? C.soft : null,
          border: sel ? Border.all(color: C.blue, width: 2) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${day.day}',
              style: TextStyle(fontWeight: day == t ? FontWeight.w800 : FontWeight.w500, fontSize: 14,
                  decoration: day == t ? TextDecoration.underline : null)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (evs.any((e) => e.type == 'doctor')) const _MiniDot(C.navy),
            if (evs.any((e) => e.type != 'doctor')) const _MiniDot(C.off),
            if (sick) const _MiniDot(Color(0xFFE5484D)),
          ]),
        ]),
      ),
    );
  }

  void _addMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.event),
            title: const Text('Termin'),
            onTap: () {
              Navigator.pop(c);
              showEventDialog(context, null, initialDay: selected);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sick_outlined),
            title: const Text('Krankmeldung'),
            onTap: () {
              Navigator.pop(c);
              showSickLeaveDialog(context, null, initialDay: selected);
            },
          ),
        ]),
      ),
    );
  }
}

class _MiniDot extends StatelessWidget {
  final Color color;
  const _MiniDot(this.color);
  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Muted(label, size: 12),
      ]);
}

class _EventCard extends StatelessWidget {
  final CalEvent e;
  const _EventCard({required this.e});

  String get statusLabel {
    switch (e.status) {
      case 'done':
        return 'erledigt';
      case 'cancelled':
        return 'abgesagt${e.narco == true ? ' · wegen Narkolepsie${e.reason != null ? ' (${e.reason})' : ''}' : e.narco == false ? ' · anderer Grund' : ''}';
      case 'moved':
        return 'verschoben${e.narco == true ? ' · wegen Narkolepsie${e.reason != null ? ' (${e.reason})' : ''}' : e.narco == false ? ' · anderer Grund' : ''}';
      default:
        return 'geplant';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Muted('${fmtWeekdayDate(e.start)} · ${hm(e.start)}')),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: e.type == 'doctor' ? C.navy : C.soft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(_typeLabels[e.type] ?? e.type,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: e.type == 'doctor' ? Colors.white : C.navy)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(e.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (e.note.isNotEmpty) Muted(e.note),
            Muted('Status: $statusLabel'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (e.status == 'planned') ...[
                OutlinedButton(onPressed: () => _done(context), child: const Text('Erledigt')),
                OutlinedButton(onPressed: () => _move(context), child: const Text('Verschieben')),
                OutlinedButton(onPressed: () => _cancel(context), child: const Text('Absagen')),
              ],
              TextButton(onPressed: () => showEventDialog(context, e), child: const Text('Bearbeiten')),
            ]),
          ]),
        ),
      ),
    );
  }

  void _done(BuildContext context) {
    e.status = 'done';
    store.saveEvent(e);
  }

  Future<void> _cancel(BuildContext context) async {
    final r = await askNarcoReason(context, 'abgesagt');
    if (r == null) return;
    e.status = 'cancelled';
    e.narco = r != 'Nein';
    e.reason = r == 'Nein' ? null : r;
    store.saveEvent(e);
  }

  Future<void> _move(BuildContext context) async {
    final d = await pickDateTime(context, e.start.add(const Duration(days: 7)));
    if (d == null || !context.mounted) return;
    final r = await askNarcoReason(context, 'verschoben');
    if (r == null) return;
    e.status = 'moved';
    e.narco = r != 'Nein';
    e.reason = r == 'Nein' ? null : r;
    store.saveEvent(e);
    store.saveEvent(CalEvent(id: newId(), title: e.title, type: e.type, start: d, note: 'Verschoben vom ${fmtDateShort(e.start)}'));
    if (context.mounted) toast(context, 'Neuer Termin am ${fmtWeekdayDate(d)} um ${hm(d)} angelegt.');
  }
}

/// Fragt, ob ein Termin wegen Narkolepsie-Symptomen abgesagt/verschoben wurde.
/// Rückgabe: Grund (z. B. "Kataplexie"), "Nein" oder null (abgebrochen).
Future<String?> askNarcoReason(BuildContext context, String verb) {
  const reasons = ['Müdigkeit / Schlafattacke', 'Kataplexie', 'Brainfog', 'Nebenwirkungen', 'Schlechte Nacht'];
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Wurde der Termin wegen Narkolepsie-Symptomen $verb?',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          for (final r in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
                onPressed: () => Navigator.pop(c, r),
                child: Text('Ja – $r'),
              ),
            ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
            onPressed: () => Navigator.pop(c, 'Nein'),
            child: const Text('Nein, anderer Grund'),
          ),
        ]),
      ),
    ),
  );
}

Future<void> showEventDialog(BuildContext context, CalEvent? existing, {DateTime? initialDay}) async {
  final title = TextEditingController(text: existing?.title ?? '');
  final note = TextEditingController(text: existing?.note ?? '');
  String type = existing?.type ?? 'doctor';
  final d0 = initialDay ?? today();
  DateTime start = existing?.start ?? DateTime(d0.year, d0.month, d0.day, 9, 0);
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(existing == null ? 'Neuer Termin' : 'Termin bearbeiten'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Titel')),
            const SizedBox(height: 10),
            ChipWrap(
              options: _typeLabels.values.toList(),
              isSelected: (o) => _typeLabels[type] == o,
              onTap: (o) => set(() => type = _typeLabels.entries.firstWhere((e) => e.value == o).key),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                final d = await pickDateTime(c, start);
                if (d != null) set(() => start = d);
              },
              child: Text('${fmtWeekdayDate(start)}, ${hm(start)}'),
            ),
            const SizedBox(height: 10),
            TextField(controller: note, decoration: const InputDecoration(labelText: 'Notiz (optional)')),
          ]),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                store.deleteEvent(existing);
                Navigator.pop(c);
              },
              child: const Text('Löschen'),
            ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              if (title.text.trim().isEmpty) return;
              final e = existing ?? CalEvent(id: newId(), title: '', type: type, start: start);
              e
                ..title = title.text.trim()
                ..type = type
                ..start = start
                ..note = note.text.trim();
              store.saveEvent(e);
              Navigator.pop(c);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showSickLeaveDialog(BuildContext context, SickLeave? existing, {DateTime? initialDay}) async {
  final d0 = initialDay ?? today();
  DateTime start = existing == null ? d0 : parseKey(existing.start);
  DateTime end = existing == null ? d0 : parseKey(existing.end);
  bool narco = existing?.narco ?? true;
  bool cert = existing?.certificate ?? true;
  final reason = TextEditingController(text: existing?.reason ?? '');
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(existing == null ? 'Krankmeldung' : 'Krankmeldung bearbeiten'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            OutlinedButton(
              onPressed: () async {
                final d = await pickDateTime(c, start, dateOnly: true);
                if (d != null) set(() {
                  start = d;
                  if (end.isBefore(start)) end = start;
                });
              },
              child: Text('Von: ${fmtWeekdayDate(start)}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final d = await pickDateTime(c, end, dateOnly: true);
                if (d != null) set(() => end = d.isBefore(start) ? start : d);
              },
              child: Text('Bis: ${fmtWeekdayDate(end)}'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: narco,
              onChanged: (v) => set(() => narco = v),
              title: const Text('Wegen Narkolepsie'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: cert,
              onChanged: (v) => set(() => cert = v),
              title: const Text('AU-Bescheinigung vorhanden'),
            ),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Grund (optional)')),
          ]),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () {
                store.deleteSickLeave(existing);
                Navigator.pop(c);
              },
              child: const Text('Löschen'),
            ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              store.saveSickLeave(SickLeave(
                id: existing?.id ?? newId(),
                start: dkey(start),
                end: dkey(end),
                narco: narco,
                certificate: cert,
                reason: reason.text.trim(),
              ));
              Navigator.pop(c);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
}

class SickLeaveScreen extends StatelessWidget {
  const SickLeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Krankmeldungen')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSickLeaveDialog(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Krankmeldung'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = [...store.sickLeaves]..sort((a, b) => b.start.compareTo(a.start));
          final years = <int>{for (final s in store.sickLeaves) parseKey(s.start).year, DateTime.now().year}.toList()
            ..sort((a, b) => b.compareTo(a));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Section(
                title: 'Übersicht',
                child: Column(children: [
                  for (final y in years)
                    Builder(builder: (_) {
                      final all = store.sickLeaves.fold<int>(0, (a, s) => a + store.sickDays(s, year: y));
                      final n = store.sickLeaves.where((s) => s.narco).fold<int>(0, (a, s) => a + store.sickDays(s, year: y));
                      final pct = all == 0 ? 0 : (n * 100 / all).round();
                      return KeyValueRow('$y', '$all Tage · $n Narkolepsie ($pct %)');
                    }),
                ]),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty) const Muted('Noch keine Krankmeldungen erfasst.'),
              for (final s in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text('${fmtDate(parseKey(s.start))} – ${fmtDate(parseKey(s.end))}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([
                        '${store.sickDays(s)} Tage',
                        s.narco ? 'wegen Narkolepsie' : 'anderer Grund',
                        s.certificate ? 'mit AU' : 'ohne AU',
                        if (s.reason.isNotEmpty) s.reason,
                      ].join(' · ')),
                      onTap: () => showSickLeaveDialog(context, s),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const Muted(
                'Die Übersicht hilft z. B. bei Gesprächen mit Arbeitgeber oder Betriebsarzt, '
                'bei einem Antrag auf Schwerbehinderung oder Nachteilsausgleich. '
                'Unter „Statistik“ kannst du alles als PDF-Bericht teilen.',
              ),
            ],
          );
        },
      ),
    );
  }
}
