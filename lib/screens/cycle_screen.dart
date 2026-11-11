import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/cycle.dart';
import '../logic/stats.dart';
import '../models.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});
  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  DateTime selected = today();
  int monthOffset = 0;

  // Einrichtung
  int setupAgo = 10;
  bool setupUnknown = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.cycle.setupDone) return _setup();
        final cm = store.cycleModel;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ringCard(cm),
            const SizedBox(height: 14),
            _calendar(cm),
            const SizedBox(height: 14),
            _dayLog(cm),
            const SizedBox(height: 14),
            _narcoCard(),
            const SizedBox(height: 14),
            Section(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: StatTileInline('Ø Zykluslänge', '${cm.avgLen} Tage')),
                  Expanded(child: StatTileInline('Ø Periodenlänge', '${cm.avgPeriod} Tage')),
                ]),
                const SizedBox(height: 10),
                Muted(cm.basisText),
                if (cm.lens.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Muted('Letzte Zykluslängen: ${cm.lens.reversed.take(6).join(', ')} Tage'),
                ],
              ]),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ Einrichtung

  Widget _setup() {
    final c = store.cycle;
    final hasData = store.cycleModel.hasData;
    final start = addDays(today(), -setupAgo);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Zyklus einrichten', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Muted(
          'Mit diesen Startwerten sagt die App deinen Zyklus voraus, bis genug eigene Daten erfasst sind. '
          'Danach rechnet sie mit deinen echten Werten.',
          size: 14,
        ),
        const SizedBox(height: 14),
        Section(
          child: InlineStepper(
            label: 'Durchschnittliche Zykluslänge',
            hint: 'Erster Tag der Periode bis Tag vor der nächsten. Meist 21–35 Tage.',
            valueText: '${c.baseLen} Tage',
            onDec: c.baseLen > 18 ? () => setState(() => c.baseLen--) : null,
            onInc: c.baseLen < 50 ? () => setState(() => c.baseLen++) : null,
          ),
        ),
        const SizedBox(height: 10),
        Section(
          child: InlineStepper(
            label: 'Durchschnittliche Periodenlänge',
            hint: 'Wie viele Tage du blutest. Meist 3–7 Tage.',
            valueText: '${c.basePeriod} Tage',
            onDec: c.basePeriod > 1 ? () => setState(() => c.basePeriod--) : null,
            onInc: c.basePeriod < 12 ? () => setState(() => c.basePeriod++) : null,
          ),
        ),
        if (!hasData) ...[
          const SizedBox(height: 10),
          Section(
            title: 'Wann hat deine letzte Periode begonnen?',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!setupUnknown)
                Row(children: [
                  RoundIconButton(
                    icon: Icons.chevron_left,
                    semantic: 'einen Tag früher',
                    onTap: setupAgo < 90 ? () => setState(() => setupAgo++) : null,
                  ),
                  Expanded(
                    child: Column(children: [
                      Text(setupAgo == 0 ? 'Heute' : fmtWeekdayDate(start),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Muted(setupAgo == 0 ? '' : 'vor $setupAgo ${setupAgo == 1 ? 'Tag' : 'Tagen'}'),
                    ]),
                  ),
                  RoundIconButton(
                    icon: Icons.chevron_right,
                    semantic: 'einen Tag später',
                    onTap: setupAgo > 0 ? () => setState(() => setupAgo--) : null,
                  ),
                ]),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ChoiceChipX(
                  label: 'Weiß ich nicht mehr',
                  selected: setupUnknown,
                  onTap: () => setState(() => setupUnknown = !setupUnknown),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () {
            if (!hasData && !setupUnknown) {
              store.logPeriod(start, c.basePeriod);
            }
            c.setupDone = true;
            store.changed(reschedule: true);
            toast(context, setupUnknown && !hasData
                ? 'Eingerichtet – trage deine nächste Periode ein.'
                : 'Eingerichtet – Vorhersage erstellt.');
          },
          child: const Text('Fertig – Vorhersage starten'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Ring

  Widget _ringCard(CycleModel cm) {
    final t = today();
    String phase = 'Noch keine Daten';
    String main = 'Periode eintragen';
    String chance = 'Trage den Beginn deiner nächsten Periode ein – dann starten die Vorhersagen.';
    double progress = 0;
    int? cd;
    if (cm.hasData) {
      cd = cm.cycleDayOf(t);
      final until = daysBetween(t, cm.nextStart!);
      final ph = cm.phaseOf(t);
      phase = cm.isFlow(t)
          ? 'Periode'
          : cm.ovulation.contains(dkey(t))
              ? 'Eisprung'
              : cm.fertile.contains(dkey(t))
                  ? 'Fruchtbares Fenster'
                  : ph == 'Follikel'
                      ? 'Follikelphase'
                      : 'Lutealphase';
      main = cm.isFlow(t)
          ? 'Periode Tag ${daysBetween(cm.lastStart!, t) + 1}'
          : until > 0
              ? 'Periode in $until ${until == 1 ? 'Tag' : 'Tagen'}'
              : until == 0
                  ? 'Periode heute erwartet'
                  : '${-until} ${until == -1 ? 'Tag' : 'Tage'} über';
      progress = (((cd ?? 1)) / cm.avgLen).clamp(0.0, 1.0).toDouble();
      chance = cm.fertile.contains(dkey(t))
          ? 'Hohe Wahrscheinlichkeit, schwanger zu werden'
          : 'Geringe Wahrscheinlichkeit, schwanger zu werden';
    }
    final selFlow = cm.isFlow(selected);
    return Section(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        SizedBox(
          width: 210,
          height: 210,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(210, 210), painter: _RingPainter(progress)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Muted(phase, size: 13),
                Text(main,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
                if (cd != null) Muted('Zyklustag $cd'),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
          child: Text(chance, textAlign: TextAlign.center, style: const TextStyle(color: C.navy, fontSize: 14)),
        ),
        if (store.cycle.mode == 'Verhütung')
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Muted('Hinweis: Die Vorhersage ist keine sichere Verhütungsmethode.', size: 12),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: selected.isAfter(t)
                ? null
                : () {
                    if (selFlow) {
                      _editPeriodDialog();
                    } else {
                      store.logPeriod(selected, store.cycleModel.avgPeriod);
                      toast(context, 'Periodenbeginn am ${fmtDateShort(selected)} eingetragen – Vorhersage aktualisiert.');
                    }
                  },
            child: Text(selFlow ? 'Periode bearbeiten' : (selected == t ? 'Periode beginnt heute' : 'Periode ab ${fmtDateShort(selected)}')),
          ),
        ),
      ]),
    );
  }

  void _editPeriodDialog() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Periode bearbeiten'),
        content: const Text(
            'Tippe im Kalender auf einzelne Tage und ändere dort die Blutungsstärke. '
            'Mit „Periode hier beenden“ werden alle folgenden Periodentage dieser Blutung entfernt.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Schließen')),
          FilledButton(
            onPressed: () {
              var d = addDays(selected, 1);
              while (store.cycleModel.isFlow(d)) {
                final l = store.cycleLogFor(d)..flow = 'keine';
                store.saveCycleLog(l);
                d = addDays(d, 1);
              }
              Navigator.pop(c);
            },
            child: const Text('Periode hier beenden'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Kalender

  Widget _calendar(CycleModel cm) {
    final t = today();
    final base = DateTime(t.year, t.month + monthOffset, 1);
    final lead = base.weekday - 1;
    final dim = DateTime(base.year, base.month + 1, 0).day;
    final cells = <Widget>[];
    for (int i = 0; i < lead; i++) {
      cells.add(const SizedBox());
    }
    for (int d = 1; d <= dim; d++) {
      final day = DateTime(base.year, base.month, d);
      final k = dkey(day);
      Color bg = Colors.transparent, fg = C.ink;
      Border? border;
      if (cm.isFlow(day)) {
        bg = C.navy;
        fg = Colors.white;
      } else if (cm.predicted.contains(k)) {
        bg = Colors.white;
        fg = C.navy;
        border = Border.all(color: C.navy, width: 2);
      } else if (cm.ovulation.contains(k)) {
        bg = C.fertile;
        border = Border.all(color: C.blue, width: 2);
      } else if (cm.fertile.contains(k)) {
        bg = C.fertile;
      }
      final isSel = day == selected;
      final hasLog = store.cycleLogs[k] != null && !(store.cycleLogs[k]!.isPeriod) && !store.cycleLogs[k]!.isEmpty;
      cells.add(Center(
        child: Semantics(
          button: true,
          label: '$d. ${kMonths[base.month - 1]}',
          child: GestureDetector(
            onTap: () => setState(() => selected = day),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: isSel ? Border.all(color: C.ink, width: 2.5) : border,
              ),
              alignment: Alignment.center,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$d',
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: day == t ? FontWeight.w800 : FontWeight.w500,
                      decoration: day == t ? TextDecoration.underline : null,
                    )),
                if (hasLog) Container(width: 4, height: 4, decoration: const BoxDecoration(color: C.blue, shape: BoxShape.circle)),
              ]),
            ),
          ),
        ),
      ));
    }
    return Section(
      child: Column(children: [
        Row(children: [
          IconButton(
            tooltip: 'Vorheriger Monat',
            onPressed: monthOffset > -24 ? () => setState(() => monthOffset--) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text('${kMonths[base.month - 1]} ${base.year}',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          IconButton(
            tooltip: 'Nächster Monat',
            onPressed: monthOffset < 6 ? () => setState(() => monthOffset++) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1,
          children: [
            for (final w in kWeekdaysShort) Center(child: Muted(w, size: 12)),
            ...cells,
          ],
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 12, runSpacing: 6, children: const [
          _Legend(color: C.navy, label: 'Periode'),
          _Legend(color: Colors.white, borderColor: C.navy, label: 'Vorhersage'),
          _Legend(color: C.fertile, label: 'Fruchtbar'),
          _Legend(color: C.fertile, borderColor: C.blue, label: 'Eisprung'),
        ]),
      ]),
    );
  }

  // ------------------------------------------------------------ Tageseintrag

  Widget _dayLog(CycleModel cm) {
    final t = today();
    final future = selected.isAfter(t);
    final log = store.cycleLogFor(selected);
    void save() => store.saveCycleLog(log);
    Widget single(String title, List<String> opts, String Function() get, void Function(String) setVal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Label(title),
            const SizedBox(height: 8),
            ChipWrap(options: opts, isSelected: (o) => get() == o, onTap: setVal),
            const SizedBox(height: 14),
          ],
        );
    Widget multi(String title, List<String> opts, List<String> list) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Label(title),
            const SizedBox(height: 8),
            ChipWrap(
              options: opts,
              isSelected: list.contains,
              onTap: (o) {
                list.contains(o) ? list.remove(o) : list.add(o);
                save();
              },
            ),
            const SizedBox(height: 14),
          ],
        );
    final cd = cm.cycleDayOf(selected);
    return Section(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(selected == t ? 'Heute, ${fmtDateShort(selected)}' : fmtWeekdayDate(selected),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          if (cd != null) Muted('Zyklustag $cd'),
        ]),
        const SizedBox(height: 12),
        if (future)
          const Muted('Für zukünftige Tage kannst du noch nichts eintragen.', size: 14)
        else ...[
          single('Blutung', const ['Schmierblutung', 'leicht', 'mittel', 'stark'], () => log.flow, (o) {
            log.flow = log.flow == o ? 'keine' : o;
            save();
          }),
          multi('Symptome', const ['Krämpfe', 'Kopfschmerzen', 'Brustspannen', 'Rückenschmerzen', 'Blähungen', 'Übelkeit', 'Akne', 'Müdigkeit', 'Heißhunger', 'Schlafprobleme'], log.sym),
          multi('Stimmung', const ['Ruhig', 'Glücklich', 'Energiegeladen', 'Gereizt', 'Traurig', 'Ängstlich', 'Stimmungsschwankungen', 'Hohe Libido', 'Niedrige Libido'], log.mood),
          single('Ausfluss', const ['keiner', 'klebrig', 'cremig', 'eiweißartig', 'wässrig'], () => log.dis, (o) {
            log.dis = log.dis == o ? '' : o;
            save();
          }),
          InlineStepper(
            label: 'Basaltemperatur',
            hint: 'optional',
            valueText: log.temp == null ? '–' : '${de(log.temp!, 2)} °C',
            onDec: () {
              log.temp = ((log.temp ?? 36.5) * 100 - 5).round() / 100;
              save();
            },
            onInc: () {
              log.temp = ((log.temp ?? 36.5) * 100 + 5).round() / 100;
              save();
            },
          ),
          if (log.temp != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  log.temp = null;
                  save();
                },
                child: const Text('Temperatur entfernen'),
              ),
            ),
          if (store.cycle.mode == 'Verhütung') ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pille genommen'),
              value: log.pill,
              onChanged: (v) {
                log.pill = v;
                save();
              },
            ),
            if (store.meds.any((m) => m.active && m.ingredient.toLowerCase().contains('modafinil')))
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
                child: const Text(
                  'Hinweis: Modafinil kann die Wirkung hormoneller Verhütung abschwächen. Sprich das mit deiner Ärztin ab.',
                  style: TextStyle(color: C.navy, fontSize: 13),
                ),
              ),
          ],
          if (store.cycle.mode == 'Schwangerschaft' || store.cycle.mode == 'Kinderwunsch')
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'Viele Narkolepsie-Medikamente sind in Schwangerschaft und Stillzeit nicht geeignet. '
                'Besprich deine Medikation frühzeitig ärztlich.',
                style: TextStyle(color: C.navy, fontSize: 13),
              ),
            ),
        ],
      ]),
    );
  }

  // ------------------------------------------------------------ Narkolepsie-Bezug

  Widget _narcoCard() {
    final ph = Stats(store, days: 120).phaseStats;
    final withData = ph.where((p) => p.sleepiness != null).toList();
    return Section(
      title: 'Zyklus & Narkolepsie',
      child: withData.isEmpty
          ? const Muted('Sobald du Abend-Checks und Zyklusdaten gesammelt hast, siehst du hier deine Tagesschläfrigkeit je Zyklusphase.')
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final p in ph)
                HBar(label: p.phase, value: p.sleepiness, valueText: p.sleepiness == null ? '–' : de(p.sleepiness!)),
              const SizedBox(height: 6),
              const Muted('Ø Tagesschläfrigkeit (0–10) je Phase, letzte 120 Tage.', size: 12),
            ]),
    );
  }
}

class StatTileInline extends StatelessWidget {
  final String label;
  final String value;
  const StatTileInline(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Muted(label),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      ]);
}

class _Legend extends StatelessWidget {
  final Color color;
  final Color? borderColor;
  final String label;
  const _Legend({required this.color, this.borderColor, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: borderColor == null ? null : Border.all(color: borderColor!, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Muted(label, size: 12),
      ]);
}

class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 10;
    final bg = Paint()
      ..color = C.soft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    final fg = Paint()
      ..color = C.blue
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 14;
    canvas.drawCircle(c, r, bg);
    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * progress, false, fg);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress;
}
