import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

const _eq = MethodChannel('xyz.luan/audioplayers');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (error) {
    debugPrint('Auralis audio-session setup unavailable: $error');
  }
  late final AuralisAudioHandler handler;
  try {
    handler = await AudioService.init(
      builder: AuralisAudioHandler.new,
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.auralis.playback',
        androidNotificationChannelName: 'Auralis playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: false,
      ),
    );
  } catch (error, stack) {
    debugPrint('Auralis media service unavailable; using in-app playback: $error\\n$stack');
    handler = AuralisAudioHandler();
  }
  try {
    final session = await AudioSession.instance;
    session.interruptionEventStream.listen((event) {
      if (event.begin && event.type == AudioInterruptionType.pause) {
        unawaited(handler.pause());
      }
    }, onError: (Object error) => debugPrint('Audio interruption stream: $error'));
    session.becomingNoisyEventStream.listen((_) => unawaited(handler.pause()),
      onError: (Object error) => debugPrint('Audio route stream: $error'));
  } catch (error) {
    debugPrint('Auralis audio interruption listeners unavailable: $error');
  }
  try {
    await LibraryDb.instance.open();
  } catch (error, stack) {
    debugPrint('Auralis library initialization failed: $error\\n$stack');
  }
  runApp(AuralisApp(handler: handler));
}

class Track {
  const Track({required this.id, required this.uri, required this.title,
    required this.artist, required this.kind, this.album = '',
    this.artwork, this.durationMs = 0, this.providerUrl});
  final String id, uri, title, artist, kind, album;
  final String? artwork, providerUrl;
  final int durationMs;

  MediaItem toItem() => MediaItem(
    id: id, title: title, artist: artist, album: album,
    artUri: artwork == null ? null : Uri.tryParse(artwork!),
    duration: Duration(milliseconds: durationMs < 0 ? 0 : durationMs),
    extras: {'uri': uri, 'kind': kind},
  );

  Map<String, Object?> toMap() => {
    'id': id, 'uri': uri, 'title': title, 'artist': artist,
    'kind': kind, 'album': album, 'artwork': artwork,
    'duration_ms': durationMs, 'provider_url': providerUrl,
  };

  factory Track.fromMap(Map<String, Object?> m) => Track(
    id: m['id']! as String, uri: m['uri']! as String,
    title: m['title']! as String, artist: m['artist'] as String? ?? '',
    kind: m['kind']! as String, album: m['album'] as String? ?? '',
    artwork: m['artwork'] as String?,
    durationMs: m['duration_ms'] as int? ?? 0,
    providerUrl: m['provider_url'] as String?,
  );
}

class LibraryDb {
  LibraryDb._();
  static final instance = LibraryDb._();
  Database? _db;
  Future<Database>? _opening;
  Future<void> open() async {
    if (_db?.isOpen ?? false) return;
    final pending = _opening;
    if (pending != null) {
      _db = await pending;
      return;
    }
    final future = openDatabase(p.join(await getDatabasesPath(), 'auralis.db'),
      version: 1, onCreate: (db, _) => db.execute('''
        CREATE TABLE tracks(id TEXT PRIMARY KEY, uri TEXT NOT NULL,
        title TEXT NOT NULL, artist TEXT NOT NULL, kind TEXT NOT NULL,
        album TEXT, artwork TEXT, duration_ms INTEGER, provider_url TEXT)
      '''));
    _opening = future;
    try { _db = await future; }
    finally { _opening = null; }
  }
  Future<Database> get database async {
    if (_db == null || !_db!.isOpen) await open();
    return _db!;
  }
  Future<List<Track>> all() async =>
    (await (await database).query('tracks', orderBy: 'title COLLATE NOCASE'))
      .map(Track.fromMap).toList();
  Future<void> save(Track t) async => (await database).insert('tracks', t.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> remove(String id) async =>
    (await database).delete('tracks', where: 'id=?', whereArgs: [id]);
}

class AuralisAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer player = AudioPlayer();
  final List<MediaItem> _queue = [];
  int _index = -1;
  bool _ready = false;
  bool _disposed = false;
  int _playRequest = 0;
  bool _eqEnabled = false;
  List<double> _eqGains = List<double>.filled(5, 0);
  Duration _position = Duration.zero;
  StreamSubscription<PlayerState>? _states;
  StreamSubscription<Duration>? _positions, _durations;
  StreamSubscription<void>? _complete;

