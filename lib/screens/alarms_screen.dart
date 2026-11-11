import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models.dart';
import '../services/alarm_service.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';
import 'ring_screen.dart';

class AlarmsScreen extends StatelessWidget {
  const AlarmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wecker')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_alarm),
        label: const Text('Neuer Wecker'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => AlarmEditScreen(alarm: store.newAlarm(), isNew: true)),
        ),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = [...store.alarms]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (list.isEmpty) const Section(child: Muted('Noch kein Wecker. Tippe auf „Neuer Wecker“.')),
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      title: Text(a.timeLabel, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      subtitle: Text([
                        if (a.label.isNotEmpty) a.label,
                        a.isNap ? 'Nap-Wecker' : null,
                        a.weekdays.isEmpty
                            ? 'einmalig'
                            : a.weekdays.length == 7
                                ? 'täglich'
                                : (a.weekdays.toList()..sort()).map((d) => kWeekdaysShort[d - 1]).join(', '),
                      ].whereType<String>().join(' · ')),
                      trailing: Switch(
                        value: a.enabled,
                        onChanged: (v) {
                          a.enabled = v;
                          store.saveAlarm(a);
                        },
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => AlarmEditScreen(alarm: a)),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Section(
                title: 'Zuverlässigkeit',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text(
                    'Damit der Wecker sicher klingelt, nimm NarcoQuest von der Akku-Optimierung aus. '
                    'Bei Samsung, Xiaomi, Huawei und Oppo ist das besonders wichtig.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      await Permission.ignoreBatteryOptimizations.request();
                      await Permission.notification.request();
                      await Permission.scheduleExactAlarm.request();
                    },
                    child: const Text('Berechtigungen prüfen'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      final id = await AlarmService.instance.scheduleNap(1);
                      if (context.mounted) toast(context, 'Test-Wecker klingelt in 1 Minute (ID $id).');
                    },
                    child: const Text('Test: Wecker in 1 Minute'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => RingScreen(
                          alarm: AlarmSettings(
                            id: 9999,
                            dateTime: DateTime.now(),
                            volumeSettings: VolumeSettings.fixed(volume: 0),
                            notificationSettings: NotificationSettings(title: 'Probe', body: 'Probe'),
                          ),
                          practice: true,
                        ),
                      ),
                    ),
                    child: const Text('Weckaufgabe üben (ohne Ton)'),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AlarmEditScreen extends StatefulWidget {
  final AlarmConfig alarm;
  final bool isNew;
  const AlarmEditScreen({super.key, required this.alarm, this.isNew = false});
  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late int hour = widget.alarm.hour;
  late int minute = widget.alarm.minute;
  late Set<int> days = widget.alarm.weekdays.toSet();
  late bool isNap = widget.alarm.isNap;
  late final TextEditingController label = TextEditingController(text: widget.alarm.label);

  @override
  void dispose() {
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Neuer Wecker' : 'Wecker bearbeiten'),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await store.deleteAlarm(widget.alarm);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: TextButton(
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: hour, minute: minute));
                if (t != null) {
                  setState(() {
                    hour = t.hour;
                    minute = t.minute;
                  });
                }
              },
              child: Text('${two(hour)}:${two(minute)}',
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800, color: C.ink)),
            ),
          ),
          const SizedBox(height: 8),
          const Label('Wiederholen'),
          const SizedBox(height: 8),
          ChipWrap(
            options: kWeekdaysShort,
            isSelected: (o) => days.contains(kWeekdaysShort.indexOf(o) + 1),
            onTap: (o) => setState(() {
              final d = kWeekdaysShort.indexOf(o) + 1;
              days.contains(d) ? days.remove(d) : days.add(d);
            }),
          ),
          const SizedBox(height: 4),
          const Muted('Kein Tag gewählt = einmaliger Wecker.'),
          const SizedBox(height: 16),
          TextField(controller: label, decoration: const InputDecoration(labelText: 'Bezeichnung (optional)')),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isNap,
            onChanged: (v) => setState(() => isNap = v),
            title: const Text('Geplanter Nap-Wecker'),
            subtitle: const Text('Zählt in der Statistik als Nap-Wecker'),
          ),
          const SizedBox(height: 8),
          const Muted('Snooze, Aufgabe und Ton stellst du unter „Mehr → Einstellungen“ ein.'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              final a = widget.alarm
                ..hour = hour
                ..minute = minute
                ..weekdays = days.toList()
                ..label = label.text.trim()
                ..isNap = isNap
                ..enabled = true;
              await store.saveAlarm(a);
              if (!context.mounted) return;
              final next = AlarmService.instance.nextOccurrence(a);
              toast(context, 'Wecker gestellt: ${fmtWeekdayDate(next)} um ${hm(next)}');
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
