import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'game/entities.dart';
import 'game/game_config.dart';
import 'game/game_painter.dart';
import 'game/game_state.dart';

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
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final GameState _state = GameState();

  late final Ticker _ticker;
  Duration _vorigeTijd = Duration.zero;

  (double, double)? _hoverCel;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _vorigeTijd).inMicroseconds / 1e6).clamp(0.0, 0.25);
    _vorigeTijd = elapsed;
    if (dt > 0) {
      // Sub-stappen van max 33ms: stabiel bij hoge dt (tab-switch e.d.).
      var rest = dt;
      while (rest > 0) {
        final stap = math.min(rest, 0.033);
        _state.update(stap);
        rest -= stap;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ---- Conversie scherm→cel ----
  (double, double) _celVanPositie(Offset pos, Size veldSize) {
    return (
      (pos.dx / veldSize.width * GameState.kolommen).clamp(0.0, GameState.kolommen - 0.01),
      (pos.dy / veldSize.height * GameState.rijen).clamp(0.0, GameState.rijen - 0.01),
    );
  }

  // Toren geraakt door tik in cel (cx, cy)?
  Toren? _torenOpCel((double, double) cel) {
    Toren? geraakt;
    for (final t in _state.torens) {
      if ((t.x - cel.$1).abs() < 0.5 && (t.y - cel.$2).abs() < 0.5) geraakt = t;
    }
    return geraakt;
  }

  void _tapOpVeld(Offset pos, Size veldSize) {
    final cel = _celVanPositie(pos, veldSize);
    setState(() {
      final geraakt = _torenOpCel(cel);
      if (geraakt != null) {
        _state.geselecteerdeToren = geraakt;
        _state.tePlaatsenType = null;
        return;
      }
      if (_state.tePlaatsenType != null) {
        _state.plaatsToren(cel.$1, cel.$2);
      } else {
        _state.geselecteerdeToren = null;
      }
    });
  }

  void _hoverOpVeld(Offset pos, Size veldSize) {
    final cel = _celVanPositie(pos, veldSize);
    if (_hoverCel != cel) setState(() => _hoverCel = cel);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final veldBreedte = constraints.maxWidth;
            var veldHoogte = veldBreedte * GameState.rijen / GameState.kolommen;
            final maxVeldHoogte = constraints.maxHeight - 150; // ruimte voor HUD
            if (veldHoogte > maxVeldHoogte) veldHoogte = math.max(200.0, maxVeldHoogte);
            final veldSize = Size(veldBreedte, veldHoogte);

            return Stack(
              children: [
                Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: veldBreedte,
                          height: veldHoogte,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _tapOpVeld(d.localPosition, veldSize),
                            onPanStart: (d) => _hoverOpVeld(d.localPosition, veldSize),
                            onPanUpdate: (d) => _hoverOpVeld(d.localPosition, veldSize),
                            onPanCancel: () => setState(() => _hoverCel = null),
                            child: MouseRegion(
                              onHover: (e) => _hoverOpVeld(e.localPosition, veldSize),
                              onExit: (_) => setState(() => _hoverCel = null),
                              child: CustomPaint(
                                size: Size(veldBreedte, veldHoogte),
                                painter: GamePainter(_state, _hoverCel),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildBenedenBalk(),
                  ],
                ),
                // Toast zwevend boven de onderbalk.
                if (_state.toast != null)
                  Positioned(
                    bottom: 148,
                    left: 0,
                    right: 0,
                    child: Center(child: _toastChip(_state.toast!)),
                  ),
                // Win/verlies overlay.
                if (_state.status == GameStatus.gewonnen ||
                    _state.status == GameStatus.verloren)
                  Positioned.fill(child: _eindOverlay()),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- CoC-stijl: hout/goud paneel-decoraties ----
  BoxDecoration get _houtBalk => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF8D6E63), const Color(0xFF6D4C41)],
        ),
        border: Border(
          top: BorderSide(color: const Color(0xFFFFD54F), width: 2.5),
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.4), width: 1),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      );

  BoxDecoration get _goudChip => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), Color(0xFFF9A825)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8D6E63), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1.5)),
        ],
      );

  Widget _buildTopBar() {
    final st = _state;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF795548), Color(0xFF5D4037)],
        ),
        border: Border(
          bottom: BorderSide(color: const Color(0xFFFFD54F), width: 2.5),
        ),
      ),
      child: Row(
        children: [
          // Levens: hart in goud-chip.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: _goudChip.copyWith(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A80), Color(0xFFE53935)],
              ),
              border: Border.all(color: const Color(0xFF5D4037), width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 17),
                Text(' ${st.levens}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Geld: munt-chip.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: _goudChip,
            child: Row(
              children: [
                const Icon(Icons.monetization_on,
                    color: Color(0xFF5D4037), size: 17),
                Text(' ${st.geld}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4E342E))),
              ],
            ),
          ),
          const Spacer(),
          Text('Golf ${st.golfNummer}/${GameBalance.totaalGolven}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFFD54F))),
          const SizedBox(width: 10),
          _statusChip(st.status),
        ],
      ),
    );
  }

  Widget _statusChip(GameStatus status) {
    final (label, kleur) = switch (status) {
      GameStatus.klaarVoorStart => ('Klaar', Colors.green),
      GameStatus.tussenGolven => ('Tussen golven', Colors.teal),
      GameStatus.golfLoopt => ('Vechten!', Colors.orange),
      GameStatus.gewonnen => ('Gewonnen 🏆', Colors.amber),
      GameStatus.verloren => ('Verloren 💀', Colors.red),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: kleur.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildBenedenBalk() {
    final st = _state;
    final torenPaneel = st.geselecteerdeToren != null
        ? _buildTorenPaneel(st.geselecteerdeToren!)
        : st.tePlaatsenType != null
            ? _buildPlaatsingsPaneel(st.tePlaatsenType!)
            : null;

    return Container(
      decoration: _houtBalk,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _torenKnop(TorenType.kanon, '💥', GameBalance.kostenKanon),
              _torenKnop(TorenType.ijs, '❄️', GameBalance.kostenIjs),
              _torenKnop(TorenType.sniper, '🎯', GameBalance.kostenSniper),
              const Spacer(),
              if (st.status == GameStatus.klaarVoorStart ||
                  st.status == GameStatus.tussenGolven)
                FilledButton.icon(
                  onPressed: () => setState(_state.startGolf),
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Golf ${st.golfNummer + 1}'),
                ),
              if (st.status == GameStatus.gewonnen ||
                  st.status == GameStatus.verloren)
                FilledButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Opnieuw'),
                ),
            ],
          ),
          ?torenPaneel,
        ],
      ),
    );
  }

  Widget _toastChip(String tekst) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(tekst, style: const TextStyle(color: Colors.white)),
      );

  Widget _torenKnop(TorenType type, String emoji, int kosten) {
    final gekozen = _state.tePlaatsenType == type;
    final betaalbaar = _state.geld >= kosten;
    return GestureDetector(
      onTap: () {
        setState(() {
          _state.tePlaatsenType = gekozen ? null : type;
          _state.geselecteerdeToren = null;
        });
        HapticFeedback.selectionClick();
      },
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gekozen
                ? [const Color(0xFFFFD54F), const Color(0xFFF9A825)]
                : betaalbaar
                    ? [const Color(0xFF8D6E63), const Color(0xFF5D4037)]
                    : [const Color(0xFF616161), const Color(0xFF424242)],
          ),
          border: Border.all(
            color: gekozen
                ? Colors.white
                : (betaalbaar ? const Color(0xFFFFD54F) : Colors.red.shade700),
            width: gekozen ? 2.5 : 1.6,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 21)),
            Text(
              '$kosten',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: gekozen
                    ? const Color(0xFF4E342E)
                    : betaalbaar
                        ? const Color(0xFFFFD54F)
                        : Colors.red.shade200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaatsingsPaneel(TorenType type) {
    final stats = TorenStats.van(type, 1);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        '${stats.naam} geselecteerd — tik op vrij veld om te plaatsen '
        '(bereik ${stats.bereik.toStringAsFixed(1)}, schade ${stats.schade.toInt()})',
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }

  Widget _buildTorenPaneel(Toren t) {
    final stats = t.stats;
    final maxLevel = t.level >= GameBalance.maxTorenLevel;
    final upgradeKosten = maxLevel ? 0 : stats.upgradeKosten(t.level);
    final emoji = switch (t.type) {
      TorenType.kanon => '💥',
      TorenType.ijs => '❄️',
      TorenType.sniper => '🎯',
    };
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text('${stats.naam} L${t.level}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Text(
            'schade ${stats.schade.toInt()} • bereik ${stats.bereik.toStringAsFixed(1)}'
            '${stats.vertragingPerTref != null ? ' • traag ❄️' : ''}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 12),
          if (!maxLevel)
            FilledButton.tonal(
              onPressed: upgradeKosten <= _state.geld
                  ? () => setState(() => _state.upgradeToren(t))
                  : null,
              child: Text('↑ L${t.level + 1} ($upgradeKosten)'),
            )
          else
            const Text('MAX', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => setState(() => _state.verkoopToren(t)),
            icon: const Icon(Icons.sell, size: 15),
            label: Text('+${t.verkoopWaarde()}'),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => setState(() => _state.geselecteerdeToren = null),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _eindOverlay() {
    final gewonnen = _state.status == GameStatus.gewonnen;
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(gewonnen ? '🏆' : '💀', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(
              gewonnen ? 'Gewonnen!' : 'Verloren…',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Golf ${_state.golfNummer}/${GameBalance.totaalGolven} • '
              '${_state.torens.length} torens • ${_state.levens} levens over',
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Opnieuw spelen'),
            ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _state
        ..geld = GameBalance.startGeld
        ..levens = GameBalance.startLevens
        ..golfNummer = 0
        ..status = GameStatus.klaarVoorStart
        ..geselecteerdeToren = null
        ..tePlaatsenType = null;
      _state.vijanden.clear();
      _state.torens.clear();
      _state.projectielen.clear();
    });
  }
}