  AuralisAudioHandler() {
    _states = player.onPlayerStateChanged.listen((_) => _publish(),
      onError: (Object e) => debugPrint('Auralis player state stream: $e'));
    _positions = player.onPositionChanged.listen((position) { _position = position; _publish(); },
      onError: (Object e) => debugPrint('Auralis position stream: $e'));
    _durations = player.onDurationChanged.listen((d) {
      final item = mediaItem.value;
      if (item != null) mediaItem.add(item.copyWith(duration: d));
      _publish();
    }, onError: (Object e) => debugPrint('Auralis duration stream: $e'));
    _complete = player.onPlayerComplete.listen((_) {
      if (_index + 1 < _queue.length) {
        unawaited(_playIndex(_index + 1).catchError((Object e) {
          debugPrint('Auralis next-track playback failed: $e');
          _publish();
        }));
      } else {
        _publish(completed: true);
      }
    }, onError: (Object e) => debugPrint('Auralis completion stream: $e'));
  }

  Future<void> playTrack(Track track) async {
    if (_disposed) return;
    final item = track.toItem();
    final old = _queue.indexWhere((x) => x.id == item.id);
    if (old >= 0) { _queue[old] = item; _index = old; }
    else { _queue.add(item); _index = _queue.length - 1; }
    queue.add(List.unmodifiable(_queue));
    try { await _playIndex(_index); }
    catch (error) {
      debugPrint('Auralis could not play "${track.title}": $error');
      _ready = false;
      _publish();
    }
  }

  Future<void> _playIndex(int i) async {
    if (_disposed || i < 0 || i >= _queue.length) return;
    final request = ++_playRequest;
    _index = i;
    final item = _queue[i];
    final uri = item.extras?['uri'] as String?;
    final kind = item.extras?['kind'] as String? ?? 'remote';
    if (uri == null) return;
    mediaItem.add(item);
    _ready = false;
    _position = Duration.zero;
    _publish(loading: true);
    try {
      await player.stop();
      if (_disposed || request != _playRequest) return;
      if (kind == 'local') {
        await player.play(DeviceFileSource(uri));
      } else {
        await player.play(UrlSource(uri));
      }
      if (_disposed || request != _playRequest) return;
      _ready = true;
      if (_eqEnabled) {
        try { await _applyEqualizer(); }
        on PlatformException catch (e) {
          debugPrint('Equalizer unavailable; playback continues: ${e.message}');
        } catch (e) { debugPrint('Equalizer unavailable; playback continues: $e'); }
      }
      _publish();
    } catch (e) {
      _ready = false;
      _publish();
      rethrow;
    }
  }

  Future<void> setEqualizer(bool enabled, List<double> gains) async {
    if (gains.length != 5 || gains.any((value) => !value.isFinite)) {
      throw ArgumentError('The equalizer requires five finite gain values.');
    }
    _eqEnabled = enabled;
    _eqGains = gains.map((value) => value.clamp(-12.0, 12.0).toDouble()).toList();
    if (_ready) await _applyEqualizer();
  }

  Future<void> _applyEqualizer() async {
    await _eq.invokeMethod<void>('setEqualizer', {
      'playerId': player.playerId,
      'configuration': {
        'enabled': _eqEnabled,
        'frequencies': [63.0, 250.0, 1000.0, 4000.0, 16000.0],
        'gains': _eqGains, 'inputGain': 0.0, 'balance': 0.0,
        'compressor': false, 'limiter': true,
        'threshold': -18.0, 'ratio': 3.0, 'attack': 10.0, 'release': 150.0,
      },
    });
  }

