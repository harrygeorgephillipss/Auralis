/// Provider-neutral metadata. Adapters translate upstream responses into this model.
class ProviderTrack {
  const ProviderTrack({required this.id, required this.providerId, required this.title, required this.artist, this.album, this.artworkUri, this.duration, this.providerPageUri, this.previewUri});
  final String id;
  final String providerId;
  final String title;
  final String artist;
  final String? album;
  final Uri? artworkUri;
  final Duration? duration;
  final Uri? providerPageUri;
  final Uri? previewUri;
  String get stableId => '$providerId:$id';
}

class ProviderCapabilities {
  const ProviderCapabilities({this.search = true, this.streamResolution = false, this.offlineDownloads = false, this.lyrics = false, this.requiresAuthentication = false});
  final bool search;
  final bool streamResolution;
  final bool offlineDownloads;
  final bool lyrics;
  final bool requiresAuthentication;
}

/// Signed URLs and headers are runtime-only; never store them in library metadata.
class ResolvedMediaSource {
  const ResolvedMediaSource({required this.uri, this.mimeType, this.expiresAt, this.headers = const {}});
  final Uri uri;
  final String? mimeType;
  final DateTime? expiresAt;
  final Map<String, String> headers;
  bool get isExpired => expiresAt != null && !expiresAt!.isAfter(DateTime.now());
}

class ProviderSearchPage {
  const ProviderSearchPage({required this.tracks, this.nextPageToken});
  final List<ProviderTrack> tracks;
  final String? nextPageToken;
}

/// Online catalogue boundary. Implementations must follow provider terms and regional rules.
abstract interface class MediaProvider {
  String get id;
  String get displayName;
  ProviderCapabilities get capabilities;
  Future<ProviderSearchPage> search(String query, {int limit = 25, String? pageToken});
  Future<ResolvedMediaSource> resolveStream(ProviderTrack track);
}

class MediaProviderRegistry {
  final Map<String, MediaProvider> _providers = {};
  List<MediaProvider> get providers => List<MediaProvider>.unmodifiable(_providers.values);
  void register(MediaProvider provider) {
    final id = provider.id.trim();
    if (id.isEmpty) throw ArgumentError.value(provider.id, 'provider.id', 'Must not be empty');
    if (_providers.containsKey(id)) throw StateError('A media provider with id "$id" is already registered');
    _providers[id] = provider;
  }
  MediaProvider? operator [](String id) => _providers[id];
}

abstract interface class DisposableMediaProvider {
  void dispose();
}

/// Application catalogue that combines registered adapters without coupling
/// the Explore screen to a particular upstream service.
class ProviderCatalogue {
  ProviderCatalogue(Iterable<MediaProvider> providers) {
    for (final provider in providers) { _registry.register(provider); }
  }
  final MediaProviderRegistry _registry = MediaProviderRegistry();
  List<MediaProvider> get providers => _registry.providers;
  Future<List<({MediaProvider provider, ProviderTrack track})>> search(String query, {int limitPerProvider = 25}) async {
    final matches = <({MediaProvider provider, ProviderTrack track})>[];
    for (final provider in _registry.providers) {
      if (!provider.capabilities.search) continue;
      final page = await provider.search(query, limit: limitPerProvider);
      for (final track in page.tracks) { matches.add((provider: provider, track: track)); }
    }
    return List.unmodifiable(matches);
  }
  Future<ResolvedMediaSource> resolve(ProviderTrack track) {
    final provider = _registry[track.providerId];
    if (provider == null) throw StateError('Provider "${track.providerId}" is not registered');
    if (!provider.capabilities.streamResolution) throw UnsupportedError('Provider does not resolve playable sources');
    return provider.resolveStream(track);
  }
  void dispose() {
    for (final provider in _registry.providers) {
      if (provider is DisposableMediaProvider) provider.dispose();
    }
  }
}
