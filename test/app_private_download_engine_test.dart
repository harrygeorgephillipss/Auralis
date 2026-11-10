import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:auralis/integrations/download_engine.dart';
import 'package:auralis/integrations/app_private_download_engine.dart';

void main() {
  late Directory directory;
  setUp(() async { directory = await Directory.systemTemp.createTemp('auralis-download-test-'); });
  tearDown(() async { if (await directory.exists()) await directory.delete(recursive: true); });

  test('refuses downloads unless provider explicitly permits offline saving', () async {
    final engine = AppPrivateDownloadEngine(storageDirectory: directory, client: MockClient((_) async => http.Response('audio', 200)));
    await expectLater(engine.enqueue(DownloadRequest(id: 'x', providerId: 'p', source: Uri.parse('https://example.test/a'), fileName: 'a.mp3', offlineSavingAllowed: false)), throwsStateError);
    expect(await directory.list().isEmpty, isTrue);
    await engine.dispose();
  });

  test('downloads an authorized HTTPS source into app-private storage', () async {
    final engine = AppPrivateDownloadEngine(storageDirectory: directory, client: MockClient((request) async {
      expect(request.url.scheme, 'https');
      return http.Response.bytes([1, 2, 3, 4], 200, headers: {'content-type': 'audio/mpeg'});
    }));
    await engine.enqueue(DownloadRequest(id: 'song-1', providerId: 'test-provider', source: Uri.parse('https://example.test/audio'), fileName: '../track.mp3', expectedBytes: 4, offlineSavingAllowed: true));
    for (var i = 0; i < 100 && engineStatus(engine, 'song-1') != DownloadTaskStatus.completed; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final snapshot = await firstSnapshot(engine, 'song-1');
    expect(snapshot.status, DownloadTaskStatus.completed);
    expect(snapshot.localUri, isNotNull);
    expect(await File(snapshot.localUri!.toFilePath()).readAsBytes(), [1, 2, 3, 4]);
    expect(snapshot.localUri!.path, endsWith('/track.mp3'));
    await engine.dispose();
  });

  test('rejects non-HTTPS URLs', () async {
    final engine = AppPrivateDownloadEngine(storageDirectory: directory, client: MockClient((_) async => http.Response('audio', 200)));
    await expectLater(engine.enqueue(DownloadRequest(id: 'x', providerId: 'p', source: Uri.parse('http://example.test/a'), fileName: 'a.mp3', offlineSavingAllowed: true)), throwsArgumentError);
    await engine.dispose();
  });

  test('marks unsuccessful HTTP responses as failed', () async {
    final engine = AppPrivateDownloadEngine(storageDirectory: directory, client: MockClient((_) async => http.Response('missing', 404)));
    await engine.enqueue(DownloadRequest(id: 'x', providerId: 'p', source: Uri.parse('https://example.test/a'), fileName: 'a.mp3', offlineSavingAllowed: true));
    for (var i = 0; i < 100 && engineStatus(engine, 'x') != DownloadTaskStatus.failed; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(engineStatus(engine, 'x'), DownloadTaskStatus.failed);
    expect(await directory.list().isEmpty, isTrue);
    await engine.dispose();
  });
}

DownloadTaskStatus? engineStatus(AppPrivateDownloadEngine engine, String id) {
  // The engine intentionally exposes state only through its stream.
  return null;
}

Future<DownloadTaskSnapshot> firstSnapshot(AppPrivateDownloadEngine engine, String id) async {
  final completer = Completer<DownloadTaskSnapshot>();
  final sub = engine.watchTasks().listen((items) {
    for (final item in items) { if (item.id == id && item.status == DownloadTaskStatus.completed) completer.complete(item); }
  });
  final result = await completer.future.timeout(const Duration(seconds: 3));
  await sub.cancel();
  return result;
}