  void _publish({bool loading = false, bool completed = false}) {
    final playing = player.state == PlayerState.playing;
    playbackState.add(PlaybackState(
      controls: [MediaControl.skipToPrevious,
        playing ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext, MediaControl.stop],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: completed ? AudioProcessingState.completed :
        loading ? AudioProcessingState.loading :
        _ready ? AudioProcessingState.ready : AudioProcessingState.idle,
      playing: playing,
      updatePosition: _position,
      bufferedPosition: Duration.zero,
      speed: 1.0,
      queueIndex: _index < 0 ? null : _index,
    ));
  }

  @override Future<void> play() async {
    if (_disposed) return;
    try {
      if (_index >= 0 && (!_ready || player.state == PlayerState.completed)) {
        if (player.state == PlayerState.completed) await player.seek(Duration.zero);
        if (!_ready) { await _playIndex(_index); return; }
      }
      await player.resume();
    } catch (e) { debugPrint('Auralis resume failed: $e'); }
  }
  @override Future<void> pause() async {
    if (_disposed) return;
    try { await player.pause(); } catch (e) { debugPrint('Auralis pause failed: $e'); }
  }
  @override Future<void> seek(Duration position) async {
    if (_disposed) return;
    try { await player.seek(position); } catch (e) { debugPrint('Auralis seek failed: $e'); }
  }
  @override Future<void> stop() async {
    if (_disposed) return;
    ++_playRequest;
    try { await player.stop(); } catch (e) { debugPrint('Auralis stop failed: $e'); }
    _ready = false; await super.stop(); _publish();
  }
  @override Future<void> skipToNext() async {
    if (_index + 1 < _queue.length) {
      try { await _playIndex(_index + 1); }
      catch (error) { debugPrint('Auralis next track failed: $error'); }
    }
  }
  @override Future<void> skipToPrevious() async {
    if (_index > 0) {
      try { await _playIndex(_index - 1); }
      catch (error) { debugPrint('Auralis previous track failed: $error'); }
    }
  }
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states?.cancel(); await _positions?.cancel();
    await _durations?.cancel(); await _complete?.cancel();
    await player.dispose();
  }
}

class _LaunchGate extends StatefulWidget {
  const _LaunchGate({required this.handler});
  final AuralisAudioHandler handler;
  @override State<_LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<_LaunchGate> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _complete = false;

  @override void initState() {
    super.initState();
    _controller = AnimationController(vsync: this,
      duration: const Duration(milliseconds: 1350))..forward();
    Future<void>.delayed(const Duration(milliseconds: 1650), () {
      if (mounted) setState(() => _complete = true);
    });
  }

  @override void dispose() { _controller.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    if (_complete) return AuralisShell(handler: widget.handler);
    return Scaffold(backgroundColor: const Color(0xFF0D0E10),
      body: Center(child: AnimatedBuilder(animation: _controller, builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(_controller.value);
        return Opacity(opacity: Curves.easeOut.transform(_controller.value),
          child: Transform.scale(scale: .92 + (.08 * progress),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 112, height: 112,
                child: CustomPaint(painter: AuralisMarkPainter(progress: progress))),
              const SizedBox(height: 24),
              const Text('AURALIS', style: TextStyle(fontSize: 17,
                letterSpacing: 5.5, fontWeight: FontWeight.w500, color: Colors.white)),
              const SizedBox(height: 8),
              const Text('MUSIC, IN ITS ELEMENT',
                style: TextStyle(fontSize: 9, letterSpacing: 2.3, color: Colors.white54)),
            ]),
          ),
        );
      })),
    );
  }
}

class AuralisMarkPainter extends CustomPainter {
  const AuralisMarkPainter({required this.progress});
  final double progress;

