import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AuralisApp());
}

class AuralisApp extends StatelessWidget {
  const AuralisApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0D0E10);
    const surface = Color(0xFF17191D);
    const accent = Color(0xFFE5E7EB);

    return MaterialApp(
      title: 'Auralis',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          surface: surface,
        ),
        useMaterial3: true,
      ),
      home: const AuralisShell(),
    );
  }
}

class LocalTrack {
  const LocalTrack({required this.path, required this.name});

  final String path;
  final String name;

  String get extension => name.contains('.')
      ? name.split('.').last.toUpperCase()
      : 'AUDIO';
}

class AuralisShell extends StatefulWidget {
  const AuralisShell({super.key});

  @override
  State<AuralisShell> createState() => _AuralisShellState();
}

class _AuralisShellState extends State<AuralisShell> {
  final AudioPlayer _player = AudioPlayer();
  final List<LocalTrack> _tracks = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  int _tab = 0;
  int _currentIndex = -1;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;
  bool _busy = false;

  LocalTrack? get _currentTrack =>
      _currentIndex >= 0 && _currentIndex < _tracks.length
          ? _tracks[_currentIndex]
          : null;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _subscriptions.addAll([
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _playerState = state);
      }),
      _player.onPositionChanged.listen((position) {
        if (mounted) setState(() => _position = position);
      }),
      _player.onDurationChanged.listen((duration) {
        if (mounted) setState(() => _duration = duration);
      }),
      _player.onPlayerComplete.listen((_) {
        if (_currentIndex + 1 < _tracks.length) {
          unawaited(_playAt(_currentIndex + 1));
        } else if (mounted) {
          setState(() => _playerState = PlayerState.completed);
        }
      }),
    ]);
  }

  Future<void> _importAudio() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        withData: false,
      );
      if (result == null) return;

      final existing = _tracks.map((track) => track.path).toSet();
      final imported = result.files
          .where((file) => file.path != null && !existing.contains(file.path))
          .map((file) => LocalTrack(path: file.path!, name: file.name))
          .toList();

      if (mounted && imported.isNotEmpty) {
        setState(() => _tracks.addAll(imported));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${imported.length} audio file(s)')),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not import audio: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _playAt(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    final track = _tracks[index];
    setState(() {
      _currentIndex = index;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(track.path));
    } catch (error) {
      if (mounted) setState(() => _error = 'Playback failed: $error');
    }
  }

  Future<void> _togglePlayback() async {
    if (_currentTrack == null) {
      if (_tracks.isNotEmpty) {
        await _playAt(0);
      } else {
        await _importAudio();
      }
      return;
    }
    if (_isPlaying) {
      await _player.pause();
    } else if (_playerState == PlayerState.paused) {
      await _player.resume();
    } else {
      await _playAt(_currentIndex);
    }
  }

  Future<void> _skip(int offset) async {
    final next = _currentIndex + offset;
    if (next >= 0 && next < _tracks.length) await _playAt(next);
  }

  String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomePage(
        trackCount: _tracks.length,
        onImport: _importAudio,
        onOpenLibrary: () => setState(() => _tab = 2),
      ),
      const _ExplorePage(),
      _LibraryPage(
        tracks: _tracks,
        currentIndex: _currentIndex,
        onImport: _importAudio,
        onPlay: _playAt,
      ),
      const _DownloadsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Auralis',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _SettingsPage(),
              ),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music_rounded),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download_rounded),
            label: 'Downloads',
          ),
        ],
      ),
      bottomSheet: _MiniPlayer(
        track: _currentTrack,
        playing: _isPlaying,
        position: _position,
        duration: _duration,
        error: _error,
        formatTime: _time,
        onToggle: _togglePlayback,
        onPrevious: () => _skip(-1),
        onNext: () => _skip(1),
        onSeek: (value) => _player.seek(
          Duration(milliseconds: value.round()),
        ),
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.trackCount,
    required this.onImport,
    required this.onOpenLibrary,
  });

  final int trackCount;
  final VoidCallback onImport;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 150),
      children: [
        Text(
          'YOUR MUSIC, YOUR WAY',
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 1.8,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Listen without limits.',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF292D34), Color(0xFF17191D)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.graphic_eq_rounded, size: 32),
              const SizedBox(height: 18),
              Text(
                'Your library. One player.',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add audio stored on your device and play it in Auralis.',
                style: TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Import music'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('On this device', style: textTheme.titleMedium),
            TextButton(onPressed: onOpenLibrary, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 8),
        _FeatureRow(
          icon: Icons.library_music_outlined,
          title: '$trackCount tracks in your library',
          detail: 'Local audio files imported from your device',
        ),
        const _FeatureRow(
          icon: Icons.high_quality_outlined,
          title: 'Format-aware playback',
          detail: 'Playback formats depend on Android codec support',
        ),
        const _FeatureRow(
          icon: Icons.extension_outlined,
          title: 'Online sources',
          detail: 'Provider integrations are the next development stage',
        ),
      ],
    );
  }
}

