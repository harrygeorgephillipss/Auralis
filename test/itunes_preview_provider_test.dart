import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auralis/integrations/itunes_preview_provider.dart';

void main() {
  test('maps iTunes preview results into provider-neutral tracks', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'itunes.apple.com');
      expect(request.url.queryParameters['term'], 'test artist');
      return http.Response(jsonEncode({'results': [{
        'trackId': 42, 'trackName': 'Example', 'artistName': 'Artist',
        'collectionName': 'Album', 'previewUrl': 'https://audio.example/preview.m4a',
        'artworkUrl100': 'https://image.example/100x100bb.jpg',
        'trackTimeMillis': 180000, 'trackViewUrl': 'https://music.example/track/42'
      }]}), 200);
    });
    final provider = ItunesPreviewProvider(client: client);
    final page = await provider.search('test artist', limit: 30);
    expect(page.tracks, hasLength(1));
    final track = page.tracks.single;
    expect(track.stableId, 'itunes-preview:42');
    expect(track.title, 'Example');
    expect(track.previewUri?.scheme, 'https');
    expect(track.artworkUri.toString(), 'https://image.example/600x600bb.jpg');
    final source = await provider.resolveStream(track);
    expect(source.uri, track.previewUri);
    expect(provider.capabilities.offlineDownloads, isFalse);
  });

  test('rejects non-HTTPS preview URLs', () async {
    final client = MockClient((_) async => http.Response(jsonEncode({'results': [{
      'trackId': 9, 'previewUrl': 'http://insecure.example/audio.mp3'
    }]}), 200));
    final provider = ItunesPreviewProvider(client: client);
    expect((await provider.search('insecure')).tracks, isEmpty);
  });

  test('reports catalogue HTTP errors', () async {
    final provider = ItunesPreviewProvider(client: MockClient((_) async => http.Response('unavailable', 503)));
    expect(() => provider.search('offline'), throwsException);
  });
}
