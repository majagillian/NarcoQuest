import 'package:flutter/material.dart';

import '../data.dart';
import '../ui/common.dart';
import '../ui/theme.dart';

class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wörterbuch')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final g in kGlossary)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(g.term, style: const TextStyle(fontWeight: FontWeight.w600)),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    iconColor: C.blue,
                    children: [
                      Text(g.text, style: const TextStyle(fontSize: 15)),
                      if (g.inApp.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Muted('In der App: ${g.inApp}'),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Muted(kDisclaimer),
        ],
      ),
    );
  }
}
