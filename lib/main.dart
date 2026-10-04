import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:tower_defense/game/game_painter.dart';
import 'package:tower_defense/game/game_state.dart';
import 'package:tower_defense/game/levels.dart';
import 'package:tower_defense/services/sound_service.dart';
import 'package:tower_defense/services/progress_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const TowerDefenseApp());
}

class TowerDefenseApp extends StatelessWidget {
  const TowerDefenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tower Defense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D5B),
          brightness: Brightness.dark,
        ),
      ),
      home: const LevelSelectScreen(),
    );
  }
}

// ====================================================================
// LEVEL-SELECTIE (fase 8: menu met kaarten, sterren, highscores)
// ====================================================================
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  Map<String, LevelVoortgang>? _voortgang;

  @override
  void initState() {
    super.initState();
    ProgressService.laad().then((v) => setState(() => _voortgang = v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D5B), Color(0xFF1B4D36)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '⚔️ TOWER DEFENSE',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD54F),
                    letterSpacing: 1.4,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3))],
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Kies een kaart',
                    style: TextStyle(fontSize: 15, color: Colors.white70)),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final lvl in alleLevels)
                      _LevelKaart(
                        config: lvl,
                        voortgang: _voortgang?[lvl.id],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GameScreen(levelConfig: lvl),
                            ),
                          ).then((_) {
                            ProgressService.laad()
                                .then((v) => setState(() => _voortgang = v));
                          });
                        },
                      ),
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

class _LevelKaart extends StatelessWidget {
  final LevelConfig config;
  final LevelVoortgang? voortgang;
  final VoidCallback onTap;

  const _LevelKaart({required this.config, this.voortgang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final v = voortgang;
    final sterren = v?.sterren ?? 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 210,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8D6E63), Color(0xFF5D4037)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD54F), width: 2.5),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(config.naam,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 4),
              Text('${config.totaalGolven} golven • start ⛁${config.startGeld}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < sterren ? Icons.star : Icons.star_border,
                      color: i < sterren ? const Color(0xFFFFD700) : Colors.white24,
                      size: 23,
                    ),
                  const Spacer(),
                  Text(
                    v?.highscore != null ? '🏆 ${v!.highscore}' : '',
                    style: const TextStyle(fontSize: 13, color: Color(0xFFFFD54F)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// GAME-SCREEN
// ====================================================================
class GameScreen extends StatefulWidget {
  final LevelConfig levelConfig;

  const GameScreen({super.key, required this.levelConfig});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late GameState _state;
  late GamePainter _painter;
  late Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _state = GameState(levelConfig: widget.levelConfig);
    _painter = GamePainter(
      state: _state,
      onTorenGeselecteerd: (type) => setState(() => _state.tePlaatsenType = type),
      onUpgrade: () => setState(() => _state.upgradeToren(_state.geselecteerdeToren!)),
      onVerkoop: () => setState(() => _state.verkoopToren(_state.geselecteerdeToren!)),
      onStartGolf: () => setState(() => _state.startGolf()),
      onTerugNaarMenu: () => Navigator.pop(context),
      onToggleModifiers: () => setState(() => _state.modifiersActief = !_state.modifiersActief),
      onToggleGeluid: () {
        _painter.geluidAan = !_painter.geluidAan;
        ProgressService.bewaarSoundMuted(!_painter.geluidAan);
      },
    );
    _ticker = Ticker(_update)..start();
    ProgressService.laadSoundMuted().then((m) => _painter.geluidAan = !m);
  }

  void _update(Duration dt) {
    if (_state.status == GameStatus.golfLoopt) {
      setState(() => _state.update(0.05));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(game: _painter),
    );
  }
}
