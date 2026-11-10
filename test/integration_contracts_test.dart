import 'package:auralis/integrations/media_provider.dart';
import 'package:auralis/integrations/download_engine.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProvider implements MediaProvider {
  _FakeProvider(this.id);
  @override final String id;
  @override String get displayName => id;
  @override ProviderCapabilities get capabilities => const ProviderCapabilities();
  @override
  Future<ProviderSearchPage> search(String query, {int limit = 25, String? pageToken}) async =>
      ProviderSearchPage(tracks: [ProviderTrack(id: '1', providerId: id, title: query, artist: 'Test Artist')]);
  @override
  Future<ResolvedMediaSource> resolveStream(ProviderTrack track) async =>
      ResolvedMediaSource(uri: Uri.parse('https://example.invalid/audio'));
}

void main() {
  group('MediaProviderRegistry', () {
    test('registers providers by stable id', () {
      final registry = MediaProviderRegistry()..register(_FakeProvider('catalogue'));
      expect(registry['catalogue']?.displayName, 'catalogue');
      expect(registry.providers, hasLength(1));
    });
    test('rejects duplicate provider ids', () {
      final registry = MediaProviderRegistry()..register(_FakeProvider('catalogue'));
      expect(() => registry.register(_FakeProvider('catalogue')), throwsStateError);
    });
    test('rejects empty provider ids', () {
      expect(() => MediaProviderRegistry().register(_FakeProvider('  ')), throwsArgumentError);
    });
  });
  test('download progress is bounded and unknown when size is missing', () {
    expect(const DownloadTaskSnapshot(id: 'a', status: DownloadTaskStatus.running, bytesReceived: 120, totalBytes: 100).progress, 1.0);
    expect(const DownloadTaskSnapshot(id: 'b', status: DownloadTaskStatus.running, bytesReceived: 20).progress, isNull);
  });
  test('expired media source is detectable', () {
    final source = ResolvedMediaSource(uri: Uri.parse('https://example.invalid/stream'), expiresAt: DateTime.utc(2000), headers: const {'Authorization': 'runtime-only'});
    expect(source.isExpired, isTrue);
  });
}