class _ExplorePage extends StatelessWidget {
  const _ExplorePage();

  @override
  Widget build(BuildContext context) {
    return const _InfoPage(
      icon: Icons.explore_outlined,
      title: 'Explore',
      subtitle:
          'Online catalogue providers are not connected yet. This area will host source discovery and provider search.',
    );
  }
}

class _LibraryPage extends StatelessWidget {
  const _LibraryPage({
    required this.tracks,
    required this.currentIndex,
    required this.onImport,
    required this.onPlay,
  });

  final List<LocalTrack> tracks;
  final int currentIndex;
  final VoidCallback onImport;
  final ValueChanged<int> onPlay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Your music',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: onImport,
                tooltip: 'Import audio',
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: tracks.isEmpty
              ? const _InfoPage(
                  icon: Icons.library_music_outlined,
                  title: 'Your library is empty',
                  subtitle:
                      'Tap + to choose audio files from your phone. Files stay in their original location.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 150),
                  itemCount: tracks.length,
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final selected = index == currentIndex;
                    return ListTile(
                      onTap: () => onPlay(index),
                      leading: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22252A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          selected
                              ? Icons.equalizer_rounded
                              : Icons.music_note_rounded,
                          color: Colors.white70,
                        ),
                      ),
                      title: Text(
                        track.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(track.extension),
                      trailing: selected
                          ? const Icon(Icons.graphic_eq_rounded)
                          : const Icon(Icons.play_arrow_rounded),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DownloadsPage extends StatelessWidget {
  const _DownloadsPage();

  @override
  Widget build(BuildContext context) {
    return const _InfoPage(
      icon: Icons.download_outlined,
      title: 'Downloads',
      subtitle:
          'Auralis does not download online tracks yet. Download support will be connected only to providers that authorize the download.',
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const ListView(
        children: [
          ListTile(
            leading: Icon(Icons.graphic_eq_rounded),
            title: Text('Audio engine'),
            subtitle: Text('Auralis local playback engine'),
          ),
          ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Storage'),
            subtitle: Text('Files are selected using Android’s system picker'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('Auralis'),
            subtitle: Text('Version 0.2.0 · Local playback milestone'),
          ),
        ],
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.track,
    required this.playing,
    required this.position,
    required this.duration,
    required this.error,
    required this.formatTime,
    required this.onToggle,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
  });

  final LocalTrack? track;
  final bool playing;
  final Duration position;
  final Duration duration;
  final String? error;
  final String Function(Duration) formatTime;
  final VoidCallback onToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds.toDouble();
    final currentMs = position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: Material(
          color: const Color(0xFF25282E),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 10, 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note_rounded),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track?.name ?? 'Nothing playing',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            error ?? (track == null ? 'Import music to begin' : 'On this device'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onPrevious,
                      icon: const Icon(Icons.skip_previous_rounded),
                    ),
                    IconButton(
                      onPressed: onToggle,
                      icon: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 30,
                      ),
                    ),
                    IconButton(
                      onPressed: onNext,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
                if (track != null)
                  Row(
                    children: [
                      Text(formatTime(position), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      Expanded(
                        child: Slider(
                          value: currentMs,
                          min: 0,
                          max: totalMs > 0 ? totalMs : 1,
                          onChanged: duration > Duration.zero ? onSeek : null,
                        ),
                      ),
                      Text(formatTime(duration), style: const TextStyle(fontSize: 10, color: Colors.white54)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF22252A),
        child: Icon(icon, color: Colors.white70),
      ),
      title: Text(title),
      subtitle: Text(detail),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.white54),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
