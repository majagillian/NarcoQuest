import 'package:flutter/material.dart';

import '../data.dart';
import '../logic/stats.dart';
import '../models.dart';
import '../services/alarm_service.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';
import 'alarms_screen.dart';
import 'sleep_log_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(String tab) onGo;
  const HomeScreen({super.key, required this.onGo});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = today();
        final night = store.activeNight;
        final nap = store.activeNap;
        final last = store.nightEndingOn(t);
        final next = AlarmService.instance.nextAlarm();
        final morningDone = store.symptomFor(dkey(t), 'morning') != null;
        final eveningDone = store.symptomFor(dkey(t), 'evening') != null;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (store.profile.name.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Hallo ${store.profile.name}!',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            if (store.lastNightMissing && night == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Card(
                  color: C.soft,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18), side: const BorderSide(color: C.softBorder)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const Expanded(
                        child: Text('Dein Schlaf von letzter Nacht fehlt noch.',
                            style: TextStyle(color: C.navy, fontWeight: FontWeight.w500)),
                      ),
                      FilledButton(
                        onPressed: () => showManualNightDialog(context),
                        child: const Text('Nachtragen'),
                      ),
                    ]),
                  ),
                ),
              ),
            _SleepCard(night: night, last: last),
            if (nap != null) ...[
              const SizedBox(height: 14),
              _NapRunningCard(nap: nap),
            ],
            const SizedBox(height: 18),
            const Label('Schnell erfassen'),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.0,
              children: [
                _Tile(
                  title: 'Kataplexie',
                  sub: 'heute: ${store.quickCountOn('cataplexy', t)}',
                  onTap: () => _cataSheet(context),
                ),
                _Tile(
                  title: 'Schlafattacke',
                  sub: 'heute: ${store.quickCountOn('attack', t)}',
                  onTap: () {
                    store.addQuickEvent('attack');
                    toast(context, 'Schlafattacke um ${hm(DateTime.now())} erfasst.');
                  },
                ),
                _Tile(
                  title: nap == null ? 'Nap starten' : 'Nap läuft',
                  sub: nap == null ? 'mit Nap-Wecker' : 'seit ${hm(nap.start)}',
                  onTap: nap == null ? () => _napSheet(context) : null,
                ),
                _Tile(
                  title: 'Wecker',
                  sub: next == null ? 'keiner aktiv' : '${fmtWeekdayDate(next.$2)} ${hm(next.$2)}',
                  highlight: true,
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AlarmsScreen())),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Section(
              title: 'Heute',
              child: Column(children: [
                _CheckRow('Morgen-Check', morningDone, () => onGo('track')),
                _CheckRow('Abend-Check', eveningDone, () => onGo('track')),
                if (last != null)
                  KeyValueRow('Schlaf-Score letzte Nacht',
                      '${Stats.sleepScore(last.duration.inMinutes / 60, last.interruptions.length, store.symptomFor(dkey(t), 'morning')?.values['quality'], null)}'),
                KeyValueRow('Getrackte Tage (7 Tage)', '${store.trackedDaysLast7} / 7'),
                KeyValueRow('Wochen-Quest: 5 Abend-Checks', '${store.eveningChecksThisWeek().clamp(0, 5)} / 5'),
              ]),
            ),
            const SizedBox(height: 14),
            _MedsToday(),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('Schlaf- und Nap-Verlauf'),
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SleepLogScreen())),
            ),
          ],
        );
      },
    );
  }

  void _cataSheet(BuildContext context) {
    String? sev;
    String? trig;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Kataplexie erfassen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Muted('Uhrzeit: ${hm(DateTime.now())}'),
              const SizedBox(height: 14),
              const Label('Stärke'),
              const SizedBox(height: 8),
              ChipWrap(options: kCataSeverity, isSelected: (o) => sev == o, onTap: (o) => set(() => sev = o)),
              const SizedBox(height: 14),
              const Label('Auslöser'),
              const SizedBox(height: 8),
              ChipWrap(options: kCataTriggers, isSelected: (o) => trig == o, onTap: (o) => set(() => trig = o)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  store.addQuickEvent('cataplexy', severity: sev, trigger: trig);
                  Navigator.pop(c);
                  toast(context, 'Kataplexie erfasst.');
                },
                child: const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _napSheet(BuildContext context) {
    int minutes = 20;
    bool planned = true;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nap starten', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              const Label('Nap-Wecker'),
              const SizedBox(height: 8),
              ChipWrap(
                options: const ['10 Min.', '15 Min.', '20 Min.', '30 Min.', '45 Min.', '60 Min.'],
                isSelected: (o) => o == '$minutes Min.',
                onTap: (o) => set(() => minutes = int.parse(o.split(' ').first)),
              ),
              const SizedBox(height: 14),
              const Label('Art'),
              const SizedBox(height: 8),
              ChipWrap(
                options: const ['Geplant', 'Ungeplant / Attacke'],
                isSelected: (o) => (o == 'Geplant') == planned,
                onTap: (o) => set(() => planned = o == 'Geplant'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(c);
                  try {
                    await store.startNap(minutes, planned: planned);
                    if (context.mounted) toast(context, 'Nap gestartet – Wecker in $minutes Minuten.');
                  } catch (e) {
                    if (context.mounted) toast(context, 'Wecker konnte nicht gestellt werden: $e');
                  }
                },
                child: const Text('Nap starten'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(c);
                  showPastNapDialog(context);
                },
                child: const Text('Vergangenen Nap nachtragen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  final SleepSession? night;
  final SleepSession? last;
  const _SleepCard({required this.night, required this.last});

  @override
  Widget build(BuildContext context) {
    final sleeping = night != null;
    return Card(
      color: C.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Label('Schlaf-Tracker', color: C.softBorder),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(sleeping ? Icons.bedtime : Icons.wb_sunny_outlined, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    sleeping ? 'Schläft seit ${hm(night!.start)}' : 'Du bist wach',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    sleeping
                        ? 'Unterbrechungen: ${night!.interruptions.length}'
                        : last == null
                            ? 'Noch kein Schlaf für letzte Nacht erfasst'
                            : 'Letzte Nacht: ${fmtDuration(last!.duration)} · ${last!.interruptions.length} Unterbr.',
                    style: const TextStyle(color: C.softBorder, fontSize: 14),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            if (!sleeping)
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.navy, minimumSize: const Size(48, 56)),
                onPressed: () {
                  store.startSleep();
                  toast(context, 'Gute Nacht! Schlafbeginn ${hm(DateTime.now())} gespeichert.');
                },
                child: const Text('Schlafen gehen'),
              )
            else
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                      minimumSize: const Size(48, 52),
                    ),
                    onPressed: () {
                      store.addInterruption();
                      toast(context, 'Unterbrechung um ${hm(DateTime.now())} notiert.');
                    },
                    child: const Text('Kurz wach'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.navy, minimumSize: const Size(48, 52)),
                    onPressed: () async {
                      final s = store.endSleep();
                      if (s != null && context.mounted) {
                        toast(context, 'Guten Morgen! ${fmtDuration(s.duration)} geschlafen · +10 XP');
                      }
                    },
                    child: const Text('Aufstehen'),
                  ),
                ),
              ]),
            if (sleeping)
              TextButton(
                onPressed: () => _editStart(context),
                child: const Text('Einschlafzeit korrigieren', style: TextStyle(color: C.softBorder)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editStart(BuildContext context) async {
    final n = store.activeNight;
    if (n == null) return;
    final d = await pickDateTime(context, n.start);
    if (d != null) {
      n.start = d;
      store.changed();
    }
  }
}

class _NapRunningCard extends StatelessWidget {
  final SleepSession nap;
  const _NapRunningCard({required this.nap});

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Nap läuft',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Seit ${hm(nap.start)} · ${nap.planned ? 'geplant' : 'ungeplant'}'),
        const SizedBox(height: 10),
        FilledButton(onPressed: () => showNapEndSheet(context), child: const Text('Aufgewacht')),
      ]),
    );
  }
}

