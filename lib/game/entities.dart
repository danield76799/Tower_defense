import 'dart:math' as math;

import 'game_config.dart';

/// Een bloon op het pad (Bloons TD-schema: lagen met kinderen).
class Vijand {
  final BloonType type;
  final BloonStats stats;

  double _afstand; // afgelegde afstand langs het pad (in cellen)
  double hp;
  double vertragingTijd = 0; // ijs-effect
  double gifTijd = 0; // gif-effect: 8 hp/s extra
  double fase = 0; // animatiefase
  bool dood = false;
  bool ontsnapt = false;

  Vijand(this.type, this.stats, double startAfstand)
      : _afstand = startAfstand,
        hp = stats.hp;

  double get afstand => _afstand;
  double get hpMax => stats.hp;
  bool get isDood => dood || ontsnapt;

  /// Restant-schade na het popt van deze laag (doordringing in kinderen).
  double neemSchade(double bedrag) {
    if (dood || ontsnapt) return bedrag;
    final restSchade = bedrag - hp;
    hp -= bedrag;
    if (hp <= 0) {
      dood = true;
      return math.max(0.0, restSchade); // doorslag in kinderen
    }
    return 0;
  }

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
    fase += dt * 9 * factor;

    if (gifTijd > 0) {
      gifTijd -= dt;
      hp -= dt * 8;
      if (hp <= 0) dood = true;
    }
  }
}

