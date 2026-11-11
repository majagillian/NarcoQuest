# NarcoQuest

Android-App für Menschen mit Narkolepsie: Schlaf, Naps, Symptome und optional den Zyklus erfassen, ohne Fitness-Tracker. Alles fließt in eine Narkolepsie-Statistik mit Arztbericht als PDF.

> NarcoQuest ist ein persönliches Tagebuch und **kein Medizinprodukt**. Die App stellt keine Diagnosen und gibt keine Therapie- oder Dosierungsempfehlungen.

## App installieren (ohne Programmieren)

1. Rechts auf dieser Seite unter **Releases** die neueste Version öffnen.
2. `NarcoQuest.apk` auf dem Android-Handy herunterladen.
3. Datei öffnen und „Aus dieser Quelle installieren“ erlauben.
4. Beim ersten Start Benachrichtigungen und „Wecker & Erinnerungen“ erlauben.
5. Für zuverlässige Wecker: **Mehr → Wecker → Berechtigungen prüfen** und die Akku-Optimierung für NarcoQuest abschalten.

Jede Änderung am Code auf dem Branch `main` baut automatisch eine neue APK (siehe Reiter **Actions**).

## Funktionen

| Bereich | Inhalt |
| --- | --- |
| Profil | Name, Geburtsdatum, Geschlecht, Narkolepsie Typ 1 / Typ 2 / nicht diagnostiziert, Begleiterkrankungen |
| Medikamente | Auswahl der in Deutschland eingesetzten Wirkstoffe (S2k-Leitlinie DGN 2025) oder eigene; Dosis, Einnahmezeiten, Erinnerung, Dosis-Verlauf |
| Wecker | Ausschalten nur nach gelöster Aufgabe; einstellbare Snooze-Anzahl und -Dauer; 8 Aufgaben (Rechnen, Schiebepuzzle, Memory, Zahlenfolge, Farbwort, Reihenfolge, Muster, Abtippen) + Zufall; 8 Töne (laut, melodisch, Natur) |
| Schlaf | Start, Unterbrechungen und Aufwachen per Knopf; Nachtragen; Erinnerung, wenn eine Nacht fehlt |
| Naps | Nap-Wecker (10–60 Min.), geplant oder ungeplant, Erholung und Träume |
| Symptome | Morgen-Check (Schlafqualität, Schlafparalyse, Halluzinationen, Träume …), Abend-Check (Tagesschläfrigkeit, Kataplexien, Brainfog …), Schnellerfassung von Kataplexien und Schlafattacken |
| Zyklus | Optional, in den Einstellungen aktivierbar. Startwerte für Zyklus- und Periodenlänge, danach Vorhersage aus eigenen Daten. Kalender, Blutung, Symptome, Stimmung, Ausfluss, Basaltemperatur, Modi (Verhütung, Kinderwunsch, Schwangerschaft …) |
| Statistik | Schlaf-Score, Schlafdauer, Unterbrechungen, Naps, Symptome, Einnahmetreue, Medikation vorher/nachher, Zyklusphasen, Wecker, Krankheitstage; Arztbericht als PDF |
| Kalender | Arzt-, Privat- und Arbeitstermine; beim Absagen/Verschieben Abfrage, ob Narkolepsie der Grund war |
| Krankmeldungen | Zeitraum, AU, narkolepsiebedingt ja/nein, Jahresübersicht |
| Gamification | XP, Level, Abzeichen, Wochen-Quest. Punkte gibt es fürs Eintragen, nie für „gute“ Werte |
| Daten | Nur auf dem Gerät. Optional: verschlüsselte Backup-Datei (AES-256-GCM) oder Nextcloud/WebDAV |

## Selbst bauen

Voraussetzungen: [Flutter](https://docs.flutter.dev/get-started/install) (stable, ≥ 3.41) und Android Studio.

```bash
flutter pub get
flutter run            # auf angeschlossenem Handy
flutter build apk      # Installationsdatei unter build/app/outputs/flutter-apk/
```

## Aufbau

```
lib/
  main.dart                 Start, Navigation, Wecker-Vollbild
  store.dart                Datenspeicher (JSON im App-Verzeichnis)
  models.dart               Datenmodelle
  data.dart                 Medikamente, Wörterbuch, Listen
  logic/cycle.dart          Zyklus-Vorhersage
  logic/stats.dart          Narkolepsie-Statistik
  services/                 Wecker, Erinnerungen, Backup, PDF-Bericht
  screens/                  Bildschirme
  ui/                       Design (neutrale Blautöne) und Bausteine
assets/sounds/              Selbst erzeugte, lizenzfreie Wecktöne
```

## Noch offen

- Google Drive als Speicherort (bis dahin: verschlüsselte Backup-Datei über „Teilen“ in Drive ablegen)
- App-Sperre per PIN/Fingerabdruck
- Aufgabe „Schütteln“
- iOS-Version
