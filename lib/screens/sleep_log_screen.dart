import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';

/// Dialog: Nacht manuell nachtragen.
Future<void> showManualNightDialog(BuildContext context, {DateTime? wakeDay}) async {
  final w = wakeDay ?? today();
  DateTime start = DateTime(w.year, w.month, w.day - 1, 23, 0);
  DateTime end = DateTime(w.year, w.month, w.day, 7, 0);
  int inter = 0;
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Nacht nachtragen'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton(
            onPressed: () async {
              final d = await pickDateTime(c, start);
              if (d != null) set(() => start = d);
            },
            child: Text('Eingeschlafen: ${fmtDateTime(start)}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final d = await pickDateTime(c, end);
              if (d != null) set(() => end = d);
            },
            child: Text('Aufgewacht: ${fmtDateTime(end)}'),
          ),
          const SizedBox(height: 8),
          InlineStepper(
            label: 'Unterbrechungen',
            valueText: '$inter',
            onDec: inter > 0 ? () => set(() => inter--) : null,
            onInc: () => set(() => inter++),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              if (!end.isAfter(start)) {
                toast(context, 'Das Aufwachen muss nach dem Einschlafen liegen.');
                return;
              }
              store.addManualNight(start, end, inter);
              Navigator.pop(c);
              toast(context, 'Nacht nachgetragen · +5 XP');
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog: vergangenen Nap nachtragen.
Future<void> showPastNapDialog(BuildContext context) async {
  final now = DateTime.now();
  DateTime start = now.subtract(const Duration(minutes: 40));
  DateTime end = now.subtract(const Duration(minutes: 20));
  bool planned = false;
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Nap nachtragen'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          OutlinedButton(
            onPressed: () async {
              final d = await pickDateTime(c, start);
              if (d != null) set(() => start = d);
            },
            child: Text('Beginn: ${fmtDateTime(start)}'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final d = await pickDateTime(c, end);
              if (d != null) set(() => end = d);
            },
            child: Text('Ende: ${fmtDateTime(end)}'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: planned,
            onChanged: (v) => set(() => planned = v),
            title: const Text('Geplanter Nap'),
            subtitle: const Text('Aus = ungeplant / Schlafattacke'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              if (!end.isAfter(start)) {
                toast(context, 'Das Ende muss nach dem Beginn liegen.');
                return;
              }
              store.addPastNap(start, end, planned: planned);
              Navigator.pop(c);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    ),
  );
}

class SleepLogScreen extends StatelessWidget {
  const SleepLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schlaf-Verlauf')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showManualNightDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nacht nachtragen'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = [...store.sleeps]..sort((a, b) => b.start.compareTo(a.start));
          if (list.isEmpty) {
            return const Center(child: Muted('Noch keine Einträge.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (c, i) => _SleepTile(s: list[i]),
          );
        },
      ),
    );
  }
}

class _SleepTile extends StatelessWidget {
  final SleepSession s;
  const _SleepTile({required this.s});

  @override
  Widget build(BuildContext context) {
    final title = s.isNight ? 'Nacht' : (s.planned ? 'Nap (geplant)' : 'Nap (ungeplant)');
    final sub = s.running
        ? 'läuft seit ${fmtDateTime(s.start)}'
        : '${fmtDateTime(s.start)} – ${hm(s.end!)} · ${fmtDuration(s.duration)}'
            '${s.isNight ? ' · ${s.interruptions.length} Unterbr.' : ''}'
            '${s.manual ? ' · nachgetragen' : ''}';
    return Card(
      child: ListTile(
        leading: Icon(s.isNight ? Icons.bedtime_outlined : Icons.airline_seat_flat_outlined, color: C.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub),
        trailing: IconButton(
          tooltip: 'Löschen',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            if (await confirm(context, 'Eintrag löschen?', 'Dieser Eintrag wird entfernt.', ok: 'Löschen')) {
              store.deleteSleep(s);
            }
          },
        ),
      ),
    );
  }
}