/// Positie op een pad op gegeven afstand (in cellen).
(double, double) positieOpPad(List<(double, double)> pad, double afstand) {
  var rest = afstand;
  for (var i = 0; i < pad.length - 1; i++) {
    final (x1, y1) = pad[i];
    final (x2, y2) = pad[i + 1];
    final segmentLengte = _segment(x1, y1, x2, y2);
    if (rest <= segmentLengte || i == pad.length - 2) {
      final t =
          (segmentLengte <= 0) ? 0.0 : (rest / segmentLengte).clamp(0.0, 1.0);
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

  /// Loop-richting (radialen) naar laatst beschoten doel.
  double loopRichting = 0.8;

  /// Knipoog-effect bij schot (0..1, dooft uit).
  double schietFlits = 0;

  /// Animatietijd (vonken e.d.).
  double animTijd = 0;

  Toren(this.type, this.x, this.y)
      : totaalGeinvesteerd = TorenStats.van(type, 1).basisKosten;

  TorenStats get stats => TorenStats.van(type, level);

  void upgrade() {
    if (level >= GameBalance.maxTorenLevel) return;
    totaalGeinvesteerd += stats.upgradeKosten(level);
    level++;
  }

  int verkoopWaarde() =>
      (totaalGeinvesteerd * GameBalance.verkoopFactor).round();
}

/// Een projectiel.
/// - Gericht (doel != null): volgt doel tot tref of dood-doel; met pierce
///   vliegt hij dóór (BTD) en wordt doel-loos met de laatst bekende richting.
/// - Doel-loos (tack-spijker / gepierced darts): vliegt rechtdoor;
///   state checkt de botsingen; verdwijnt na maxAfstand.
class Projectiel {
  final TorenType type;
  Vijand? doel; // wordt null na dood-doel met pierce-over
  final double schade;
  final double snelheid;
  final double? vertragingPerTref;
  final double? splashRadius;
  final List<(double, double)> pad;
  double richting; // bijgesteld bij doel-volgen (voor pierce-voortzetting)
  final double? maxAfstand; // tack: levensduur in cellen

  /// Aantal extra bloons dat dit projectiel na zijn eerste raak nog mag raken.
  int pierce;

  /// Bloons die al door dit projectiel geraakt zijn (geen dubbele raak).
  final Set<Vijand> geraakt = {};

  double x;
  double y;
  double vorigeX;
  double vorigeY;
  double _gevlogen = 0;
  bool weg = false;

  Projectiel({
    required this.type,
    required this.doel,
    required this.schade,
    required this.snelheid,
    required this.vertragingPerTref,
    required this.pad,
    this.splashRadius,
    this.maxAfstand,
    this.richting = 0,
    this.pierce = 0,
    required this.x,
    required this.y,
  })  : vorigeX = x,
        vorigeY = y;

  void update(double dt) {
    if (weg) return;

    final d = doel;
    if (d != null) {
      if (d.isDood) {
        if (pierce > 0) {
          doel = null; // rechtdoor verder (pierce)
        } else {
          weg = true;
          return;
        }
      }
      if (doel != null) {
        final (tx, ty) = positieOpPad(pad, doel!.afstand);
        final dx = tx - x;
        final dy = ty - y;
        final dist = math.sqrt(dx * dx + dy * dy);
        richting = math.atan2(dy, dx); // onthoud richting voor pierce
        if (dist < 0.15) {
          weg = true;
          _raak(directDoel: doel!, trefX: tx, trefY: ty);
          return;
        }
        final stap = snelheid * dt;
        vorigeX = x;
        vorigeY = y;
        x += dx / dist * stap;
        y += dy / dist * stap;
        _gevlogen += stap;
        return;
      }
    }

    // Doel-loos (tack/pierce-voortzetting): rechtdoor.
    final stap = snelheid * dt;
    vorigeX = x;
    vorigeY = y;
    x += math.cos(richting) * stap;
    y += math.sin(richting) * stap;
    _gevlogen += stap;
    if (maxAfstand != null && _gevlogen >= maxAfstand!) {
      weg = true;
    }
  }

  /// Raak een bloon: schade + effect. Geen dubbele raak op zelfde bloon.
  void raakBloon(Vijand v) {
    if (geraakt.contains(v)) return;
    geraakt.add(v);
    v.schade(schade);
    if (vertragingPerTref != null && vertragingPerTref! > 0) {
      v.vertrag(vertragingPerTref!);
    }
    if (type == TorenType.gif) v.vergif(4.0);
    if (splashRadius != null) {
      // Bom ontploft bij eerste raak: splash op deze plek, einde projectiel.
      splashCallback?.call(x, y, splashRadius!, schade);
      weg = true;
      return;
    }
    if (pierce > 0) pierce--;
  }

  void _raak({
    required Vijand directDoel,
    required double trefX,
    required double trefY,
  }) {
    if (splashRadius == null) {
      raakBloon(directDoel);
      // Met pierce over: wordt doel-loos, vliegt rechtdoor verder.
      // Update() doet dit vanzelf bij volgende tik (doel null).
      if (pierce > 0) {
        weg = false;
        doel = null;
      }
      return;
    }
    splashCallback?.call(trefX, trefY, splashRadius!, schade);
    weg = true;
  }

  void Function(double x, double y, double radius, double schade)?
      splashCallback;
}

/// Golfsamenstelling: welke bloons, wanneer gespawned.
class Golf {
  final int nummer;
  final List<(BloonType, double)> spawns; // (type, offset in s)

  /// MOAB-HP-multiplier voor deze golf (intro-MOAB zachter).
  final double moabHpMult;

  Golf(this.nummer, this.spawns, {double? moabHpMult})
      : moabHpMult = moabHpMult ?? moabHpMultiplier(nummer, nummer);

  /// MOAB-HP-multiplier per golf: introductie-MOAB (golf 10) is zacht
  /// (0.35×), golf 15 middenmoab (0.55×), finale full HP.
  static double moabHpMultiplier(int golf, int totaalGolven) {
    if (golf == totaalGolven) return 1.0;
    if (golf >= 15) return 0.55;
    return 0.35;
  }

  /// BTD-achtige curve: steeds hogere lagen, vanaf golf 10 MOAB-waarschuwing.
  static Golf bouw(
    int nummer, {
    int totaalGolven = GameBalance.totaalGolven,
    double? moabHpMult,
  }) {
    final spawns = <(BloonType, double)>[];
    var t = 0.0;
    const interval = 0.55; // BTD: veel bloons op korte tussenruimte

    BloonType laagVoor(int golf) {
      if (golf <= 2) return BloonType.rood;
      if (golf <= 4) return BloonType.blauw;
      if (golf <= 6) return BloonType.groen;
      if (golf <= 8) return BloonType.geel;
      if (golf <= 10) return BloonType.roze;
      if (golf <= 12) return BloonType.zwart;
      if (golf <= 14) return BloonType.zebra;
      if (golf <= 16) return BloonType.regenboog;
      return BloonType.keramiek;
    }

    final hoofdLaag = laagVoor(nummer);
    final aantal = (12 + nummer * 2).clamp(0, 60);
    for (var i = 0; i < aantal; i++) {
      spawns.add((hoofdLaag, t));
      t += interval;
    }

    // Mix in één laag lager vanaf golf 3 (gelaagde groepen).
    if (nummer >= 3) {
      final subLaag = laagVoor(math.max(1, nummer - 2));
      for (var i = 0; i < nummer.clamp(0, 20); i++) {
        spawns.add((subLaag, t));
        t += interval * 0.6;
      }
    }

    // MOAB op golf 10 (introductie), 15 (keer), finale (2 stuks).
    final finale = nummer == totaalGolven;
    if (nummer == 10 || nummer == 15 || finale) {
      spawns.add((BloonType.moab, t + 1.5));
    }
    if (finale && nummer >= 20) {
      spawns.add((BloonType.moab, t + 4.0));
    }

    return Golf(nummer, spawns, moabHpMult: moabHpMult);
  }

  double get totaleDuur => spawns.isEmpty ? 0 : spawns.last.$2 + 2.0;
}