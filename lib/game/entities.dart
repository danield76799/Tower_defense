import 'dart:math' as math;

import 'game_config.dart';

/// Een vijand die over het pad loopt.
class Vijand {
  final VijandType type;
  final VijandStats stats;

  double _afstand; // afgelegde afstand langs het pad (in cellen)
  double hp;
  double vertragingTijd = 0; // ijs-effect: x seconden op halve snelheid
  double gifTijd = 0; // gif-effect: x seconden 8 HP/s extra schade
  double fase = 0; // loop-animatiefase (hop-beweging in de painter)
  bool dood = false;
  bool ontsnapt = false;

  Vijand(this.type, this.stats, double startAfstand)
      : _afstand = startAfstand,
        hp = stats.hp.toDouble();

  double get afstand => _afstand;
  double get hpMax => stats.hp.toDouble();
  bool get isDood => dood || ontsnapt;

  void schade(double bedrag) {
    if (dood || ontsnapt) return;
    hp -= bedrag;
    if (hp <= 0) dood = true;
  }

  void vertrag(double seconden) {
    if (dood || ontsnapt) return;
    vertragingTijd = math.max(vertragingTijd, seconden);
  }

  void vergif(double seconden) {
    if (dood || ontsnapt) return;
    gifTijd = math.max(gifTijd, seconden);
  }

  void update(double dt) {
    if (dood || ontsnapt) return;
    final factor = vertragingTijd > 0 ? 0.45 : 1.0;
    if (vertragingTijd > 0) vertragingTijd -= dt;
    _afstand += stats.snelheid * factor * dt;
    fase += dt * 9 * factor; // sneller lopen = sneller huppelen

    // Gif-ticks: 8 HP/s while vergiftigd.
    if (gifTijd > 0) {
      gifTijd -= dt;
      hp -= dt * 8;
      if (hp <= 0) dood = true;
    }
  }
}

/// Positie op een pad op een gegeven afstand (in cellen).
/// Berekend door het pad in segmenten te lopen.
(double, double) positieOpPad(List<(double, double)> pad, double afstand) {
  var rest = afstand;
  for (var i = 0; i < pad.length - 1; i++) {
    final (x1, y1) = pad[i];
    final (x2, y2) = pad[i + 1];
    final segmentLengte = _segment(x1, y1, x2, y2);
    if (rest <= segmentLengte || i == pad.length - 2) {
      final t = (segmentLengte <= 0) ? 0.0 : (rest / segmentLengte).clamp(0.0, 1.0);
      return (x1 + (x2 - x1) * t, y1 + (y2 - y1) * t);
    }
    rest -= segmentLengte;
  }
  return pad.last;
}

double padTotaleLengte(List<(double, double)> pad) {
  var totaal = 0.0;
  for (var i = 0; i < pad.length - 1; i++) {
    final (x1, y1) = pad[i];
    final (x2, y2) = pad[i + 1];
    totaal += _segment(x1, y1, x2, y2);
  }
  return totaal;
}

double _segment(double x1, double y1, double x2, double y2) {
  final dx = x2 - x1;
  final dy = y2 - y1;
  return math.sqrt(dx * dx + dy * dy);
}

/// Een toren op het veld.
class Toren {
  final TorenType type;
  final double x;
  final double y;

  int level = 1;
  double vuurCooldown = 0;
  int totaalGeinvesteerd;

  /// Loop-richting (radialen) naar het laatstbeschoten doel — voor een
  /// draaiend kanonloopje in de painter. Start omlaag-rechts.
  double loopRichting = 0.8;

  /// Knipoog-effect bij schot (0..1, dooft uit).
  double schietFlits = 0;

  /// Vriendje-animatietijd (draaiende decoraties e.d.).
  double animTijd = 0;

  void voorLoop(double dt) {
    animTijd += dt;
    if (schietFlits > 0) schietFlits = schietFlits; // dooft uit in game_state
  }

  Toren(this.type, this.x, this.y)
      : totaalGeinvesteerd = TorenStats.van(type, 1).basisKosten;

  TorenStats get stats => TorenStats.van(type, level);

  void upgrade() {
    if (level >= GameBalance.maxTorenLevel) return;
    totaalGeinvesteerd += stats.upgradeKosten(level);
    level++;
  }

  int verkoopWaarde() => (totaalGeinvesteerd * GameBalance.verkoopFactor).round();
}

/// Een projectiel onderweg naar zijn doel.
class Projectiel {
  final TorenType type;
  final Vijand doel;
  final double schade;
  final double snelheid;
  final double? vertragingPerTref;
  final List<(double, double)> pad; // pad van de actieve kaart
  double x;
  double y;
  bool weg = false;

  /// Vorige positie — voor een streepje/sliert tekenen.
  double vorigeX;
  double vorigeY;

  Projectiel({
    required this.type,
    required this.doel,
    required this.schade,
    required this.snelheid,
    required this.vertragingPerTref,
    required this.pad,
    required this.x,
    required this.y,
  })  : vorigeX = x,
        vorigeY = y;

  void update(double dt) {
    if (weg || doel.isDood) {
      weg = true;
      return;
    }
    final (tx, ty) = positieOpPad(pad, doel.afstand);
    final dx = tx - x;
    final dy = ty - y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 0.15) {
      // Tref!
      doel.schade(schade);
      if (vertragingPerTref != null && vertragingPerTref! > 0) {
        doel.vertrag(vertragingPerTref!);
      }
      // Gif-projectiel vergiftigt (8s) i.p.v. vertragen — herkenbaar aan type.
      if (type == TorenType.gif) {
        doel.vergif(4.0);
      }
      weg = true;
      return;
    }
    final stap = snelheid * dt;
    vorigeX = x;
    vorigeY = y;
    x += dx / d * stap;
    y += dy / d * stap;
  }
}

/// Golfsamenstelling: welke vijanden, welke types, bij welk getal.
class Golf {
  final int nummer;
  final List<(VijandType, double)> spawns; // (type, spawn-tijd offset in s)

  Golf(this.nummer, this.spawns);

  /// Genereert een golf volgens een oplopende curve.
  /// Elke 5e golf bevat tanks; vanaf golf 6 lopen snelle vijanden mee.
  /// Elke 10e golf (en de laatste) eindigt met een boss.
  static Golf bouw(int nummer, {int totaalGolven = GameBalance.totaalGolven}) {
    final spawns = <(VijandType, double)>[];
    var t = 0.0;
    const interval = 1.1;

    var aantalNormaal = 6 + (nummer * 1.5).floor();
    var aantalSnel = nummer >= 3 ? (nummer / 3).floor() : 0;
    var aantalTank = nummer >= 5 ? (nummer / 5).floor() : 0;

    // Cap zodat het niet explodeert.
    aantalNormaal = math.min(aantalNormaal, 24);
    aantalSnel = math.min(aantalSnel, 10);
    aantalTank = math.min(aantalTank, 5);

    for (var i = 0; i < aantalNormaal; i++) {
      spawns.add((VijandType.normaal, t));
      t += interval;
    }
    for (var i = 0; i < aantalSnel; i++) {
      spawns.add((VijandType.snel, t));
      t += interval * 0.7;
    }
    for (var i = 0; i < aantalTank; i++) {
      spawns.add((VijandType.tank, t));
      t += interval * 1.3;
    }

    // Boss op golf 10, 20, en de laatste golf.
    if (nummer % 10 == 0 || nummer == totaalGolven) {
      spawns.add((VijandType.boss, t + 2.0));
    }

    return Golf(nummer, spawns);
  }

  double get totaleDuur => spawns.isEmpty ? 0 : spawns.last.$2 + 2.0;
}