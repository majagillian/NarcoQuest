import 'package:flutter/material.dart';

import '../store.dart';
import 'theme.dart';

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
}

class Section extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Widget? trailing;
  const Section({super.key, this.title, required this.child, this.padding = const EdgeInsets.all(16), this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: Label(title!)),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class Label extends StatelessWidget {
  final String text;
  final Color color;
  const Label(this.text, {super.key, this.color = C.muted});
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.7, color: color),
      );
}

class Muted extends StatelessWidget {
  final String text;
  final double size;
  const Muted(this.text, {super.key, this.size = 13});
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(color: C.muted, fontSize: size));
}

/// Auswahl-Chip im App-Stil (für Einfach- und Mehrfachauswahl).
class ChoiceChipX extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ChoiceChipX({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? C.navy : Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? C.navy : C.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : C.ink,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChipWrap extends StatelessWidget {
  final List<String> options;
  final bool Function(String) isSelected;
  final void Function(String) onTap;
  const ChipWrap({super.key, required this.options, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options) ChoiceChipX(label: o, selected: isSelected(o), onTap: () => onTap(o)),
      ],
    );
  }
}

/// Skala 0–max mit Plus/Minus und Balken.
class ScaleStepper extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final String? lo;
  final String? hi;
  final bool showOfMax;
  final ValueChanged<int> onChanged;
  const ScaleStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 10,
    this.lo,
    this.hi,
    this.showOfMax = true,
  });

  @override
  Widget build(BuildContext context) {
    return Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              Text(showOfMax ? '$value / $max' : '$value',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: C.blue)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              RoundIconButton(
                icon: Icons.remove,
                semantic: 'weniger',
                onTap: value > 0 ? () => onChanged(value - 1) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0).toDouble(),
                    minHeight: 10,
                    backgroundColor: C.soft,
                    color: C.blue,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RoundIconButton(
                icon: Icons.add,
                semantic: 'mehr',
                onTap: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
          if (lo != null || hi != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Muted(lo ?? '', size: 12), Muted(hi ?? '', size: 12)],
              ),
            ),
        ],
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String semantic;
  final VoidCallback? onTap;
  const RoundIconButton({super.key, required this.icon, required this.semantic, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantic,
      button: true,
      child: Material(
        color: onTap == null ? C.bg : C.soft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: onTap == null ? C.off : C.navy),
          ),
        ),
      ),
    );
  }
}

/// Zahl mit Plus/Minus in einer Zeile (für Einstellungen).
class InlineStepper extends StatelessWidget {
  final String label;
  final String valueText;
  final VoidCallback? onDec;
  final VoidCallback? onInc;
  final String? hint;
  const InlineStepper({super.key, required this.label, required this.valueText, this.onDec, this.onInc, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                if (hint != null) Muted(hint!, size: 12),
              ],
            ),
          ),
          RoundIconButton(icon: Icons.remove, semantic: 'weniger', onTap: onDec),
          SizedBox(
            width: 76,
            child: Text(valueText,
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          RoundIconButton(icon: Icons.add, semantic: 'mehr', onTap: onInc),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String value;
  final String label;
  const StatTile(this.value, this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.blue)),
            ),
            const SizedBox(height: 2),
            Muted(label, size: 12),
          ],
        ),
      ),
    );
  }
}

class KeyValueRow extends StatelessWidget {
  final String k;
  final String v;
  const KeyValueRow(this.k, this.v, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(k, style: const TextStyle(color: C.muted, fontSize: 14))),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      );
}

/// Horizontaler Balken mit Beschriftung (z. B. Zyklusphasen).
class HBar extends StatelessWidget {
  final String label;
  final double? value;
  final double max;
  final String valueText;
  const HBar({super.key, required this.label, required this.value, this.max = 10, required this.valueText});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 108, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: value == null ? 0.0 : (value! / max).clamp(0.0, 1.0).toDouble(),
                minHeight: 10,
                backgroundColor: C.soft,
                color: C.blue,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(valueText,
                textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// Einfaches Säulendiagramm.
class BarChartX extends StatelessWidget {
  final List<String> labels;
  final List<double?> values;
  final double max;
  final double height;
  final String Function(double)? fmt;
  const BarChartX({super.key, required this.labels, required this.values, required this.max, this.height = 140, this.fmt});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < values.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (values[i] != null)
                          FittedBox(
                            child: Text(
                              fmt != null ? fmt!(values[i]!) : values[i]!.round().toString(),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: values[i] == null
                              ? 3
                              : ((values[i]! / (max == 0 ? 1 : max)).clamp(0.0, 1.0) * (height - 22)).toDouble() + 3,
                          decoration: BoxDecoration(
                            color: values[i] == null ? C.line : C.blue,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final l in labels)
              Expanded(
                child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: C.muted)),
              ),
          ],
        ),
      ],
    );
  }
}

class XpBadge extends StatelessWidget {
  const XpBadge({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(99)),
              child: Text('Level ${store.level} · ${store.xp} XP',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.navy)),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: store.xpInLevel / 100,
                  minHeight: 6,
                  backgroundColor: C.soft,
                  color: C.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String text, {String ok = 'OK'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r ?? false;
}

Future<DateTime?> pickDateTime(BuildContext context, DateTime initial, {bool dateOnly = false}) async {
  final d = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2015),
    lastDate: DateTime(2100),
  );
  if (d == null) return null;
  if (dateOnly) return d;
  if (!context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}
