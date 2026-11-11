/// Statische Inhalte: Medikamente, Begleiterkrankungen, Wörterbuch.

class MedPreset {
  final String ingredient;
  final String brand;
  final String use;
  final String unit;
  final String note;
  const MedPreset(this.ingredient, this.brand, this.use, this.unit, [this.note = '']);
}

/// Grundlage: S2k-Leitlinie „Behandlung der Narkolepsie bei Erwachsenen und Kindern“
/// (DGN, Dezember 2025). Vor Veröffentlichung mit aktuellen Fachinformationen abgleichen.
const List<MedPreset> kMedPresets = [
  MedPreset('Modafinil', 'Vigil, Generika', 'Tagesschläfrigkeit', 'mg',
      'Kann die Wirkung hormoneller Verhütung abschwächen.'),
  MedPreset('Pitolisant', 'Wakix', 'Tagesschläfrigkeit und Kataplexie', 'mg'),
  MedPreset('Natriumoxybat', 'Xyrem, Generika', 'Tagesschläfrigkeit und Kataplexie', 'g',
      'Betäubungsmittel. Meist zwei nächtliche Dosen. Kein Alkohol.'),
  MedPreset('Solriamfetol', 'Sunosi', 'Tagesschläfrigkeit', 'mg'),
  MedPreset('Venlafaxin', 'Generika', 'Kataplexie', 'mg', 'Nicht abrupt absetzen.'),
  MedPreset('Clomipramin', 'Anafranil, Generika', 'Kataplexie', 'mg', 'Nicht abrupt absetzen.'),
  MedPreset('Methylphenidat', 'Ritalin, Medikinet u. a.', 'Tagesschläfrigkeit', 'mg', 'Betäubungsmittel.'),
  MedPreset('Dexamfetamin', 'Attentin u. a.', 'Tagesschläfrigkeit', 'mg', 'Betäubungsmittel.'),
  MedPreset('Lisdexamfetamin', 'Elvanse', 'Tagesschläfrigkeit', 'mg', 'Betäubungsmittel.'),
];

const List<String> kComorbidities = [
  'Schlafapnoe',
  'Restless Legs',
  'REM-Schlaf-Verhaltensstörung',
  'Depression',
  'Angststörung',
  'ADHS',
  'Adipositas',
  'Migräne',
];

const List<String> kMorningFlags = [
  'Schlafparalyse',
  'Hypnagoge Halluzination',
  'Hypnopompe Halluzination',
  'Albträume',
  'Luzide Träume',
  'Sehr lebhafte Träume',
  'Sprechen/Bewegen im Schlaf',
  'Nachts gegessen',
];

const List<String> kEveningFlags = [
  'Schlafattacke',
  'Automatisches Verhalten',
  'Koffein',
  'Alkohol',
  'Stress',
  'Sport',
  'Medikament vergessen',
  'Nebenwirkungen',
];

const List<String> kCataTriggers = ['Lachen', 'Überraschung', 'Ärger', 'Freude', 'Stress', 'Unbekannt'];
const List<String> kCataSeverity = ['Gesicht/Kopf', 'Knie/Arme', 'Sturz'];

class GlossaryEntry {
  final String term;
  final String text;
  final String inApp;
  const GlossaryEntry(this.term, this.text, this.inApp);
}

const List<GlossaryEntry> kGlossary = [
  GlossaryEntry('Tagesschläfrigkeit',
      'Starke, oft unwiderstehliche Müdigkeit am Tag – trotz Nachtschlaf. Das Leitsymptom der Narkolepsie.',
      'Abend-Check: Skala 0–10.'),
  GlossaryEntry('Schlafattacke',
      'Plötzliches, kaum vermeidbares Einschlafen am Tag, auch in aktiven Situationen wie Gesprächen oder beim Essen.',
      'Startseite: „Schlafattacke“ antippen – Uhrzeit wird gespeichert.'),
  GlossaryEntry('Kataplexie',
      'Kurzer Verlust der Muskelspannung bei vollem Bewusstsein, meist ausgelöst durch Gefühle wie Lachen, Überraschung oder Ärger. Reicht vom Erschlaffen der Gesichtsmuskeln bis zum Sturz. Kennzeichen von Typ 1.',
      'Startseite: „Kataplexie“ antippen und Stärke sowie Auslöser wählen.'),
  GlossaryEntry('Schlafparalyse',
      'Beim Einschlafen oder Aufwachen kurz nicht bewegen oder sprechen können, obwohl man wach ist. Meist Sekunden bis wenige Minuten, oft beängstigend, aber harmlos.',
      'Morgen-Check: Häkchen „Schlafparalyse“.'),
  GlossaryEntry('Hypnagoge Halluzination',
      'Sehr lebhafte, traumähnliche Wahrnehmungen beim Einschlafen – Bilder, Geräusche oder das Gefühl, jemand sei im Raum.',
      'Morgen-Check.'),
  GlossaryEntry('Hypnopompe Halluzination', 'Dieselben lebhaften Wahrnehmungen, aber beim Aufwachen.', 'Morgen-Check.'),
  GlossaryEntry('Fragmentierter Nachtschlaf',
      'Häufiges Aufwachen in der Nacht. Bei Narkolepsie typisch, obwohl man tagsüber sehr müde ist.',
      'Während der Nacht „Kurz wach“ antippen.'),
  GlossaryEntry('Automatisches Verhalten',
      'Handlungen im Halbschlaf, an die man sich später nicht erinnert – z. B. sinnlose Notizen oder Gegenstände an falschen Orten.',
      'Abend-Check.'),
  GlossaryEntry('Luzider Traum', 'Ein Traum, in dem man weiß, dass man träumt.', 'Morgen-Check.'),
  GlossaryEntry('Brainfog', 'Gefühl von Benommenheit mit Konzentrations- und Gedächtnisproblemen.',
      'Abend-Check: Skala 0–10.'),
  GlossaryEntry('Schlaftrunkenheit',
      'Schweres, verwirrtes Wachwerden. Die Lösezeit der Weckaufgabe gibt einen groben Hinweis darauf.',
      'Wird automatisch über den Wecker erfasst.'),
  GlossaryEntry('Hypokretin (Orexin)',
      'Botenstoff im Gehirn, der Wachheit stabilisiert. Bei Typ 1 ist er stark vermindert.', ''),
  GlossaryEntry('Polysomnographie', 'Messung im Schlaflabor über Nacht (Hirnströme, Atmung, Bewegungen).', ''),
  GlossaryEntry('MSLT', 'Multipler Schlaflatenztest: mehrere Einschlafversuche über den Tag verteilt im Schlaflabor.', ''),
  GlossaryEntry('SOREMP', 'Sehr frühes Auftreten von REM-Schlaf nach dem Einschlafen – ein typischer Befund bei Narkolepsie.', ''),
  GlossaryEntry('Status kataplektikus',
      'Serie von Kataplexien hintereinander, z. B. nach abruptem Absetzen von Medikamenten. Ärztlich abklären.', ''),
  GlossaryEntry('Lutealphase',
      'Zweite Zyklushälfte nach dem Eisprung bis zur nächsten Periode. Hormonschwankungen können Müdigkeit beeinflussen.',
      'Zyklustracker.'),
];

const String kDisclaimer =
    'NarcoQuest ist ein persönliches Tagebuch und kein Medizinprodukt. Die App stellt keine Diagnosen '
    'und gibt keine Therapie- oder Dosierungsempfehlungen. Auswertungen zeigen nur Zusammenhänge in '
    'deinen eigenen Einträgen. Besprich Veränderungen deiner Behandlung immer mit deiner Ärztin oder deinem Arzt.';
