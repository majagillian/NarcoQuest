import 'package:flutter/material.dart';

import '../data.dart';
import '../store.dart';
import '../ui/common.dart';
import '../util.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final p = store.profile;
  late final name = TextEditingController(text: p.name);
  late final year = TextEditingController(text: p.diagnosisYear?.toString() ?? '');
  late final other = TextEditingController();
  late String gender = p.gender;
  late String type = p.narcoType;
  late Set<String> comorb = p.comorbidities.toSet();
  late String? birth = p.birthDate;

  @override
  void dispose() {
    name.dispose();
    year.dispose();
    other.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extra = comorb.where((c) => !kComorbidities.contains(c)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name oder Spitzname')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.cake_outlined),
            label: Text(birth == null ? 'Geburtsdatum (optional)' : 'Geboren am ${fmtDate(parseKey(birth!))}'),
            onPressed: () async {
              final d = await pickDateTime(context, birth == null ? DateTime(1995) : parseKey(birth!), dateOnly: true);
              if (d != null) setState(() => birth = dkey(d));
            },
          ),
          const SizedBox(height: 16),
          const Label('Geschlecht'),
          const SizedBox(height: 8),
          ChipWrap(
            options: const ['weiblich', 'männlich', 'divers', 'keine Angabe'],
            isSelected: (o) => gender == o,
            onTap: (o) => setState(() => gender = o),
          ),
          const SizedBox(height: 16),
          const Label('Narkolepsie'),
          const SizedBox(height: 8),
          ChipWrap(
            options: const ['Typ 1', 'Typ 2', 'Nicht diagnostiziert'],
            isSelected: (o) => {'Typ 1': 'typ1', 'Typ 2': 'typ2', 'Nicht diagnostiziert': 'undiagnosed'}[o] == type,
            onTap: (o) => setState(() => type = {'Typ 1': 'typ1', 'Typ 2': 'typ2', 'Nicht diagnostiziert': 'undiagnosed'}[o]!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: year,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Diagnosejahr (optional)'),
          ),
          const SizedBox(height: 16),
          const Label('Begleiterkrankungen'),
          const SizedBox(height: 8),
          ChipWrap(
            options: [...kComorbidities, ...extra],
            isSelected: comorb.contains,
            onTap: (o) => setState(() => comorb.contains(o) ? comorb.remove(o) : comorb.add(o)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: other, decoration: const InputDecoration(labelText: 'Weitere hinzufügen'))),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Hinzufügen',
              onPressed: () {
                final t = other.text.trim();
                if (t.isEmpty) return;
                setState(() {
                  comorb.add(t);
                  other.clear();
                });
              },
              icon: const Icon(Icons.add),
            ),
          ]),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              p
                ..name = name.text.trim()
                ..birthDate = birth
                ..gender = gender
                ..narcoType = type
                ..diagnosisYear = int.tryParse(year.text.trim())
                ..comorbidities = comorb.toList();
              store.changed();
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
