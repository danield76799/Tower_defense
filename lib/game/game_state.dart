import 'dart:math' as math;

import 'entities.dart';
import 'game_config.dart';
import 'levels.dart';

/// Game-status.
enum GameStatus { klaarVoorStart, golfLoopt, tussenGolven, gewonnen, verloren }

/// De volledige game-state en -logica. Puur Dart (geen Flutter), unit-testable.
class GameState {
  LevelConfig level;

  int geld;
  int levens;

  /// Totaal aantal gepopte lagen (score-basis, BTD-achtig).
  int poptsTotaal = 0;

  int golfNummer = 0;
  GameStatus status = GameStatus.klaarVoorStart;

  final List<Vijand> vijanden = [];
  final List<Toren> torens = [];
  final List<Projectiel> projectielen = [];

  Golf? _huidigeGolf;
  double _golfTijd = 0;
  int _spawnIndex = 0;

  TorenType? tePlaatsenType;
  Toren? geselecteerdeToren;

  String? toast;

  GameState({LevelConfig? levelConfig})
      : level = levelConfig ?? levelGroeneVallei,
        geld = (levelConfig ?? levelGroeneVallei).startGeld,
        levens = (levelConfig ?? levelGroeneVallei).startLevens;

  static const double kolommen = 16;
  static const double rijen = 9;

  List<(double, double)> get pad => level.pad;

  bool isPadCel(double cx, double cy) {
    final p = pad;
    for (var i = 0; i < p.length - 1; i++) {
      final (x1, y1) = p[i];
      final (x2, y2) = p[i + 1];
      if (_afstandTotSegment(cx, cy, x1, y1, x2, y2) < 0.75) return true;
    }
    return false;
  }

  bool kanPlaatsen(double cx, double cy) {
    if (cx < 0.5 || cx > kolommen - 0.5 || cy < 0.5 || cy > rijen - 0.5) return false;
    if (isPadCel(cx, cy)) return false;
    if (tePlaatsenType == null) return false;
    for (final t in torens) {
      if ((t.x - cx).abs() < 0.9 && (t.y - cy).abs() < 0.9) return false;
    }
    return geld >= TorenStats.van(tePlaatsenType!, 1).basisKosten;
  }

  void plaatsToren(double cx, double cy) {
    final type = tePlaatsenType;
    if (type == null) return;
    if (!kanPlaatsen(cx, cy)) {
      toast = geld < TorenStats.van(type, 1).basisKosten
          ? 'Te duur!'
          : 'Kan hier niet';
      return;
    }
    final toren = Toren(type, cx, cy);
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
    _huidigeGolf = Golf.bouw(
      golfNummer,
      totaalGolven: level.totaalGolven,
      moabHpMult: Golf.moabHpMultiplier(golfNummer, level.totaalGolven),
    );
    _golfTijd = 0;
    _spawnIndex = 0;
    status = GameStatus.golfLoopt;
    toast = null;
  }

  /// De hoofd-tick. dt in seconden.
  void update(double dt) {
    toast = null;

    if (status != GameStatus.golfLoopt || _huidigeGolf == null) return;
    _golfTijd += dt;

    // Spawns.
    final spawns = _huidigeGolf!.spawns;
    while (_spawnIndex < spawns.length && spawns[_spawnIndex].$2 <= _golfTijd) {
      final (type, _) = spawns[_spawnIndex];
      final stats0 = BloonStats.van(type);
      var hp = stats0.hp;
      if (type == BloonType.moab) {
        hp = stats0.hp * _huidigeGolf!.moabHpMult;
      }
      final v = Vijand(type, stats0, 0.0);
      v.hp = hp;
      vijanden.add(v);
      _spawnIndex++;
    }

    // Bloons lopen.
    final padLengte = padTotaleLengte(pad);
    for (final v in vijanden) {
      v.update(dt);
      if (!v.ontsnapt && v.afstand >= padLengte) {
        v.ontsnapt = true;
        levens -= v.stats.levensVerlies;
      }
    }

    // Torens schieten.
    // Per-frame claim-set: torens verdelen de schoten over ónderschillende
    // bloons, MAAR alleen als één schot het bloon ook echt popt. Zware
    // bloons (zebra+ / MOAB) blijven claimbaar zodat meerdere torens er op
    // stapelen — anders lopen MOAB's ongehinderd door (BTD: focus fire op
    // dik vee, verspreid vuur op klein gedierte).
    final geclaimd = <Vijand>{};
    for (final t in torens) {
      if (t.schietFlits > 0) t.schietFlits -= dt * 4;
      t.animTijd += dt;
      t.vuurCooldown -= dt;
      if (t.vuurCooldown <= 0) {
        final stats = t.stats;
        if (stats.spijkers > 0) {
          // Tack: N spijkers in een cirkel, doel-loos.
          for (var i = 0; i < stats.spijkers; i++) {
            final hoek = i * 2 * math.pi / stats.spijkers + t.animTijd * 0.3;
            projectielen
                .add(_bouwProjectiel(t, stats, richting: hoek, doel: null));
          }
          t.schietFlits = 1;
          t.vuurCooldown = stats.vuurInterval;
        } else {
          final doel = _zoekDoel(t, geclaimd);
          if (doel != null) {
            // Claim dit bloon voor dit frame: alle torens verspreiden over
            // verschillende bloons. (Zelfs zwaar vee: focus-fire regelen we
            // via doel-selectie, niet via de claim — anders loopt de rest
            // van de golf erdoorheen.)
            geclaimd.add(doel);
            final (vx, vy) = positieOpPad(pad, doel.afstand);
            t.loopRichting = math.atan2(vy - t.y, vx - t.x);
            t.schietFlits = 1;
            projectielen.add(_bouwProjectiel(t, stats, richting: 0, doel: doel));
            t.vuurCooldown = stats.vuurInterval;
          }
        }
      }
    }

    // Projectielen: update + botsingen (tack + pierce-voortzetting).
    for (final p in projectielen) {
      p.update(dt);
      if (p.weg || p.splashRadius != null) continue;
      // Doel-loze projectielen (tack-spijkers, gepierced darts): bots-check
      // tegen elk bloon in een 0.3-cel-radius onderweg.
      for (final v in vijanden) {
        if (v.isDood || p.weg) continue;
        if (p.geraakt.contains(v)) continue;
        final (vx, vy) = positieOpPad(pad, v.afstand);
        final dx = vx - p.x;
        final dy = vy - p.y;
        if (math.sqrt(dx * dx + dy * dy) < 0.3) {
          p.raakBloon(v);
          if (p.pierce > 0) {
            // Doorvliegen (richting ongewijzigd).
            continue;
          }
          p.weg = true;
          break;
        }
      }
    }

    // Popts + opruimen: dood bloon → geld + kinderen; ontsnapte → weg.
    final nieuweVijanden = <Vijand>[];
    vijanden.removeWhere((v) {
      if (v.ontsnapt) return true;
      if (!v.dood) return false;
      geld += v.stats.geldPerPop;
      poptsTotaal++;
      final childType = v.stats.childType;
      if (childType == null) return true;
      for (var i = 0; i < v.stats.childAantal; i++) {
        nieuweVijanden
            .add(Vijand(childType, BloonStats.van(childType), v.afstand - i * 0.18));
      }
      return true;
    });
    vijanden.addAll(nieuweVijanden);
    projectielen.removeWhere((p) => p.weg);

    // Golf klaar?
    if (_spawnIndex >= spawns.length && vijanden.isEmpty) {
      if (golfNummer >= level.totaalGolven) {
        status = GameStatus.gewonnen;
      } else {
        status = GameStatus.tussenGolven;
        geld += GameBalance.golfBonus(golfNummer);
      }
    }

    if (levens <= 0) {
      status = GameStatus.verloren;
    }
  }

