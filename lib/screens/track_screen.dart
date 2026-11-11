import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';
import 'glossary_screen.dart';

/// Morgen- und Abend-Fragebogen.
class TrackScreen extends StatefulWidget {
  final String? initialPeriod;
  final bool popOnSave;
  const TrackScreen({super.key, this.initialPeriod, this.popOnSave = false});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  late String period = widget.initialPeriod ?? (DateTime.now().hour >= 15 ? 'evening' : 'morning');
  DateTime day = today();
  Map<String, int> values = {};
  Set<String> flags = {};

  static const _defaults = {
    'quality': 5,
    'rested': 5,
    'feltInterruptions': 0,
    'sleepy': 5,
    'fog': 5,
    'cata': 0,
    'attacks': 0,
    'mood': 5,
    'stress': 5,
    'energy': 5,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final e = store.symptomFor(dkey(day), period);
    values = Map<String, int>.from(e?.values ?? {});
    flags = (e?.flags ?? <String>[]).toSet();
    if (period == 'evening' && e == null) {
      values['cata'] = store.quickCountOn('cataplexy', day);
      values['attacks'] = store.quickCountOn('attack', day);
    }
    if (period == 'morning' && e == null) {
      final n = store.nightEndingOn(day);
      if (n != null) values['feltInterruptions'] = n.interruptions.length;
    }
  }

  int v(String k) => values[k] ?? _defaults[k] ?? 0;

  void setV(String k, int x) => setState(() => values[k] = x);

  @override
  Widget build(BuildContext context) {
    final morning = period == 'morning';
    final existing = store.symptomFor(dkey(day), period) != null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'morning', label: Text('Morgens'), icon: Icon(Icons.wb_twilight)),
            ButtonSegment(value: 'evening', label: Text('Abends'), icon: Icon(Icons.nights_stay_outlined)),
          ],
          selected: {period},
          onSelectionChanged: (s) => setState(() {
            period = s.first;
            _load();
          }),
        ),
        const SizedBox(height: 12),
        Row(children: [
          IconButton(
            tooltip: 'Vorheriger Tag',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              day = addDays(day, -1);
              _load();
            }),
          ),
          Expanded(
            child: Text(day == today() ? 'Heute, ${fmtDateShort(day)}' : fmtWeekdayDate(day),
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          IconButton(
            tooltip: 'Nächster Tag',
            icon: const Icon(Icons.chevron_right),
            onPressed: day == today()
                ? null
                : () => setState(() {
                      day = addDays(day, 1);
                      _load();
                    }),
          ),
        ]),
        const SizedBox(height: 4),
        Text(morning ? 'Wie war deine Nacht?' : 'Wie war dein Tag?',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        if (existing) const Muted('Schon ausgefüllt – du kannst die Angaben ändern.'),
        const SizedBox(height: 12),
        if (morning) ...[
          ScaleStepper(label: 'Schlafqualität', value: v('quality'), onChanged: (x) => setV('quality', x), lo: 'sehr schlecht', hi: 'sehr gut'),
          const SizedBox(height: 10),
          ScaleStepper(label: 'Erholt beim Aufstehen', value: v('rested'), onChanged: (x) => setV('rested', x), lo: 'gar nicht', hi: 'völlig'),
          const SizedBox(height: 10),
          ScaleStepper(
              label: 'Gefühlte Unterbrechungen',
              value: v('feltInterruptions'),
              max: 20,
              showOfMax: false,
              onChanged: (x) => setV('feltInterruptions', x)),
        ] else ...[
          ScaleStepper(label: 'Tagesschläfrigkeit', value: v('sleepy'), onChanged: (x) => setV('sleepy', x), lo: 'hellwach', hi: 'extrem müde'),
          const SizedBox(height: 10),
          ScaleStepper(label: 'Brainfog / Konzentration', value: v('fog'), onChanged: (x) => setV('fog', x), lo: 'klar', hi: 'sehr benebelt'),
          const SizedBox(height: 10),
          if (store.profile.narcoType != 'typ2') ...[
            ScaleStepper(label: 'Kataplexien heute', value: v('cata'), max: 30, showOfMax: false, onChanged: (x) => setV('cata', x)),
            const SizedBox(height: 10),
          ],
          ScaleStepper(label: 'Ungewollte Einschlafattacken', value: v('attacks'), max: 20, showOfMax: false, onChanged: (x) => setV('attacks', x)),
          const SizedBox(height: 10),
          ScaleStepper(label: 'Stimmung', value: v('mood'), onChanged: (x) => setV('mood', x), lo: 'sehr schlecht', hi: 'sehr gut'),
          const SizedBox(height: 10),
          ScaleStepper(label: 'Stress', value: v('stress'), onChanged: (x) => setV('stress', x), lo: 'keiner', hi: 'sehr hoch'),
          const SizedBox(height: 10),
          ScaleStepper(label: 'Energie', value: v('energy'), onChanged: (x) => setV('energy', x), lo: 'leer', hi: 'voll'),
        ],
        const SizedBox(height: 16),
        Label(morning ? 'Was ist passiert?' : 'Was gab es heute?'),
        const SizedBox(height: 8),
        ChipWrap(
          options: morning ? kMorningFlags : kEveningFlags,
          isSelected: flags.contains,
          onTap: (o) => setState(() => flags.contains(o) ? flags.remove(o) : flags.add(o)),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.help_outline),
            label: const Text('Begriffe unklar? Wörterbuch öffnen'),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const GlossaryScreen())),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () {
            final vals = <String, int>{};
            final keys = morning
                ? ['quality', 'rested', 'feltInterruptions']
                : ['sleepy', 'fog', if (store.profile.narcoType != 'typ2') 'cata', 'attacks', 'mood', 'stress', 'energy'];
            for (final k in keys) {
              vals[k] = v(k);
            }
            store.saveSymptoms(SymptomEntry(date: dkey(day), period: period, values: vals, flags: flags.toList()));
            toast(context, existing ? 'Änderungen gespeichert.' : '${morning ? 'Morgen' : 'Abend'}-Check gespeichert · +10 XP');
            if (widget.popOnSave) {
              Navigator.pop(context);
            } else {
              setState(() {});
            }
          },
          child: Text(existing ? 'Änderungen speichern' : 'Speichern · +10 XP'),
        ),
        const SizedBox(height: 8),
        const Muted('Tipp: Kataplexien und Schlafattacken kannst du auf der Startseite direkt im Moment erfassen.'),
        const SizedBox(height: 4),
        const SizedBox(height: 4, child: ColoredBox(color: C.bg)),
      ],
    );
  }
}
