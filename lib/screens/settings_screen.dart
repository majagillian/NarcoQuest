import 'package:flutter/material.dart';

import '../services/alarm_service.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';
import 'tasks.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<String?> _pickTime(BuildContext context, String hhmm) async {
    final p = hhmm.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
    );
    return t == null ? null : '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = store.settings;
          final c = store.cycle;
          void upd({bool alarms = false, bool notes = false}) {
            store.changed(reschedule: notes);
            if (alarms) AlarmService.instance.syncAll();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Section(
                title: 'Wecker',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  InlineStepper(
                    label: 'Max. Snoozes',
                    hint: 'Danach muss die Aufgabe gelöst werden',
                    valueText: '${s.maxSnooze}',
                    onDec: s.maxSnooze > 0 ? () { s.maxSnooze--; upd(); } : null,
                    onInc: s.maxSnooze < 5 ? () { s.maxSnooze++; upd(); } : null,
                  ),
                  InlineStepper(
                    label: 'Snooze-Dauer',
                    valueText: '${s.snoozeMin} Min.',
                    onDec: s.snoozeMin > 1 ? () { s.snoozeMin--; upd(); } : null,
                    onInc: s.snoozeMin < 30 ? () { s.snoozeMin++; upd(); } : null,
                  ),
                  const SizedBox(height: 12),
                  const Label('Aufgabe zum Ausschalten'),
                  const SizedBox(height: 8),
                  ChipWrap(
                    options: kTaskTypes,
                    isSelected: (o) => s.task == o,
                    onTap: (o) { s.task = o; upd(); },
                  ),
                  const SizedBox(height: 12),
                  const Label('Schwierigkeit'),
                  const SizedBox(height: 8),
                  ChipWrap(
                    options: const ['leicht', 'mittel'],
                    isSelected: (o) => s.difficulty == o,
                    onTap: (o) { s.difficulty = o; upd(); },
                  ),
                  const SizedBox(height: 12),
                  for (final g in ['Laut', 'Melodisch', 'Natur']) ...[
                    Label('Weckton · $g'),
                    const SizedBox(height: 8),
                    ChipWrap(
                      options: kSounds.where((x) => x.group == g).map((x) => x.label).toList(),
                      isSelected: (o) => soundById(s.sound).label == o,
                      onTap: (o) {
                        s.sound = kSounds.firstWhere((x) => x.label == o).id;
                        upd(alarms: true);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lautstärke langsam steigern'),
                    value: s.fadeIn,
                    onChanged: (v) { s.fadeIn = v; upd(alarms: true); },
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Section(
                title: 'Erinnerungen',
                child: Column(children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fehlenden Schlaf nachtragen'),
                    subtitle: Text('Um ${s.missingReminderHour}:00 Uhr, wenn die letzte Nacht fehlt'),
                    value: s.missingReminder,
                    onChanged: (v) { s.missingReminder = v; upd(notes: true); },
                  ),
                  if (s.missingReminder)
                    InlineStepper(
                      label: 'Uhrzeit',
                      valueText: '${s.missingReminderHour}:00',
                      onDec: s.missingReminderHour > 6 ? () { s.missingReminderHour--; upd(notes: true); } : null,
                      onInc: s.missingReminderHour < 20 ? () { s.missingReminderHour++; upd(notes: true); } : null,
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Morgen-Check'),
                    subtitle: Text('täglich um ${s.morningTime} Uhr'),
                    value: s.morningReminder,
                    onChanged: (v) { s.morningReminder = v; upd(notes: true); },
                    secondary: IconButton(
                      tooltip: 'Uhrzeit ändern',
                      icon: const Icon(Icons.schedule),
                      onPressed: () async {
                        final t = await _pickTime(context, s.morningTime);
                        if (t != null) { s.morningTime = t; upd(notes: true); }
                      },
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Abend-Check'),
                    subtitle: Text('täglich um ${s.eveningTime} Uhr'),
                    value: s.eveningReminder,
                    onChanged: (v) { s.eveningReminder = v; upd(notes: true); },
                    secondary: IconButton(
                      tooltip: 'Uhrzeit ändern',
                      icon: const Icon(Icons.schedule),
                      onPressed: () async {
                        final t = await _pickTime(context, s.eveningTime);
                        if (t != null) { s.eveningTime = t; upd(notes: true); }
                      },
                    ),
                  ),
                  const Muted('Medikamenten-Erinnerungen stellst du pro Medikament ein.', size: 12),
                ]),
              ),
              const SizedBox(height: 14),
              Section(
                title: 'Zyklustracker',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Zyklustracker anzeigen'),
                    subtitle: const Text('Erscheint als eigener Menüpunkt'),
                    value: c.enabled,
                    onChanged: (v) { c.enabled = v; upd(notes: true); },
                  ),
                  if (c.enabled) ...[
                    const Label('Modus'),
                    const SizedBox(height: 8),
                    ChipWrap(
                      options: const ['Zyklus verfolgen', 'Verhütung', 'Kinderwunsch', 'Schwangerschaft', 'Wechseljahre'],
                      isSelected: (o) => c.mode == o,
                      onTap: (o) { c.mode = o; upd(); },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Erinnerung 2 Tage vor der Periode'),
                      value: c.reminder,
                      onChanged: (v) { c.reminder = v; upd(notes: true); },
                    ),
                    Row(children: [
                      Expanded(child: Muted('Startwerte: ${c.baseLen} Tage Zyklus · ${c.basePeriod} Tage Periode')),
                      TextButton(
                        onPressed: () {
                          c.setupDone = false;
                          upd();
                          Navigator.pop(context);
                          toast(context, 'Öffne „Zyklus“, um die Startwerte zu ändern.');
                        },
                        child: const Text('Ändern'),
                      ),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              Section(
                title: 'Daten',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Muted('Alle Daten liegen nur auf diesem Gerät, solange du keine Cloud einrichtest.'),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB42318)),
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        'Alle Daten löschen?',
                        'Profil, Einträge, Wecker und Einstellungen werden unwiderruflich von diesem Gerät gelöscht. '
                            'Sicherungen in deiner Cloud bleiben bestehen.',
                        ok: 'Endgültig löschen',
                      );
                      if (ok) {
                        await store.deleteAll();
                        if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
                      }
                    },
                    child: const Text('Alle Daten löschen'),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              const Center(child: Muted('Farben: neutrales Blau · Version 1.0', size: 12)),
              const SizedBox(height: 4, child: ColoredBox(color: C.bg)),
            ],
          );
        },
      ),
    );
  }
}