  Projectiel _bouwProjectiel(
    Toren t,
    TorenStats stats, {
    required double richting,
    required Vijand? doel,
  }) {
    // BTD-pierce: dart 2 (BTD6-basis), spijkers 1, sniper 6, bom = splash,
    // bliksem 2, ijs 1, gif 2 (gif-wolk doortrek).
    final pierce = switch (t.type) {
      TorenType.dart => 2,
      TorenType.tack => 1,
      TorenType.sniper => 6,
      TorenType.bliksem => 2,
      TorenType.gif => 2,
      _ => 1,
    };
    final p = Projectiel(
      type: t.type,
      doel: doel,
      schade: stats.schade,
      snelheid: stats.projectileSnelheid,
      vertragingPerTref: stats.vertragingPerTref,
      splashRadius: stats.splashRadius,
      maxAfstand: stats.maxProjectielAfstand,
      richting: richting,
      pierce: pierce,
      pad: pad,
      x: t.x,
      y: t.y,
    );
    p.splashCallback = _doeSplash;
    return p;
  }

  /// Splash: alle bloons binnen straal van (x,y) nemen schade.
  void _doeSplash(double x, double y, double radius, double schade) {
    for (final v in vijanden) {
      if (v.dood || v.ontsnapt) continue;
      final (vx, vy) = positieOpPad(pad, v.afstand);
      final dx = vx - x;
      final dy = vy - y;
      if (math.sqrt(dx * dx + dy * dy) <= radius) {
        v.schade(schade);
      }
    }
  }

  /// Zoekt een doel binnen bereik. Bloon in [geclaimd] zijn al bezet door
  /// een andere toren dit frame (overkill-voorkoming); er wordt op de eerst
  /// nog-vrije doel gericht.
  /// Hybrid-strategie: sniper/bom/bliksem richten bij voorkeur op zwaar
  /// gewicht (keramiek/MOAB, hp >= 3) als dat in bereik is, anders "first".
  Vijand? _zoekDoel(Toren t, Set<Vijand> geclaimd) {
    final stats = t.stats;
    final magStrong = t.type == TorenType.sniper ||
        t.type == TorenType.bom ||
        t.type == TorenType.bliksem;
    Vijand? beste;
    Vijand? sterkste;
    for (final v in vijanden) {
      if (v.isDood) continue;
      final (vx, vy) = positieOpPad(pad, v.afstand);
      final dx = vx - t.x;
      final dy = vy - t.y;
      if (math.sqrt(dx * dx + dy * dy) > stats.bereik) continue;
      if (geclaimd.contains(v)) continue;
      if (beste == null || v.afstand > beste.afstand) beste = v;
      if (magStrong &&
          (sterkste == null || v.hpMax > sterkste.hpMax ||
              (v.hpMax == sterkste.hpMax && v.afstand > sterkste.afstand))) {
        sterkste = v;
      }
    }
    // Zwaar gewicht aanwezig? Dan daarop richten.
    if (magStrong && sterkste != null && sterkste.hpMax >= 3) return sterkste;
    return beste;
  }
}

double _afstandTotSegment(
    double px, double py, double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  final lenSq = dx * dx + dy * dy;
  if (lenSq == 0) {
    return math.sqrt((px - x1) * (px - x1) + (py - y1) * (py - y1));
  }
  var t = ((px - x1) * dx + (py - y1) * dy) / lenSq;
  t = t.clamp(0.0, 1.0);
  final nx = x1 + dx * t;
  final ny = y1 + dy * t;
  return math.sqrt((px - nx) * (px - nx) + (py - ny) * (py - ny));
}