  @override void paint(Canvas canvas, Size size) {
    final scale = size.width / 128;
    canvas.save();
    canvas.scale(scale, size.height / 128);
    final paint = Paint()..color = Colors.white..style = PaintingStyle.stroke
      ..strokeWidth = 7.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final mark = Path()
      ..moveTo(19, 91)
      ..cubicTo(34, 65, 45, 37, 58, 17)
      ..cubicTo(61, 12, 67, 12, 70, 18)
      ..lineTo(109, 91);
    final metric = mark.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0).toDouble()), paint);
    if (progress > .48) {
      final bar = Path()..moveTo(42, 66)..lineTo(84, 66);
      final barMetric = bar.computeMetrics().first;
      final barProgress = ((progress - .48) / .52).clamp(0.0, 1.0).toDouble();
      canvas.drawPath(barMetric.extractPath(0, barMetric.length * barProgress), paint);
    }
    canvas.restore();
  }

  @override bool shouldRepaint(covariant AuralisMarkPainter oldDelegate) =>
    oldDelegate.progress != progress;
}

class AuralisApp extends StatelessWidget {
  const AuralisApp({required this.handler, super.key});
  final AuralisAudioHandler handler;
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'Auralis', debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0E10),
      colorScheme: const ColorScheme.dark(primary: Color(0xFFE5E7EB),
        surface: Color(0xFF17191D)), useMaterial3: true),
    home: _LaunchGate(handler: handler),
  );
}

class AuralisShell extends StatefulWidget {
  const AuralisShell({required this.handler, super.key});
  final AuralisAudioHandler handler;
  @override State<AuralisShell> createState() => _AuralisShellState();
}

class _AuralisShellState extends State<AuralisShell> {
  final _search = TextEditingController();
  final List<Track> _library = [], _results = [];
  int _tab = 0;
  bool _busy = false, _eqEnabled = false;
  String? _error;
  int _searchSequence = 0;
  List<double> _gains = List<double>.filled(5, 0);

