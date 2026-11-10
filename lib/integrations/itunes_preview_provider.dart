import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'media_provider.dart';

/// iTunes Search API adapter. It exposes Apple's 30-second preview URLs only;
/// it does not claim full-track streaming or offline-download permission.
class ItunesPreviewProvider implements MediaProvider, DisposableMediaProvider {
  ItunesPreviewProvider({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  @override String get id => 'itunes-preview';
  @override String get displayName => 'iTunes previews';
  @override ProviderCapabilities get capabilities => const ProviderCapabilities(search: true, streamResolution: true, offlineDownloads: false);

  @override
  Future<ProviderSearchPage> search(String query, {int limit = 25, String? pageToken}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const ProviderSearchPage(tracks: []);
    final boundedLimit = limit.clamp(1, 50);
    final uri = Uri.https('itunes.apple.com', '/search', {'term': normalized, 'entity': 'song', 'limit': '$boundedLimit'});
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw HttpException('Catalogue HTTP ${response.statusCode}');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Unexpected iTunes response');
    final rows = decoded['results'];
    if (rows is! List) return const ProviderSearchPage(tracks: []);
    final tracks = <ProviderTrack>[];
    for (final value in rows) {
      if (value is! Map<String, dynamic>) continue;
      final rawId = value['trackId'];
      final rawPreview = value['previewUrl'];
      if (rawId == null || rawPreview is! String) continue;
      final preview = Uri.tryParse(rawPreview);
      if (preview == null || preview.scheme != 'https' || preview.host.isEmpty) continue;
      final trackName = value['trackName'];
      final artistName = value['artistName'];
      final artwork = value['artworkUrl100'];
      final page = value['trackViewUrl'];
      final duration = value['trackTimeMillis'];
      tracks.add(ProviderTrack(
        id: rawId.toString(), providerId: id,
        title: trackName is String && trackName.isNotEmpty ? trackName : 'Unknown title',
        artist: artistName is String && artistName.isNotEmpty ? artistName : 'Unknown artist',
        album: value['collectionName'] is String ? value['collectionName'] as String : null,
        artworkUri: artwork is String ? Uri.tryParse(artwork.replaceAll('100x100bb', '600x600bb')) : null,
        previewUri: preview,
        duration: duration is int && duration > 0 ? Duration(milliseconds: duration) : null,
        providerPageUri: page is String ? Uri.tryParse(page) : null,
      ));
    }
    return ProviderSearchPage(tracks: List.unmodifiable(tracks));
  }

  @override
  Future<ResolvedMediaSource> resolveStream(ProviderTrack track) async {
    if (track.providerId != id || track.previewUri == null) {
      throw ArgumentError('Track does not contain an iTunes preview source');
    }
    return ResolvedMediaSource(uri: track.previewUri!, mimeType: 'audio/mp4');
  }

  @override
  void dispose() => _client.close();
}
