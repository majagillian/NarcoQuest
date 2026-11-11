import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';

class MedsScreen extends StatelessWidget {
  const MedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medikamente')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Hinzufügen'),
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MedEditScreen())),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (store.meds.isEmpty) const Section(child: Muted('Noch keine Medikamente angelegt.')),
            for (final m in store.meds)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Icon(Icons.medication, color: m.active ? C.blue : C.off),
                    title: Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (m.ingredient.isNotEmpty && m.ingredient != m.name) m.ingredient,
                      m.times.isEmpty ? 'keine Einnahmezeit' : m.times.join(', '),
                      if (!m.active) 'abgesetzt',
                    ].join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MedEditScreen(med: m))),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Muted(
              'Dosisänderungen werden mit Datum gespeichert. Die Statistik vergleicht dann die 14 Tage '
              'vor und nach der Änderung.',
            ),
          ],
        ),
      ),
    );
  }
}

class MedEditScreen extends StatefulWidget {
  final Medication? med;
  const MedEditScreen({super.key, this.med});
  @override
  State<MedEditScreen> createState() => _MedEditScreenState();
}

class _MedEditScreenState extends State<MedEditScreen> {
  late final name = TextEditingController(text: widget.med?.name ?? '');
  late final ingredient = TextEditingController(text: widget.med?.ingredient ?? '');
  late final dose = TextEditingController(text: widget.med?.dose ?? '');
  late String unit = widget.med?.unit ?? 'mg';
  late List<String> times = [...?widget.med?.times];
  late bool active = widget.med?.active ?? true;
  late bool remind = widget.med?.remind ?? true;
  late DateTime start = widget.med == null || widget.med!.start.isEmpty ? today() : parseKey(widget.med!.start);
  String? presetNote;

  @override
  void dispose() {
    name.dispose();
    ingredient.dispose();
    dose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.med == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Medikament hinzufügen' : 'Medikament bearbeiten'),
        actions: [
          if (!isNew)
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(context, 'Medikament löschen?',
                    'Tipp: Statt zu löschen kannst du es als „abgesetzt“ markieren – dann bleibt der Verlauf erhalten.',
                    ok: 'Löschen')) {
                  store.deleteMed(widget.med!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isNew) ...[
            const Label('In Deutschland zur Behandlung eingesetzt'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in kMedPresets)
                ChoiceChipX(
                  label: p.ingredient,
                  selected: ingredient.text == p.ingredient,
                  onTap: () => setState(() {
                    ingredient.text = p.ingredient;
                    name.text = p.ingredient;
                    unit = p.unit;
                    presetNote = '${p.brand} · ${p.use}${p.note.isEmpty ? '' : '\n${p.note}'}';
                  }),
                ),
            ]),
            if (presetNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
                  child: Text(presetNote!, style: const TextStyle(color: C.navy, fontSize: 13)),
                ),
              ),
            const SizedBox(height: 6),
            const Muted('Quelle: S2k-Leitlinie Narkolepsie (DGN, 2025). Eigene Medikamente kannst du frei eintragen.', size: 12),
            const SizedBox(height: 16),
          ],
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (z. B. Handelsname)')),
          const SizedBox(height: 10),
          TextField(controller: ingredient, decoration: const InputDecoration(labelText: 'Wirkstoff')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: dose,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Dosis'),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: unit,
              items: const ['mg', 'g', 'ml', 'µg', 'Tablette', 'Kapsel']
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) => setState(() => unit = v ?? 'mg'),
            ),
          ]),
          const SizedBox(height: 16),
          const Label('Einnahmezeiten'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in times)
              InputChip(
                label: Text(t),
                onDeleted: () => setState(() => times.remove(t)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Zeit'),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
                if (t != null) {
                  setState(() {
                    times.add('${two(t.hour)}:${two(t.minute)}');
                    times.sort();
                  });
                }
              },
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final d = await pickDateTime(context, start, dateOnly: true);
              if (d != null) setState(() => start = d);
            },
            child: Text('Einnahme seit ${fmtDate(start)}'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Erinnerung zur Einnahme'),
            value: remind,
            onChanged: (v) => setState(() => remind = v),
          ),
          if (!isNew)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Wird aktuell eingenommen'),
              subtitle: const Text('Aus = abgesetzt (Verlauf bleibt erhalten)'),
              value: active,
              onChanged: (v) => setState(() => active = v),
            ),
          if (!isNew && widget.med!.history.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Label('Dosis-Verlauf'),
            for (final h in widget.med!.history.reversed) KeyValueRow(fmtDate(parseKey(h.date)), h.dose),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) {
                toast(context, 'Bitte einen Namen eingeben.');
                return;
              }
              final old = widget.med;
              final m = Medication(
                id: old?.id ?? newId(),
                name: name.text.trim(),
                ingredient: ingredient.text.trim(),
                dose: dose.text.trim().replaceAll(',', '.').replaceAll('.', ','),
                unit: unit,
                times: times,
                start: dkey(start),
                active: active,
                remind: remind,
                history: old == null ? [] : [...old.history],
              );
              store.saveMed(m);
              Navigator.pop(context);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
