import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _consent = false;
  final _name = TextEditingController();
  DateTime? _birth;
  String _gender = 'keine Angabe';
  String _type = 'typ1';
  final Set<String> _comorb = {};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final p = store.profile;
    p.name = _name.text.trim();
    p.birthDate = _birth == null ? null : dkey(_birth!);
    p.gender = _gender;
    p.narcoType = _type;
    p.comorbidities = _comorb.toList();
    p.onboarded = true;
    store.addXp(20, 'Profil erstellt');
    store.changed(reschedule: true);
    try {
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            const Text('NarcoQuest', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: C.navy)),
            const SizedBox(height: 4),
            const Muted('Dein Tagebuch für Schlaf, Naps und Narkolepsie-Symptome.', size: 15),
            const SizedBox(height: 24),
            if (_step == 0) ..._welcome(),
            if (_step == 1) ..._profile(),
            if (_step == 2) ..._condition(),
          ],
        ),
      ),
    );
  }

  List<Widget> _welcome() => [
        const Section(
          title: 'Deine Daten gehören dir',
          child: Text(
            'Alle Einträge werden nur auf diesem Handy gespeichert. Eine Sicherung in deiner eigenen Cloud '
            'kannst du später selbst einrichten – verschlüsselt mit deinem Passwort.',
            style: TextStyle(fontSize: 15),
          ),
        ),
        const SizedBox(height: 12),
        const Section(title: 'Wichtiger Hinweis', child: Text(kDisclaimer, style: TextStyle(fontSize: 15))),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _consent,
          onChanged: (v) => setState(() => _consent = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('Ich habe den Hinweis gelesen und willige ein, dass die App meine Gesundheitsdaten '
              'auf diesem Gerät speichert und auswertet.'),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _consent ? () => setState(() => _step = 1) : null, child: const Text('Weiter')),
      ];

  List<Widget> _profile() => [
        const Text('Über dich', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name oder Spitzname')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.cake_outlined),
          label: Text(_birth == null ? 'Geburtsdatum (optional)' : fmtDate(_birth!)),
          onPressed: () async {
            final d = await pickDateTime(context, _birth ?? DateTime(1995), dateOnly: true);
            if (d != null) setState(() => _birth = d);
          },
        ),
        const SizedBox(height: 16),
        const Label('Geschlecht'),
        const SizedBox(height: 8),
        ChipWrap(
          options: const ['weiblich', 'männlich', 'divers', 'keine Angabe'],
          isSelected: (o) => _gender == o,
          onTap: (o) => setState(() => _gender = o),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 0), child: const Text('Zurück'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: () => setState(() => _step = 2), child: const Text('Weiter'))),
        ]),
      ];

  List<Widget> _condition() => [
        const Text('Deine Narkolepsie', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final t in const [
          ('typ1', 'Typ 1', 'mit Kataplexien'),
          ('typ2', 'Typ 2', 'ohne Kataplexien'),
          ('undiagnosed', 'Nicht diagnostiziert', 'Verdacht oder Diagnose läuft'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: RadioListTile<String>(
                value: t.$1,
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v ?? 'typ1'),
                title: Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(t.$3),
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Label('Begleiterkrankungen (optional)'),
        const SizedBox(height: 8),
        ChipWrap(
          options: kComorbidities,
          isSelected: _comorb.contains,
          onTap: (o) => setState(() => _comorb.contains(o) ? _comorb.remove(o) : _comorb.add(o)),
        ),
        const SizedBox(height: 8),
        const Muted('Medikamente und Wecker richtest du danach unter „Mehr“ ein.'),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _step = 1), child: const Text('Zurück'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: _finish, child: const Text('Los geht’s'))),
        ]),
      ];
}
