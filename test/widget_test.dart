import 'package:auralis/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('track serialization preserves local file metadata', () {
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

  test('online catalogue tracks retain preview source and artwork', () {
    const track = Track(
      id: 'itunes-123',
      uri: 'https://example.invalid/preview.m4a',
      title: 'Preview',
      artist: 'Artist',
      kind: 'remote',
      artwork: 'https://example.invalid/artwork.jpg',
      providerUrl: 'https://music.apple.com/track/123',
    );

    final item = track.toItem();
    expect(item.id, 'itunes-123');
    expect(item.extras?['kind'], 'remote');
    expect(item.extras?['uri'], track.uri);
    expect(item.artUri.toString(), track.artwork);
  });

  test('media items never receive a negative duration', () {
    const track = Track(
      id: 'zero-duration',
      uri: 'https://example.invalid/audio.m4a',
      title: 'No duration',
      artist: 'Artist',
      kind: 'remote',
      durationMs: 0,
    );
    expect(track.toItem().duration, Duration.zero);
  });

  test('negative source durations are normalized to zero', () {
    const track = Track(
      id: 'bad-duration',
      uri: 'https://example.invalid/audio.m4a',
      title: 'Bad duration',
      artist: 'Artist',
      kind: 'remote',
      durationMs: -500,
    );
    expect(track.toItem().duration, Duration.zero);
  });
}
