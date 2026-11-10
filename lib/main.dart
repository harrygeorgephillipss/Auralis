import 'package:flutter/material.dart';

void main() {
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
        colorScheme: const ColorScheme.dark(primary: accent, surface: surface),
        useMaterial3: true,
      ),
      home: const AuralisShell(),
    );
  }
}

class AuralisShell extends StatefulWidget {
  const AuralisShell({super.key});

  @override
  State<AuralisShell> createState() => _AuralisShellState();
}

class _AuralisShellState extends State<AuralisShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomePage(),
      const _PlaceholderPage(title: 'Explore', subtitle: 'Music providers will appear here.'),
      const _PlaceholderPage(title: 'Your library', subtitle: 'Your local music collection will live here.'),
      const _PlaceholderPage(title: 'Downloads', subtitle: 'Download queue and completed files will appear here.'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Auralis', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const _PlaceholderPage(
                title: 'Settings',
                subtitle: 'Themes, player layouts, audio and provider preferences.',
              ),
            )),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore_rounded), label: 'Explore'),
          NavigationDestination(icon: Icon(Icons.library_music_outlined), selectedIcon: Icon(Icons.library_music_rounded), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.download_outlined), selectedIcon: Icon(Icons.download_rounded), label: 'Downloads'),
        ],
      ),
      bottomSheet: const _MiniPlayer(),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
      children: [
        Text('YOUR MUSIC, YOUR WAY', style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.8, color: Colors.white54)),
        const SizedBox(height: 8),
        Text('Listen without limits.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1C20),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.graphic_eq_rounded, size: 30, color: Colors.white70),
              const SizedBox(height: 18),
              Text('A new listening experience', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Auralis is being built. Your player, library, providers and downloads will come together here.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text('Coming into focus', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        const _FeatureRow(icon: Icons.palette_outlined, title: 'Make it yours', detail: 'Themes, layouts and visual details'),
        const _FeatureRow(icon: Icons.headphones_outlined, title: 'High-quality playback', detail: 'Display the actual source codec and quality'),
        const _FeatureRow(icon: Icons.extension_outlined, title: 'Provider extensions', detail: 'Connect supported music sources'),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(backgroundColor: const Color(0xFF22252A), child: Icon(icon, color: Colors.white70)),
    title: Text(title),
    subtitle: Text(detail),
  );
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          color: const Color(0xFF25282E),
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.music_note_rounded),
            ),
            title: const Text('Nothing playing', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Auralis preview'),
            trailing: IconButton(onPressed: null, icon: const Icon(Icons.play_arrow_rounded)),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_rounded, size: 42, color: Colors.white54),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    ),
  );
}
