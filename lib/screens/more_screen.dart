import 'package:flutter/material.dart';

import '../data.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import 'alarms_screen.dart';
import 'backup_screen.dart';
import 'glossary_screen.dart';
import 'meds_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'sleep_log_screen.dart';

class MoreScreen extends StatelessWidget {
  final VoidCallback onOpenCycle;
  const MoreScreen({super.key, required this.onOpenCycle});

  void _open(BuildContext context, Widget w) =>
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.profile;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _open(context, const ProfileScreen()),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: C.soft,
                      child: Text(p.name.isEmpty ? '?' : p.name.characters.first.toUpperCase(),
                          style: const TextStyle(color: C.navy, fontWeight: FontWeight.w800, fontSize: 20)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name.isEmpty ? 'Profil' : p.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                        Muted(p.typeLabel),
                        if (store.meds.any((m) => m.active))
                          Muted(store.meds.where((m) => m.active).map((m) => m.label).join(' · ')),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: C.muted),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _Group(children: [
              _Item(Icons.medication_outlined, 'Medikamente', () => _open(context, const MedsScreen())),
              _Item(Icons.alarm, 'Wecker', () => _open(context, const AlarmsScreen())),
              _Item(Icons.history, 'Schlaf-Verlauf', () => _open(context, const SleepLogScreen())),
              _Item(Icons.menu_book_outlined, 'Wörterbuch', () => _open(context, const GlossaryScreen())),
            ]),
            const SizedBox(height: 14),
            _Group(children: [
              SwitchListTile(
                secondary: const Icon(Icons.water_drop_outlined, color: C.blue),
                title: const Text('Zyklustracker'),
                subtitle: const Text('Erscheint als eigener Menüpunkt'),
                value: store.cycle.enabled,
                onChanged: (v) {
                  store.cycle.enabled = v;
                  store.changed(reschedule: true);
                  if (v) {
                    onOpenCycle();
                    toast(context, store.cycle.setupDone
                        ? 'Zyklustracker aktiviert.'
                        : 'Zyklustracker aktiviert – kurz einrichten.');
                  } else {
                    toast(context, 'Zyklustracker ausgeblendet. Deine Daten bleiben gespeichert.');
                  }
                },
              ),
              _Item(Icons.tune, 'Einstellungen', () => _open(context, const SettingsScreen())),
              _Item(Icons.cloud_outlined, 'Datenspeicherung & Backup', () => _open(context, const BackupScreen())),
            ]),
            const SizedBox(height: 14),
            Section(
              title: 'Erfolge',
              child: store.badges.isEmpty
                  ? const Muted('Noch keine Abzeichen – erfasse deine erste Nacht!')
                  : Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final b in store.badges)
                        Chip(
                          avatar: const Icon(Icons.emoji_events_outlined, size: 18, color: C.navy),
                          label: Text(b),
                          backgroundColor: C.soft,
                          side: BorderSide.none,
                        ),
                    ]),
            ),
            const SizedBox(height: 14),
            const Section(title: 'Hinweis', child: Muted(kDisclaimer)),
            const SizedBox(height: 8),
            const Center(child: Muted('NarcoQuest 1.0', size: 12)),
          ],
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ]),
      );
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Item(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: C.blue),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: C.muted),
        onTap: onTap,
      );
}
