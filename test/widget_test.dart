import 'package:auralis/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local track metadata survives database-shaped serialization', () {
    const track = Track(
      id: 'local-1',
      uri: '/storage/music/example.flac',
      title: 'Example',
      artist: 'Auralis Test',
      kind: 'local',
      album: 'Test Album',
      durationMs: 123000,
    );

    final restored = Track.fromMap(track.toMap());

    expect(restored.id, track.id);
    expect(restored.uri, track.uri);
    expect(restored.title, track.title);
    expect(restored.artist, track.artist);
    expect(restored.kind, 'local');
    expect(restored.durationMs, 123000);
    expect(restored.toItem().extras?['uri'], track.uri);
  });

  test('online catalogue tracks retain their preview source', () {
    const track = Track(
      id: 'itunes-123',
      uri: 'https://example.invalid/preview.m4a',
      title: 'Preview',
      artist: 'Artist',
      kind: 'remote',
      providerUrl: 'https://music.apple.com/track/123',
    );

    final item = track.toItem();
    expect(item.id, 'itunes-123');
    expect(item.extras?['kind'], 'remote');
    expect(item.extras?['uri'], 'https://example.invalid/preview.m4a');
  });
}