  @override void initState() { super.initState(); _loadLibrary(); }
  Future<void> _loadLibrary() async {
    try {
      final rows = await LibraryDb.instance.all();
      if (mounted) setState(() { _library..clear()..addAll(rows); });
    } catch (e) {
      debugPrint('Auralis library load failed: $e');
      if (mounted) setState(() => _error = 'Library could not be loaded. Try again later.');
    }
  }
  Future<void> _import() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);
      if (!mounted || files.isEmpty) return;
      final appDirectory = await getApplicationDocumentsDirectory();
      final musicDirectory = Directory(p.join(appDirectory.path, 'music'));
      await musicDirectory.create(recursive: true);
      var imported = 0;
      for (final file in files) {
        final sourcePath = file.path;
        if (sourcePath == null) continue;
        final source = File(sourcePath);
        if (!await source.exists()) continue;
        final safeName = p.basename(file.name).replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
        final destination = p.join(musicDirectory.path,
          '${DateTime.now().microsecondsSinceEpoch}_$safeName');
        final stored = await source.copy(destination);
        await LibraryDb.instance.save(Track(
          id: 'local_${p.basename(destination)}', uri: stored.path,
          title: p.basenameWithoutExtension(file.name),
          artist: 'Local file', kind: 'local'));
        imported++;
      }
      await _loadLibrary();
      if (mounted && imported == 0) {
        setState(() => _error = 'No readable audio files were imported.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Audio import failed: $e');
    }
  }
  Future<void> _discover(String query) async {
    if (query.trim().isEmpty) return;
    final request = ++_searchSequence;
    setState(() { _busy = true; _error = null; _results.clear(); });
    final found = <Track>[];
    try {
      final uri = Uri.https('itunes.apple.com', '/search',
        {'term': query.trim(), 'entity': 'song', 'limit': '30'});
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception('Catalogue HTTP ${response.statusCode}');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      for (final row in (data['results'] as List<dynamic>? ?? [])) {
        if (row is! Map<String, dynamic> || row['previewUrl'] is! String || row['trackId'] == null) continue;
        final previewUri = Uri.tryParse(row['previewUrl'] as String);
        if (previewUri == null || previewUri.scheme != 'https') continue;
        found.add(Track(
          id: 'itunes_${row['trackId']}', uri: previewUri.toString(),
          title: row['trackName'] as String? ?? 'Unknown title',
          artist: row['artistName'] as String? ?? 'Unknown artist',
          album: row['collectionName'] as String? ?? '',
          artwork: (row['artworkUrl100'] as String?)?.replaceAll('100x100bb', '600x600bb'),
          durationMs: row['trackTimeMillis'] as int? ?? 0,
          kind: 'remote', providerUrl: row['trackViewUrl'] as String?));
      }
    } on TimeoutException {
      if (request == _searchSequence) _error = 'The catalogue request timed out. Check your connection and retry.';
    } catch (e) {
      if (request == _searchSequence) _error = 'Search failed: $e';
    } finally {
      if (mounted && request == _searchSequence) {
        setState(() { _results..clear()..addAll(found); _busy = false; });
      }
    }
  }
  Future<void> _save(Track t) async {
    try { await LibraryDb.instance.save(t); await _loadLibrary(); }
    catch (e) { if (mounted) setState(() => _error = 'Could not save track: $e'); }
  }
  Future<void> _remove(Track t) async {
    try {
      await LibraryDb.instance.remove(t.id);
      if (t.kind == 'local') {
        final appDirectory = await getApplicationDocumentsDirectory();
        final musicRoot = p.normalize(p.join(appDirectory.path, 'music'));
        final candidate = p.normalize(t.uri);
        if (p.isWithin(musicRoot, candidate)) {
          final file = File(candidate);
          if (await file.exists()) await file.delete();
        }
      }
      await _loadLibrary();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not remove track: $e');
    }
  }
  Future<void> _showEq() async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) =>
      _EqualizerPage(enabled: _eqEnabled, gains: List.of(_gains),
        onChanged: (enabled, gains) async {
          await widget.handler.setEqualizer(enabled, gains);
          if (mounted) setState(() { _eqEnabled = enabled; _gains = List.of(gains); });
        })));
  }
  @override void dispose() { _search.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    final pages = [
      _HomePage(count: _library.length, onImport: _import,
        onLibrary: () => setState(() => _tab = 2)),
      _ExplorePage(controller: _search, results: _results, busy: _busy,
        error: _error, onSearch: _discover, onPlay: widget.handler.playTrack,
        onSave: _save),
      _LibraryPage(tracks: _library, onImport: _import,
        onPlay: widget.handler.playTrack, onRemove: _remove),
      const _DownloadsPage(),
    ];
    return Scaffold(
      appBar: AppBar(leading: const Padding(padding: EdgeInsets.all(12),
        child: CustomPaint(painter: AuralisMarkPainter(progress: 1))),
        title: const Text('Auralis', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(tooltip: 'Equalizer', onPressed: _showEq,
            icon: const Icon(Icons.equalizer_rounded)),
          IconButton(tooltip: 'Settings', onPressed: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const _SettingsPage())),
            icon: const Icon(Icons.tune_rounded)),
        ]),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab,
        onDestinationSelected: (v) => setState(() => _tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.download_outlined), label: 'Downloads'),
        ]),
      bottomSheet: _MiniPlayer(handler: widget.handler),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.count, required this.onImport, required this.onLibrary});
  final int count; final VoidCallback onImport, onLibrary;
  @override Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 130), children: [
      const Text('YOUR MUSIC, YOUR WAY', style: TextStyle(color: Colors.white54, letterSpacing: 1.8)),
      const SizedBox(height: 8),
      Text('Listen without limits.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: const Color(0xFF1A1C20),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .07))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.graphic_eq_rounded, size: 30),
          const SizedBox(height: 16),
          Text('Your library. One player.', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Discover music online or play audio stored on your phone.'),
          const SizedBox(height: 18),
          Wrap(spacing: 10, children: [
            FilledButton.icon(onPressed: onImport, icon: const Icon(Icons.add), label: const Text('Import music')),
            OutlinedButton(onPressed: onLibrary, child: const Text('Library')),
          ]),
        ])),
      const SizedBox(height: 20),
      ListTile(leading: const Icon(Icons.library_music_outlined), title: Text('$count saved tracks'), subtitle: const Text('Persistent SQLite library')),
      const ListTile(leading: Icon(Icons.notifications_active_outlined), title: Text('Background playback'), subtitle: Text('Android media notification and lock-screen controls')),
      const ListTile(leading: Icon(Icons.equalizer_rounded), title: Text('5-band equalizer'), subtitle: Text('Android DynamicsProcessing where supported')),
    ]);
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage({required this.controller, required this.results, required this.busy,
    required this.error, required this.onSearch, required this.onPlay, required this.onSave});
  final TextEditingController controller; final List<Track> results;
  final bool busy; final String? error;
  final ValueChanged<String> onSearch;
  final ValueChanged<Track> onPlay, onSave;
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.all(16), child: TextField(
      controller: controller, textInputAction: TextInputAction.search,
      onSubmitted: onSearch,
      decoration: InputDecoration(hintText: 'Search songs and artists',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(onPressed: () => onSearch(controller.text), icon: const Icon(Icons.arrow_forward)),
        filled: true, fillColor: const Color(0xFF1B1D22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)))),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 18),
      child: Align(alignment: Alignment.centerLeft, child: Text('iTunes catalogue · 30-second previews', style: TextStyle(color: Colors.white54, fontSize: 11)))),
    if (busy) const LinearProgressIndicator(),
    if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
    Expanded(child: results.isEmpty && !busy
      ? const Center(child: Text('Search to discover music and play previews.'))
      : ListView.builder(padding: const EdgeInsets.only(bottom: 130),
        itemCount: results.length, itemBuilder: (_, i) {
          final t = results[i];
          return ListTile(leading: _Art(url: t.artwork),
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(t.artist), onTap: () => onPlay(t),
            trailing: IconButton(onPressed: () => onSave(t), icon: const Icon(Icons.add_circle_outline)));
        })),
  ]);
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({required this.tracks, required this.onImport, required this.onPlay, required this.onRemove});
  final List<Track> tracks; final VoidCallback onImport;
  final ValueChanged<Track> onPlay, onRemove;
  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 8, 12, 8), child: Row(children: [
      Expanded(child: Text('Your music', style: Theme.of(context).textTheme.headlineSmall)),
      IconButton.filledTonal(onPressed: onImport, icon: const Icon(Icons.add))])),
    Expanded(child: tracks.isEmpty ? const Center(child: Text('Import audio or save a discovery result.'))
      : ListView.builder(padding: const EdgeInsets.only(bottom: 130), itemCount: tracks.length,
        itemBuilder: (_, i) { final t = tracks[i]; return ListTile(
          leading: _Art(url: t.artwork), title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(t.artist), onTap: () => onPlay(t),
          trailing: IconButton(onPressed: () => onRemove(t), icon: const Icon(Icons.delete_outline)));
        })),
  ]);
}

