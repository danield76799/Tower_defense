import 'dart:math' as math;

import 'entities.dart';
import 'game_config.dart';

/// Game-status.
enum GameStatus { klaarVoorStart, golfLoopt, tussenGolven, gewonnen, verloren }

/// De volledige game-state en -logica. Geen Flutter-imports: puur Dart,
/// zodat de hele game te unit-testen is.
class GameState {
  int geld = GameBalance.startGeld;
  int levens = GameBalance.startLevens;
  int golfNummer = 0;

  GameStatus status = GameStatus.klaarVoorStart;

  final List<Vijand> vijanden = [];
  final List<Toren> torens = [];
  final List<Projectiel> projectielen = [];

  Golf? _huidigeGolf;
  double _golfTijd = 0;
  double _spawnIndex = 0;

  /// Geselecteerde toren voor plaatsing (uit de HUD) ofInspectie (op veld).
  TorenType? tePlaatsenType;
  Toren? geselecteerdeToren;

  /// Laatste melding voor de UI (bv. "Niet genoeg geld").
  String? toast;

  /// Cel-sizes: het veld is 16 x 9 cellen.
  static const double kolommen = 16;
  static const double rijen = 9;

  bool isPadCel(double cx, double cy) {
    // Een cel is 'pad' als zijn middelpunt binnen 0.75 cel van een padsegment ligt.
    for (var i = 0; i < levelPad.length - 1; i++) {
      final (x1, y1) = levelPad[i];
      final (x2, y2) = levelPad[i + 1];
      final d = _afstandTotSegment(cx, cy, x1, y1, x2, y2);
      if (d < 0.75) return true;
    }
    return false;
  }

  bool kanPlaatsen(double cx, double cy) {
    if (cx < 0.5 || cx > kolommen - 0.5 || cy < 0.5 || cy > rijen - 0.5) return false;
    if (isPadCel(cx, cy)) return false;
    if (tePlaatsenType == null) return false;
    // Niet op een bestaande toren.
    for (final t in torens) {
      if ((t.x - cx).abs() < 0.9 && (t.y - cy).abs() < 0.9) return false;
    }
    return switch (tePlaatsenType!) {
      TorenType.kanon => geld >= GameBalance.kostenKanon,
      TorenType.ijs => geld >= GameBalance.kostenIjs,
      TorenType.sniper => geld >= GameBalance.kostenSniper,
    };
  }

  void plaatsToren(double cx, double cy) {
    if (!kanPlaatsen(cx, cy)) {
      if (tePlaatsenType != null) toast = 'Kan hier niet (bezet / op pad / te duur)';
      return;
    }
    final toren = Toren(tePlaatsenType!, cx, cy);
    geld -= toren.stats.basisKosten;
    torens.add(toren);
    geselecteerdeToren = toren;
    tePlaatsenType = null;
  }

  void upgradeToren(Toren t) {
    if (t.level >= GameBalance.maxTorenLevel) {
      toast = 'Max level';
      return;
    }
    final kosten = t.stats.upgradeKosten(t.level);
    if (geld < kosten) {
      toast = 'Te duur ($kosten)';
      return;
    }
    geld -= kosten;
    t.upgrade();
  }

  void verkoopToren(Toren t) {
    final waarde = t.verkoopWaarde();
    geld += waarde;
    torens.remove(t);
    if (geselecteerdeToren == t) geselecteerdeToren = null;
    toast = '+$waarde';
  }

  void startGolf() {
    if (status != GameStatus.klaarVoorStart && status != GameStatus.tussenGolven) return;
    golfNummer++;
    _huidigeGolf = Golf.bouw(golfNummer);
    _golfTijd = 0;
    _spawnIndex = 0;
    status = GameStatus.golfLoopt;
    toast = null;
  }

  /// De hoofd-tick. dt in seconden.
  void update(double dt) {
    toast = null; // toast is altijd puur één frame leesbaar

    if (status == GameStatus.golfLoopt && _huidigeGolf != null) {
      _golfTijd += dt;

      // Spawns.
      final spawns = _huidigeGolf!.spawns;
      while (_spawnIndex < spawns.length && spawns[_spawnIndex.toInt()].$2 <= _golfTijd) {
        final (type, _) = spawns[_spawnIndex.toInt()];
        final stats = VijandStats.van(type, golfNummer);
        // Kleine variatie in startafstand zodat ze niet precies op één lijn lopen.
        vijanden.add(Vijand(type, stats, -_spawnIndex * 0.15));
        _spawnIndex++;
      }

      // Vijanden lopen.
      final padLengte = padTotaleLengte();
      for (final v in vijanden) {
        v.update(dt);
        if (!v.ontsnapt && v.afstand >= padLengte) {
          v.ontsnapt = true;
          levens -= v.stats.levensVerlies;
        }
      }

      // Torens schieten.
      for (final t in torens) {
        t.vuurCooldown -= dt;
        if (t.vuurCooldown <= 0) {
          final stats = t.stats;
          final doel = _zoekDoel(t);
          if (doel != null) {
            projectielen.add(Projectiel(
              type: t.type,
              doel: doel,
              schade: stats.schade,
              snelheid: stats.projectileSnelheid,
              vertragingPerTref: stats.vertragingPerTref,
              x: t.x,
              y: t.y,
            ));
            t.vuurCooldown = stats.vuurInterval;
          }
        }
      }

      // Projectielen.
      for (final p in projectielen) {
        p.update(dt);
      }

      // Opruimen.
      vijanden.removeWhere((v) {
        if (v.dood) {
          geld += v.stats.geldBijDood;
          return true;
        }
        return v.ontsnapt;
      });
      projectielen.removeWhere((p) => p.weg);

      // Golf klaar?
      if (_spawnIndex >= spawns.length && vijanden.isEmpty) {
        if (golfNummer >= GameBalance.totaalGolven) {
          status = GameStatus.gewonnen;
        } else {
          status = GameStatus.tussenGolven;
          geld += 40 + golfNummer * 5; // golf-bonus
        }
      }

      // Verloren?
      if (levens <= 0) {
        status = GameStatus.verloren;
      }
    }
  }

  /// Zoekt het meest-gevorderde vijand binnen bereik ("first"-strategie).
  Vijand? _zoekDoel(Toren t) {
    final stats = t.stats;
    Vijand? beste;
    for (final v in vijanden) {
      if (v.isDood) continue;
      final (vx, vy) = positieOpPad(v.afstand);
      final dx = vx - t.x;
      final dy = vy - t.y;
      if (math.sqrt(dx * dx + dy * dy) <= stats.bereik) {
        if (beste == null || v.afstand > beste.afstand) beste = v;
      }
    }
    return beste;
  }
}

double _afstandTotSegment(double px, double py, double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) return math.sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1));
  var t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
  t = t.clamp(0.0, 1.0);
  final nx = x1 + dx * t;
  final ny = y1 + dy * t;
  return math.sqrt((px - nx) * (px - nx) + (py - ny) * (py - ny));
}