import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../store.dart';
import '../util.dart';

/// Sicherungen: verschlüsselte Backup-Datei und Nextcloud/WebDAV.
/// Verschlüsselung: AES-256-GCM, Schlüssel per PBKDF2-SHA256 aus dem Passwort.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _magic = 'NQENC1';
  final _aes = AesGcm.with256bits();

  Future<SecretKey> _key(String password, List<int> salt) {
    final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 60000, bits: 256);
    return kdf.deriveKeyFromPassword(password: password, nonce: salt);
  }

  Future<Uint8List> encrypt(String plain, String password) async {
    final rnd = Random.secure();
    final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
    final key = await _key(password, salt);
    final box = await _aes.encrypt(utf8.encode(plain), secretKey: key, nonce: _aes.newNonce());
    final out = BytesBuilder();
    out.add(utf8.encode(_magic));
    out.add(salt);
    out.add(box.concatenation());
    return out.toBytes();
  }

  Future<String> decrypt(Uint8List data, String password) async {
    final salt = data.sublist(_magic.length, _magic.length + 16);
    final rest = data.sublist(_magic.length + 16);
    final key = await _key(password, salt);
    final box = SecretBox.fromConcatenation(rest, nonceLength: 12, macLength: 16);
    final clear = await _aes.decrypt(box, secretKey: key);
    return utf8.decode(clear);
  }

  bool isEncrypted(Uint8List data) =>
      data.length > _magic.length && utf8.decode(data.sublist(0, _magic.length), allowMalformed: true) == _magic;

  Future<Uint8List> buildBackup(String? password) async {
    final json = jsonEncode(store.toJson(includeSecrets: false));
    if (password == null || password.isEmpty) return Uint8List.fromList(utf8.encode(json));
    return encrypt(json, password);
  }

  String backupFileName(bool encrypted) {
    final n = DateTime.now();
    return 'narcoquest_backup_${dkey(n)}_${two(n.hour)}${two(n.minute)}.${encrypted ? 'nqbak' : 'json'}';
  }

  /// Backup-Datei an selbst gewähltem Ort speichern.
  Future<bool> saveBackupFile(String? password) async {
    final bytes = await buildBackup(password);
    final uri = await FilePicker.saveFile(
      fileName: backupFileName(password != null && password.isNotEmpty),
      bytes: bytes,
      dialogTitle: 'Backup speichern',
    );
    return uri != null;
  }

  /// Backup über das Teilen-Menü versenden (z. B. an eigene Cloud-App).
  Future<void> shareBackup(String? password) async {
    final bytes = await buildBackup(password);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${backupFileName(password != null && password.isNotEmpty)}');
    await f.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: 'NarcoQuest-Backup'));
  }

  /// Datei auswählen und Rohdaten zurückgeben (null = abgebrochen).
  Future<Uint8List?> pickBackupFile() async {
    final f = await FilePicker.pickFile(dialogTitle: 'Backup auswählen');
    if (f == null) return null;
    return f.readAsBytes();
  }

  /// Rohdaten (ggf. verschlüsselt) einspielen.
  Future<void> restore(Uint8List data, String? password) async {
    String text;
    if (isEncrypted(data)) {
      if (password == null || password.isEmpty) {
        throw const FormatException('Diese Sicherung ist verschlüsselt. Bitte Passwort eingeben.');
      }
      try {
        text = await decrypt(data, password);
      } catch (_) {
        throw const FormatException('Falsches Passwort oder beschädigte Datei.');
      }
    } else {
      text = utf8.decode(data);
    }
    final j = jsonDecode(text) as Map<String, dynamic>;
    await store.importJson(j);
  }

  // ---------------------------------------------------------------- WebDAV / Nextcloud

  Uri _davUri() {
    var base = store.settings.webdavUrl.trim();
    if (!base.endsWith('/')) base = '$base/';
    return Uri.parse('${base}narcoquest_backup.nqbak');
  }

  Map<String, String> _davHeaders() {
    final s = store.settings;
    return {
      'Authorization': 'Basic ${base64Encode(utf8.encode('${s.webdavUser}:${s.webdavPass}'))}',
    };
  }

  /// Verschlüsselte Sicherung auf den WebDAV-Server laden. Passwort ist Pflicht.
  Future<void> uploadWebdav(String password) async {
    if (password.isEmpty) throw const FormatException('Für die Cloud ist ein Backup-Passwort Pflicht.');
    final bytes = await buildBackup(password);
    final r = await http.put(_davUri(), headers: {..._davHeaders(), 'Content-Type': 'application/octet-stream'}, body: bytes);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw HttpException('Upload fehlgeschlagen (HTTP ${r.statusCode}). Adresse, Benutzer und App-Passwort prüfen.');
    }
    store.settings.lastSync = DateTime.now().toIso8601String();
    store.changed();
  }

  Future<void> downloadWebdav(String password) async {
    final r = await http.get(_davUri(), headers: _davHeaders());
    if (r.statusCode == 404) throw const HttpException('Auf dem Server liegt noch keine Sicherung.');
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw HttpException('Download fehlgeschlagen (HTTP ${r.statusCode}).');
    }
    await restore(r.bodyBytes, password);
  }
}
