import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data.dart';
import '../logic/stats.dart';
import '../store.dart';
import '../util.dart';

/// Erstellt den Arztbericht als PDF und öffnet das Teilen-Menü.
class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  /// Standardschrift im PDF kennt nur Latin-1 – Sonderzeichen ersetzen.
  String _t(String s) => s
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('→', '->')
      .replaceAll('…', '...')
      .replaceAll('„', '"')
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('’', "'")
      .replaceAll('−', '-')
      .replaceAll('×', 'x');

  Future<File> buildReport(int days) async {
    final st = Stats(store, days: days);
    final p = store.profile;
    final doc = pw.Document(title: 'NarcoQuest Bericht', author: p.name);
    final h1 = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E3A66));
    final h2 = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1E3A66));
    const small = pw.TextStyle(fontSize: 9, color: PdfColors.grey700);

    pw.Widget kv(String k, String v) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(_t(k))),
            pw.Text(_t(v), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ]),
        );

    String n1(double? v, [String unit = '']) => v == null ? '-' : '${de(v)}$unit';

    final nights = st.nights;
    final year = DateTime.now().year;
    final activeMeds = store.meds.where((m) => m.active).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Seite ${ctx.pageNumber} von ${ctx.pagesCount}', style: small),
        ),
        build: (ctx) => [
          pw.Text('NarcoQuest - Bericht für das Arztgespräch', style: h1),
          pw.SizedBox(height: 4),
          pw.Text(_t('Zeitraum: ${fmtDate(st.from)} – ${fmtDate(st.to)} ($days Tage) · erstellt am ${fmtDate(DateTime.now())}'),
              style: small),
          pw.SizedBox(height: 14),
          pw.Text('Profil', style: h2),
          kv('Name', p.name.isEmpty ? '-' : p.name),
          if (p.birthDate != null) kv('Geburtsdatum', fmtDate(parseKey(p.birthDate!))),
          kv('Diagnose', p.typeLabel),
          if (p.comorbidities.isNotEmpty) kv('Begleiterkrankungen', p.comorbidities.join(', ')),
          pw.SizedBox(height: 10),
          pw.Text('Aktuelle Medikation', style: h2),
          if (activeMeds.isEmpty) pw.Text('Keine Medikamente eingetragen.'),
          for (final m in activeMeds)
            kv(m.name, '${m.dose} ${m.unit} · ${m.times.join(', ')}${m.ingredient.isNotEmpty && m.ingredient != m.name ? ' (${m.ingredient})' : ''}'),
          kv('Einnahmetreue im Zeitraum', st.adherence == null ? '-' : '${(st.adherence! * 100).round()} %'),
          pw.SizedBox(height: 10),
          pw.Text('Schlaf', style: h2),
          kv('Erfasste Nächte', '${nights.length}'),
          kv('Ø Nachtschlaf', n1(st.avgSleepHours, ' h')),
          kv('Ø Unterbrechungen pro Nacht', n1(st.avgInterruptions)),
          kv('Streuung der Einschlafzeit', st.bedtimeSpread == null ? '-' : '${st.bedtimeSpread!.round()} min'),
          kv('Ø Schlaf-Score (0-100)', st.avgScore?.toString() ?? '-'),
          kv('Ø gefühlte Schlafqualität (0-10)', n1(st.avgValue('morning', 'quality'))),
          kv('Naps pro Tag', de(st.napsPerDay)),
          kv('Anteil ungeplanter Naps', st.unplannedNapShare == null ? '-' : '${(st.unplannedNapShare! * 100).round()} %'),
          pw.SizedBox(height: 10),
          pw.Text('Symptome', style: h2),
          kv('Ø Tagesschläfrigkeit (0-10)', n1(st.avgValue('evening', 'sleepy'))),
          kv('Ø Brainfog (0-10)', n1(st.avgValue('evening', 'fog'))),
          kv('Ø Kataplexien pro Tag', n1(st.cataPerDay)),
          kv('Schlafattacken (Schnellerfassung)', '${st.attacks}'),
          for (final e in st.flagCounts('morning').entries) kv('Nächte mit ${e.key}', '${e.value}'),
          for (final e in st.flagCounts('evening').entries) kv('Tage mit ${e.key}', '${e.value}'),
          for (final e in st.cataTriggers.entries) kv('Kataplexie-Auslöser ${e.key}', '${e.value}'),
          pw.SizedBox(height: 10),
          if (st.medChanges.isNotEmpty) ...[
            pw.Text('Medikamenten-Änderungen (je 14 Tage vorher/nachher)', style: h2),
            for (final m in st.medChanges.take(6))
              kv('${m.med} -> ${m.dose} am ${fmtDate(parseKey(m.date))}',
                  'Schläfrigkeit ${n1(m.sleepBefore)} -> ${n1(m.sleepAfter)} · Kataplexie ${n1(m.cataBefore)} -> ${n1(m.cataAfter)}'),
            pw.SizedBox(height: 10),
          ],
          if (store.cycle.enabled && st.phaseStats.any((x) => x.sleepiness != null)) ...[
            pw.Text('Zyklusphasen (Ø Tagesschläfrigkeit, letzte 120 Tage)', style: h2),
            for (final ph in st.phaseStats) kv(ph.phase, '${n1(ph.sleepiness)} (n=${ph.n})'),
            pw.SizedBox(height: 10),
          ],
          pw.Text('Wecker & Arbeit', style: h2),
          kv('Ø Snoozes pro Morgen', n1(st.avgSnoozes)),
          kv('Ø Lösezeit der Weckaufgabe', st.avgSolveSeconds == null ? '-' : '${st.avgSolveSeconds!.round()} s'),
          kv('Krankheitstage $year (davon Narkolepsie)', '${st.sickDaysYear(year)} (${st.sickDaysYear(year, narco: true)})'),
          kv('Termine wegen Symptomen abgesagt/verschoben', '${st.narcoCancellations}'),
          pw.SizedBox(height: 10),
          if (st.insights.isNotEmpty) ...[
            pw.Text('Auffälligkeiten', style: h2),
            for (final i in st.insights) pw.Bullet(text: _t('${i.title}: ${i.text}')),
            pw.SizedBox(height: 10),
          ],
          pw.Text('Nächte im Detail', style: h2),
          pw.TableHelper.fromTextArray(
            headers: ['Aufgewacht', 'Einschlafen', 'Dauer', 'Unterbr.', 'Qualität', 'Score'],
            data: [
              for (final n in nights.reversed.take(60))
                [
                  fmtDate(n.wakeDay),
                  hm(n.session.start),
                  fmtDuration(n.session.duration),
                  '${n.interruptions}',
                  n.quality?.toString() ?? '-',
                  '${n.score}',
                ],
            ],
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 14),
          pw.Text(_t(kDisclaimer), style: small),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/NarcoQuest_Bericht_${dkey(DateTime.now())}.pdf');
    await f.writeAsBytes(await doc.save(), flush: true);
    return f;
  }

  Future<void> shareReport(int days) async {
    final f = await buildReport(days);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: 'application/pdf')], subject: 'NarcoQuest-Bericht'));
  }
}
