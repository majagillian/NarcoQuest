import 'package:flutter/material.dart';

import '../data.dart';
import '../logic/stats.dart';
import '../services/report_service.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int days = 30;
  bool busy = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final st = Stats(store, days: days);
        final nights = st.nights;
        final last14 = nights.length > 14 ? nights.sublist(nights.length - 14) : nights;
        final sleepy = st.sleepinessSeries(7);
        final insights = st.insights;
        final year = DateTime.now().year;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 Tage')),
                ButtonSegment(value: 30, label: Text('30 Tage')),
                ButtonSegment(value: 90, label: Text('90 Tage')),
              ],
              selected: {days},
              onSelectionChanged: (s) => setState(() => days = s.first),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: StatTile(st.avgScore?.toString() ?? '–', 'Ø Schlaf-Score')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(st.avgSleepHours == null ? '–' : '${de(st.avgSleepHours!)} h', 'Ø Nachtschlaf')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(de(st.napsPerDay), 'Naps pro Tag')),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: StatTile(st.avgInterruptions == null ? '–' : de(st.avgInterruptions!), 'Ø Unterbrechungen')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(st.cataPerDay == null ? '–' : de(st.cataPerDay!), 'Kataplexien/Tag')),
              const SizedBox(width: 10),
              Expanded(child: StatTile(st.adherence == null ? '–' : '${(st.adherence! * 100).round()} %', 'Medikamente')),
            ]),
            const SizedBox(height: 14),
            if (insights.isNotEmpty)
              Section(
                title: 'Auffälligkeiten',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final i in insights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.title, style: const TextStyle(fontWeight: FontWeight.w700, color: C.navy)),
                          const SizedBox(height: 2),
                          Text(i.text, style: const TextStyle(color: C.navy, fontSize: 14)),
                        ]),
                      ),
                    ),
                  const Muted('Hinweise beschreiben Zusammenhänge in deinen Einträgen – keine Diagnose.', size: 12),
                ]),
              )
            else
              const Section(
                title: 'Auffälligkeiten',
                child: Muted('Für Auswertungen braucht die App etwa 10–14 Tage mit Schlaf- und Abend-Einträgen.'),
              ),
            const SizedBox(height: 14),
            Section(
              title: 'Nachtschlaf (letzte ${14} Nächte, Stunden)',
              child: last14.isEmpty
                  ? const Muted('Noch keine Nächte erfasst.')
                  : BarChartX(
                      labels: [for (final n in last14) '${n.wakeDay.day}.'],
                      values: [for (final n in last14) n.hours],
                      max: 10,
                      fmt: (v) => de(v),
                    ),
            ),
            const SizedBox(height: 14),
            Section(
              title: 'Tagesschläfrigkeit (letzte 7 Tage)',
              child: BarChartX(
                labels: [for (final s in sleepy) kWeekdaysShort[s.$1.weekday - 1]],
                values: [for (final s in sleepy) s.$2?.toDouble()],
                max: 10,
              ),
            ),
            if (store.cycle.enabled) ...[
              const SizedBox(height: 14),
              Section(
                title: 'Nach Zyklusphase (Ø Tagesschläfrigkeit)',
                child: Column(children: [
                  for (final p in Stats(store, days: 120).phaseStats)
                    HBar(label: p.phase, value: p.sleepiness, valueText: p.sleepiness == null ? '–' : de(p.sleepiness!)),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            _symptomCard(st),
            const SizedBox(height: 14),
            if (st.medChanges.isNotEmpty) ...[
              Section(
                title: 'Medikation vorher / nachher (je 14 Tage)',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final m in st.medChanges.take(5)) ...[
                    Text('${m.med} → ${m.dose} (${fmtDateShort(parseKey(m.date))})',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    KeyValueRow('Tagesschläfrigkeit',
                        '${m.sleepBefore == null ? '–' : de(m.sleepBefore!)} → ${m.sleepAfter == null ? '–' : de(m.sleepAfter!)}'),
                    KeyValueRow('Kataplexien/Tag',
                        '${m.cataBefore == null ? '–' : de(m.cataBefore!)} → ${m.cataAfter == null ? '–' : de(m.cataAfter!)}'),
                    const SizedBox(height: 8),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
            ],
            Section(
              title: 'Wecker',
              child: Column(children: [
                KeyValueRow('Ø Snoozes pro Morgen', st.avgSnoozes == null ? '–' : de(st.avgSnoozes!)),
                KeyValueRow('Ø Lösezeit der Aufgabe', st.avgSolveSeconds == null ? '–' : '${st.avgSolveSeconds!.round()} s'),
                KeyValueRow('Ø Fehler bei der Aufgabe', st.avgTaskErrors == null ? '–' : de(st.avgTaskErrors!)),
              ]),
            ),
            const SizedBox(height: 14),
            Section(
              title: 'Arbeit',
              child: Column(children: [
                KeyValueRow('Krankheitstage $year', '${st.sickDaysYear(year)}'),
                KeyValueRow('davon wegen Narkolepsie', '${st.sickDaysYear(year, narco: true)}'),
                KeyValueRow('Termine wegen Symptomen abgesagt/verschoben', '${st.narcoCancellations}'),
              ]),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Arztbericht als PDF'),
              onPressed: busy ? null : _report,
            ),
            const SizedBox(height: 8),
            const Muted(kDisclaimer, size: 12),
          ],
        );
      },
    );
  }

  Widget _symptomCard(Stats st) {
    final m = st.flagCounts('morning');
    final e = st.flagCounts('evening');
    final trig = st.cataTriggers;
    final nMorning = st.entries('morning').length;
    final nEvening = st.entries('evening').length;
    return Section(
      title: 'Symptome',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KeyValueRow('Ø Tagesschläfrigkeit', st.avgValue('evening', 'sleepy') == null ? '–' : de(st.avgValue('evening', 'sleepy')!)),
        KeyValueRow('Ø Brainfog', st.avgValue('evening', 'fog') == null ? '–' : de(st.avgValue('evening', 'fog')!)),
        KeyValueRow('Ø Schlafqualität', st.avgValue('morning', 'quality') == null ? '–' : de(st.avgValue('morning', 'quality')!)),
        KeyValueRow('Schlafattacken (Schnellerfassung)', '${st.attacks}'),
        if (m.isNotEmpty) ...[
          const SizedBox(height: 8),
          Muted('Nächte mit … (von $nMorning Morgen-Checks)'),
          for (final k in m.keys) KeyValueRow(k, '${m[k]}×'),
        ],
        if (e.isNotEmpty) ...[
          const SizedBox(height: 8),
          Muted('Tage mit … (von $nEvening Abend-Checks)'),
          for (final k in e.keys) KeyValueRow(k, '${e[k]}×'),
        ],
        if (trig.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Muted('Kataplexie-Auslöser'),
          for (final k in trig.keys) KeyValueRow(k, '${trig[k]}×'),
        ],
      ]),
    );
  }

  Future<void> _report() async {
    final weeks = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Zeitraum für den Bericht'),
        children: [
          for (final w in [4, 8, 12])
            SimpleDialogOption(onPressed: () => Navigator.pop(c, w), child: Text('$w Wochen')),
        ],
      ),
    );
    if (weeks == null) return;
    setState(() => busy = true);
    try {
      await ReportService.instance.shareReport(weeks * 7);
      store.addXpOncePerDay(15, 'Arztbericht');
      store.changed();
    } catch (e) {
      if (mounted) toast(context, 'Bericht konnte nicht erstellt werden: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