/// Abfrage nach einem Nap: erholt? geträumt?
void showNapEndSheet(BuildContext context) {
  int refreshed = 3;
  bool? dreamt;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Wie war der Nap?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            const Label('Erholt (1–5)'),
            const SizedBox(height: 8),
            ChipWrap(
              options: const ['1', '2', '3', '4', '5'],
              isSelected: (o) => o == '$refreshed',
              onTap: (o) => set(() => refreshed = int.parse(o)),
            ),
            const SizedBox(height: 14),
            const Label('Geträumt?'),
            const SizedBox(height: 8),
            ChipWrap(
              options: const ['Ja', 'Nein'],
              isSelected: (o) => dreamt != null && (o == 'Ja') == dreamt,
              onTap: (o) => set(() => dreamt = o == 'Ja'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                await store.endNap(refreshed: refreshed, dreamt: dreamt);
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Speichern · +5 XP'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final bool highlight;
  const _Tile({required this.title, required this.sub, this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? C.soft : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: highlight ? C.softBorder : C.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: highlight ? C.navy : C.ink)),
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: highlight ? C.navy : C.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String label;
  final bool done;
  final VoidCallback onTap;
  const _CheckRow(this.label, this.done, this.onTap);
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? C.blue : C.off),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Text(done ? 'erledigt' : 'offen', style: TextStyle(color: done ? C.blue : C.muted, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _MedsToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = dkey(today());
    final items = <(Medication, String)>[];
    for (final m in store.meds.where((m) => m.active)) {
      for (final time in m.times) {
        items.add((m, time));
      }
    }
    items.sort((a, b) => a.$2.compareTo(b.$2));
    if (items.isEmpty) {
      return const Section(
        title: 'Medikamente heute',
        child: Muted('Noch keine Medikamente angelegt. Unter „Mehr → Medikamente“ hinzufügen.'),
      );
    }
    return Section(
      title: 'Medikamente heute',
      child: Column(children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.$1.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Muted('${it.$2} Uhr'),
                ]),
              ),
              _TakenButton(med: it.$1, date: t, time: it.$2),
            ]),
          ),
      ]),
    );
  }
}

class _TakenButton extends StatelessWidget {
  final Medication med;
  final String date;
  final String time;
  const _TakenButton({required this.med, required this.date, required this.time});
  @override
  Widget build(BuildContext context) {
    final taken = store.isTaken(med.id, date, time);
    return taken
        ? FilledButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Genommen'),
            onPressed: () => store.toggleIntake(med.id, date, time),
          )
        : OutlinedButton(
            onPressed: () => store.toggleIntake(med.id, date, time),
            child: const Text('Genommen?'),
          );
  }
}