class _DownloadsPage extends StatelessWidget {
  const _DownloadsPage();
  @override Widget build(BuildContext context) => const _InfoPage(
    icon: Icons.extension_outlined, title: 'Provider downloads',
    subtitle: 'Mornye’s full extension runtime and verified download queue are not yet connected to this Auralis shell. Catalogue previews are not downloadable here.');
}

class _EqualizerPage extends StatefulWidget {
  const _EqualizerPage({required this.enabled, required this.gains, required this.onChanged});
  final bool enabled; final List<double> gains;
  final Future<void> Function(bool, List<double>) onChanged;
  @override State<_EqualizerPage> createState() => _EqualizerPageState();
}
class _EqualizerPageState extends State<_EqualizerPage> {
  late bool enabled = widget.enabled;
  late List<double> gains = List.of(widget.gains);
  String? error;
  static const labels = ['63 Hz', '250 Hz', '1 kHz', '4 kHz', '16 kHz'];
  Future<void> apply() async {
    try { await widget.onChanged(enabled, gains); if (mounted) setState(() => error = null); }
    catch (e) { if (mounted) setState(() => error = e.toString()); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Equalizer')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Enable equalizer'),
        value: enabled, onChanged: (v) { setState(() => enabled = v); apply(); }),
      for (var i = 0; i < 5; i++) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(labels[i]), Text('${gains[i].round()} dB')]),
        Slider(min: -12, max: 12, divisions: 24, value: gains[i],
          onChanged: (v) { setState(() => gains[i] = v); apply(); }),
      ]),
      if (error != null) Text(error!, style: const TextStyle(color: Colors.orangeAccent)),
      const Text('Android DynamicsProcessing is required (Android 9+). Some audio routes may not support effects.', style: TextStyle(color: Colors.white54)),
    ]));
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.handler});
  final AuralisAudioHandler handler;
  @override Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
    stream: handler.mediaItem, builder: (context, ms) {
      final item = ms.data;
      return StreamBuilder<PlaybackState>(stream: handler.playbackState, builder: (context, ps) {
        final playing = ps.data?.playing ?? false;
        return SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Material(color: const Color(0xFF25282E), borderRadius: BorderRadius.circular(18),
            child: ListTile(leading: _Art(url: item?.artUri?.toString(), size: 42),
              title: Text(item?.title ?? 'Nothing playing', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(item?.artist ?? 'Choose a track'),
              trailing: IconButton(onPressed: item == null ? null : () => playing ? handler.pause() : handler.play(),
                icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30)),
              onTap: item == null ? null : () => showModalBottomSheet<void>(context: context,
                builder: (_) => _NowPlaying(handler: handler, item: item))))));
      });
    });
}

