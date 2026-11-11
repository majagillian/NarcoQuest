import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/alarm_service.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';
import 'tasks.dart';
import 'track_screen.dart';

/// Vollbild beim Klingeln: Snooze (begrenzt) oder Aufgabe lösen.
class RingScreen extends StatefulWidget {
  final AlarmSettings alarm;
  final bool practice;
  const RingScreen({super.key, required this.alarm, this.practice = false});
  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> {
  String phase = 'ring'; // ring, task, done
  late RingState rs;
  late String taskType;
  DateTime? taskStart;
  int errors = 0;
  int solveSeconds = 0;
  int? feeling;

  bool get isNap => !widget.practice && AlarmService.instance.isNapAlarm(widget.alarm);

  @override
  void initState() {
    super.initState();
    final existing = store.ringState;
    if (!widget.practice && existing != null && existing.alarmId == widget.alarm.id) {
      rs = existing;
    } else {
      rs = RingState(widget.alarm.id, DateTime.now(), 0);
      if (!widget.practice) {
        store.ringState = rs;
        // Nicht während des Aufbaus benachrichtigen.
        WidgetsBinding.instance.addPostFrameCallback((_) => store.changed());
      }
    }
    taskType = WakeTask.resolve(store.settings.task);
  }

  int get snoozesLeft => store.settings.maxSnooze - rs.snoozes;

  Future<void> _snooze() async {
    if (snoozesLeft <= 0) return;
    rs.snoozes++;
    if (!widget.practice) {
      store.ringState = rs;
      store.changed();
      await AlarmService.instance.snooze(widget.alarm, store.settings.snoozeMin);
    } else {
      setState(() {});
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _solved(int errs) async {
    errors = errs;
    solveSeconds = DateTime.now().difference(taskStart ?? DateTime.now()).inSeconds;
    if (!widget.practice) {
      await AlarmService.instance.dismiss(widget.alarm);
    }
    if (mounted) setState(() => phase = 'done');
  }

  Future<void> _finish() async {
    if (widget.practice) {
      Navigator.pop(context);
      return;
    }
    store.logAlarm(AlarmLog(
      alarmId: widget.alarm.id,
      isNap: isNap,
      firstRang: rs.firstRang,
      dismissedAt: DateTime.now(),
      snoozes: rs.snoozes,
      task: taskType,
      solveSeconds: solveSeconds,
      errors: errors,
      wakeFeeling: feeling,
    ));
    if (isNap) {
      await store.endNap(refreshed: feeling);
      if (mounted) Navigator.pop(context);
      return;
    }
    final s = store.endSleep();
    if (!mounted) return;
    if (s != null) toast(context, 'Schlaf gespeichert: ${fmtDuration(s.duration)}');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Morgen-Check')),
          body: const SafeArea(child: TrackScreen(initialPeriod: 'morning', popOnSave: true)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return PopScope(
      canPop: widget.practice || phase == 'done',
      child: Scaffold(
        backgroundColor: C.ink,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 24),
              if (phase == 'ring') ..._ring(now),
              if (phase == 'task')
                WakeTask(type: taskType, hard: store.settings.difficulty == 'mittel', onSolved: _solved),
              if (phase == 'done') ..._done(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _ring(DateTime now) {
    final label = widget.practice ? 'Übung' : AlarmService.instance.labelOf(widget.alarm);
    final name = store.profile.name;
    return [
      Text(isNap ? 'Nap vorbei' : (name.isEmpty ? 'Guten Morgen!' : 'Guten Morgen, $name!'),
          textAlign: TextAlign.center, style: const TextStyle(color: C.softBorder, fontSize: 16)),
      const SizedBox(height: 8),
      Text(hm(now),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w800, letterSpacing: -2)),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(color: C.softBorder, fontSize: 15)),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Text(
          snoozesLeft > 0
              ? (rs.snoozes == 0
                  ? 'Snooze ${store.settings.snoozeMin} Min. · noch $snoozesLeft×'
                  : 'Snooze ${rs.snoozes} von ${store.settings.maxSnooze} – noch $snoozesLeft×')
              : 'Keine Snoozes mehr – löse die Aufgabe.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
      const SizedBox(height: 20),
      if (snoozesLeft > 0)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
            minimumSize: const Size(48, 60),
          ),
          onPressed: _snooze,
          child: Text('Snooze (${store.settings.snoozeMin} Min.)'),
        ),
      const SizedBox(height: 12),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.navy, minimumSize: const Size(48, 60)),
        onPressed: () => setState(() {
          phase = 'task';
          taskStart = DateTime.now();
        }),
        child: const Text('Aufgabe lösen'),
      ),
    ];
  }

  List<Widget> _done() => [
        const Text('Du bist wach!',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text('Snoozes: ${rs.snoozes} · Fehler: $errors · $solveSeconds s',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17)),
        const SizedBox(height: 6),
        Text(
          widget.practice
              ? 'Übung beendet.'
              : (rs.snoozes == 0 && !isNap ? 'Ohne Snooze aufgestanden · +5 XP' : 'Diese Werte fließen in deine Statistik.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: C.softBorder, fontSize: 15),
        ),
        const SizedBox(height: 24),
        Text(isNap ? 'Wie erholt fühlst du dich?' : 'Wie wach fühlst du dich?',
            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 1; i <= 5; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChipX(label: '$i', selected: feeling == i, onTap: () => setState(() => feeling = i)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('1 = gar nicht · 5 = hellwach',
            textAlign: TextAlign.center, style: TextStyle(color: C.softBorder, fontSize: 13)),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.navy, minimumSize: const Size(48, 56)),
          onPressed: _finish,
          child: Text(widget.practice ? 'Schließen' : (isNap ? 'Fertig' : 'Zum Morgen-Check')),
        ),
      ];
}
