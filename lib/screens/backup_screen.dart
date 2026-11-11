import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../store.dart';
import '../ui/common.dart';
import '../ui/theme.dart';
import '../util.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final s = store.settings;
  late final url = TextEditingController(text: s.webdavUrl);
  late final user = TextEditingController(text: s.webdavUser);
  late final pass = TextEditingController(text: s.webdavPass);
  bool busy = false;

  @override
  void dispose() {
    url.dispose();
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<String?> _askPassword({required bool confirmTwice, String title = 'Backup-Passwort'}) async {
    final a = TextEditingController();
    final b = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ohne dieses Passwort lässt sich die Sicherung nicht wiederherstellen. Bitte gut aufbewahren.',
              style: TextStyle(fontSize: 14)),
          const SizedBox(height: 10),
          TextField(controller: a, obscureText: true, decoration: const InputDecoration(labelText: 'Passwort')),
          if (confirmTwice) ...[
            const SizedBox(height: 8),
            TextField(controller: b, obscureText: true, decoration: const InputDecoration(labelText: 'Passwort wiederholen')),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              if (a.text.length < 6) {
                toast(context, 'Mindestens 6 Zeichen.');
                return;
              }
              if (confirmTwice && a.text != b.text) {
                toast(context, 'Die Passwörter stimmen nicht überein.');
                return;
              }
              Navigator.pop(c, a.text);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    a.dispose();
    b.dispose();
    return r;
  }

  Future<void> _run(Future<void> Function() f, String ok) async {
    setState(() => busy = true);
    try {
      await f();
      if (mounted) toast(context, ok);
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', '').replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _saveDav() {
    s
      ..webdavUrl = url.text.trim()
      ..webdavUser = user.text.trim()
      ..webdavPass = pass.text;
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datenspeicherung')),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            Section(
              title: 'Speicherort',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'local',
                  groupValue: s.storage,
                  onChanged: (v) => setState(() { s.storage = 'local'; store.changed(); }),
                  title: const Text('Nur auf diesem Gerät'),
                  subtitle: const Text('Standard. Keine Daten verlassen das Handy.'),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'webdav',
                  groupValue: s.storage,
                  onChanged: (v) => setState(() { s.storage = 'webdav'; store.changed(); }),
                  title: const Text('Zusätzlich in meiner Cloud (Nextcloud/WebDAV)'),
                  subtitle: const Text('Verschlüsselt mit deinem Passwort, bevor es das Handy verlässt.'),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  enabled: false,
                  leading: Icon(Icons.radio_button_unchecked),
                  title: Text('Google Drive (in Vorbereitung)'),
                  subtitle: Text('Bis dahin: Backup-Datei über „Teilen“ in Google Drive ablegen.'),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Section(
              title: 'Backup-Datei',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Muted('Speichere eine Sicherung an einem Ort deiner Wahl oder teile sie z. B. an Google Drive, '
                    'Dropbox oder per E-Mail an dich selbst.'),
                const SizedBox(height: 10),
                FilledButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Verschlüsselt speichern'),
                  onPressed: () async {
                    final pw = await _askPassword(confirmTwice: true);
                    if (pw == null) return;
                    await _run(() async {
                      final ok = await BackupService.instance.saveBackupFile(pw);
                      if (!ok) throw Exception('Speichern abgebrochen.');
                    }, 'Backup gespeichert.');
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Verschlüsselt teilen'),
                  onPressed: () async {
                    final pw = await _askPassword(confirmTwice: true);
                    if (pw == null) return;
                    await _run(() => BackupService.instance.shareBackup(pw), 'Teilen geöffnet.');
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.data_object),
                  label: const Text('Unverschlüsselt exportieren (JSON)'),
                  onPressed: () async {
                    final ok = await confirm(context, 'Unverschlüsselt exportieren?',
                        'Die Datei enthält deine Gesundheitsdaten im Klartext. Nur verwenden, wenn du weißt, wo sie landet.',
                        ok: 'Exportieren');
                    if (!ok) return;
                    await _run(() => BackupService.instance.shareBackup(null), 'Teilen geöffnet.');
                  },
                ),
                const Divider(height: 28),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restore),
                  label: const Text('Backup-Datei wiederherstellen'),
                  onPressed: () async {
                    final data = await BackupService.instance.pickBackupFile();
                    if (data == null || !mounted) return;
                    String? pw;
                    if (BackupService.instance.isEncrypted(data)) {
                      pw = await _askPassword(confirmTwice: false, title: 'Passwort der Sicherung');
                      if (pw == null) return;
                    }
                    if (!mounted) return;
                    final ok = await confirm(context, 'Wiederherstellen?',
                        'Alle aktuellen Daten auf diesem Gerät werden durch die Sicherung ersetzt.', ok: 'Ersetzen');
                    if (!ok) return;
                    await _run(() => BackupService.instance.restore(data, pw), 'Sicherung wiederhergestellt.');
                  },
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Section(
              title: 'Nextcloud / WebDAV',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Muted(
                  'Nextcloud: Adresse wie https://deine-cloud.de/remote.php/dav/files/BENUTZER/NarcoQuest/ '
                  '(Ordner vorher anlegen). Verwende ein App-Passwort aus den Nextcloud-Sicherheitseinstellungen.',
                ),
                const SizedBox(height: 10),
                TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'WebDAV-Ordner-Adresse')),
                const SizedBox(height: 8),
                TextField(controller: user, decoration: const InputDecoration(labelText: 'Benutzername')),
                const SizedBox(height: 8),
                TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'App-Passwort')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        _saveDav();
                        if (s.webdavUrl.isEmpty) {
                          toast(context, 'Bitte Adresse eingeben.');
                          return;
                        }
                        final pw = await _askPassword(confirmTwice: true);
                        if (pw == null) return;
                        await _run(() => BackupService.instance.uploadWebdav(pw), 'In die Cloud hochgeladen.');
                      },
                      child: const Text('Hochladen'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        _saveDav();
                        final pw = await _askPassword(confirmTwice: false, title: 'Passwort der Sicherung');
                        if (pw == null || !mounted) return;
                        final ok = await confirm(context, 'Aus der Cloud wiederherstellen?',
                            'Alle aktuellen Daten auf diesem Gerät werden ersetzt.', ok: 'Ersetzen');
                        if (!ok) return;
                        await _run(() => BackupService.instance.downloadWebdav(pw), 'Aus der Cloud wiederhergestellt.');
                      },
                      child: const Text('Herunterladen'),
                    ),
                  ),
                ]),
                if (s.lastSync != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Muted('Letzter Upload: ${fmtDateTime(DateTime.parse(s.lastSync!))}'),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'Verschlüsselung: AES-256-GCM, Schlüssel aus deinem Passwort (PBKDF2). '
                'Weder der Cloud-Anbieter noch die App-Entwickler können deine Daten lesen.',
                style: TextStyle(color: C.navy, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