class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.handler, required this.item});
  final AuralisAudioHandler handler; final MediaItem item;
  @override Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      _Art(url: item.artUri?.toString(), size: 220),
      const SizedBox(height: 16),
      Text(item.title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      Text(item.artist ?? '', style: const TextStyle(color: Colors.white60)),
      StreamBuilder<PlaybackState>(stream: handler.playbackState, builder: (context, s) {
        final playing = s.data?.playing ?? false;
        return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: handler.skipToPrevious, icon: const Icon(Icons.skip_previous, size: 36)),
          IconButton(onPressed: () => playing ? handler.pause() : handler.play(),
            icon: Icon(playing ? Icons.pause_circle : Icons.play_circle, size: 58)),
          IconButton(onPressed: handler.skipToNext, icon: const Icon(Icons.skip_next, size: 36)),
        ]);
      }),
    ])));
}

class _Art extends StatelessWidget {
  const _Art({required this.url, this.size = 48});
  final String? url; final double size;
  @override Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(10),
    child: url == null ? Container(width: size, height: size, color: Colors.white10, child: const Icon(Icons.music_note))
      : Image.network(url!, width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(width: size, height: size, color: Colors.white10, child: const Icon(Icons.music_note))));
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')),
    body: ListView(children: [
      const ListTile(leading: Icon(Icons.storage), title: Text('Persistent library'), subtitle: Text('Imported audio is copied into app-private storage')),
      const ListTile(leading: Icon(Icons.notifications_active), title: Text('Background playback'), subtitle: Text('Media session and Android notification')),
      const ListTile(leading: Icon(Icons.extension), title: Text('Provider extensions'), subtitle: Text('Full Mornye extension runtime is not yet integrated')),
      ListTile(leading: const Icon(Icons.info_outline), title: const Text('About Auralis'),
        subtitle: const Text('Version, acknowledgements and open-source licences'),
        onTap: () => showAboutDialog(context: context, applicationName: 'Auralis',
          applicationVersion: '0.4.0', applicationLegalese: 'Auralis is licensed under LGPL-3.0-only. Third-party notices are available in the source repository.')),
      ListTile(leading: const Icon(Icons.policy_outlined), title: const Text('Open-source licences'),
        onTap: () => showLicensePage(context: context, applicationName: 'Auralis', applicationVersion: '0.4.0',
          applicationLegalese: 'Auralis source: LGPL-3.0-only. See THIRD_PARTY_NOTICES.md for upstream attributions.')),
    ]));
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title, subtitle;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 42, color: Colors.white54), const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8), Text(subtitle, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white60, height: 1.45)),
    ])));
}
