/// Bloon-lagen (Bloons TD-schema): pop → kind(eren) lopen verder.
/// Het veld is een logisch raster van 16 x 9 cellen (landschap, tablet);
/// alles rekent in cel-coördinaten, de painter schaalt naar schermpixels.
library;

import 'package:flutter/material.dart';

/// Bloon-types, van klein naar groot.
enum BloonType {
  rood,
  blauw,
  groen,
  geel,
  roze,
  zwart,
  zebra,
  regenboog,
  keramiek,
  moab,
}

enum BloonStijl { normaal, zebra, regenboog, moab }

/// Statistieken per bloon-laag.
class BloonStats {
  final String naam;
  final double hp;
  final double snelheid; // cellen per seconde
  final int geldPerPop;
  final int levensVerlies; // als hij de basis bereikt
  final BloonType? childType;
  final int childAantal;
  final Color kleur;
  final BloonStijl stijl;

  const BloonStats({
    required this.naam,
    required this.hp,
    required this.snelheid,
    required this.geldPerPop,
    required this.levensVerlies,
    this.childType,
    this.childAantal = 0,
    required this.kleur,
    this.stijl = BloonStijl.normaal,
  });

  static const Map<BloonType, BloonStats> alle = {
    // Elke laag 1 hp behalve zebra/regenboog/keramiek/MOAB. Kinderen: +1/+2 laag.
    // Snelheden lager dan BTD: ons veld is kleiner (16x9), BTD-paths zijn langer.
    BloonType.rood: BloonStats(
      naam: 'Rood', hp: 1, snelheid: 0.95, geldPerPop: 1, levensVerlies: 1,
      kleur: Color(0xFFE53935),
    ),
    BloonType.blauw: BloonStats(
      naam: 'Blauw', hp: 1, snelheid: 1.1, geldPerPop: 1, levensVerlies: 1,
      childType: BloonType.rood, childAantal: 1, kleur: Color(0xFF1E88E5),
    ),
    BloonType.groen: BloonStats(
      naam: 'Groen', hp: 1, snelheid: 1.25, geldPerPop: 1, levensVerlies: 1,
      childType: BloonType.blauw, childAantal: 1, kleur: Color(0xFF43A047),
    ),
    BloonType.geel: BloonStats(
      naam: 'Geel', hp: 1, snelheid: 1.9, geldPerPop: 1, levensVerlies: 1,
      childType: BloonType.groen, childAantal: 1, kleur: Color(0xFFFDD835),
    ),
    BloonType.roze: BloonStats(
      naam: 'Roze', hp: 1, snelheid: 2.3, geldPerPop: 1, levensVerlies: 1,
      childType: BloonType.geel, childAantal: 1, kleur: Color(0xFFEC407A),
    ),
    BloonType.zwart: BloonStats(
      naam: 'Zwart', hp: 1, snelheid: 1.7, geldPerPop: 2, levensVerlies: 1,
      childType: BloonType.roze, childAantal: 2, kleur: Color(0xFF212121),
    ),
    BloonType.zebra: BloonStats(
      naam: 'Zebra', hp: 2, snelheid: 1.5, geldPerPop: 2, levensVerlies: 1,
      childType: BloonType.zwart, childAantal: 1, kleur: Color(0xFFF5F5F5),
      stijl: BloonStijl.zebra,
    ),
    BloonType.regenboog: BloonStats(
      naam: 'Regenboog', hp: 2, snelheid: 1.7, geldPerPop: 3, levensVerlies: 1,
      childType: BloonType.zebra, childAantal: 1, kleur: Color(0xFFE53935),
      stijl: BloonStijl.regenboog,
    ),
    BloonType.keramiek: BloonStats(
      naam: 'Keramiek', hp: 10, snelheid: 1.9, geldPerPop: 3, levensVerlies: 2,
      childType: BloonType.regenboog, childAantal: 1, kleur: Color(0xFF8D6E63),
    ),
    BloonType.moab: BloonStats(
      naam: 'MOAB', hp: 200, snelheid: 0.45, geldPerPop: 50, levensVerlies: 15,
      childType: BloonType.keramiek, childAantal: 4, kleur: Color(0xFF546E7A),
      stijl: BloonStijl.moab,
    ),
  };

  static BloonStats van(BloonType type) => alle[type]!;
}

class GameBalance {
  // Begin-economie (per kaart via LevelConfig; dit is de fallback).
  static const int startGeld = 650; // Bloons-achtig startbedrag
  static const int startLevens = 40;

  // Torenkosten.
  static const int kostenDart = 100;
  static const int kostenTack = 120;
  static const int kostenIjs = 150;
  static const int kostenGif = 160;
  static const int kostenBom = 180;
  static const int kostenSniper = 200;
  static const int kostenBliksem = 240;
  static const double verkoopFactor = 0.7; // BTD geeft 70-80% terug

  static const int maxTorenLevel = 3;

  // Golven (per kaart via LevelConfig; dit is de fallback).
  static const int totaalGolven = 20;

  // Golf-bonus bij afronding (BTD-gevoel: geld na elke ronde).
  static int golfBonus(int golfNummer) => 30 + golfNummer * 8;
}

/// Toren-types (Bloons-getint).
enum TorenType { dart, tack, ijs, gif, bom, sniper, bliksem }

/// Per-toren statistieken, geschaald per level (1-based).
class TorenStats {
  final String naam;
  final int basisKosten;
  final double bereik; // in cellen
  final double vuurInterval; // seconden tussen schoten
  final double schade; // = aantal lagen per tref (1 hp per kleine laag)
  final double projectileSnelheid; // cellen per seconde

  /// Ijs: vertraging per treffer (s). Gif: 0 → vergif()-pad.
  final double? vertragingPerTref;

  /// Bom: splash-radius (cellen) — raakt ALLE bloons in de cirkel.
  final double? splashRadius;

  /// Tack: aantal spijkers in een cirkel per schot (0 = gericht schot).
  final int spijkers;

  /// Tack: projectiel verdwijnt na deze afstand.
  final double? maxProjectielAfstand;

  final String icoonEmoji;

  const TorenStats({
    required this.naam,
    required this.basisKosten,
    required this.bereik,
    required this.vuurInterval,
    required this.schade,
    required this.projectileSnelheid,
    this.vertragingPerTref,
    this.splashRadius,
    this.spijkers = 0,
    this.maxProjectielAfstand,
    required this.icoonEmoji,
  });

  static TorenStats van(TorenType type, int level) {
    final l = level - 1;
    final basis = _basisStats[type]!;
    var intervalMult = 1.0;
    for (var i = 0; i < l; i++) {
      intervalMult *= 0.85;
    }
    return TorenStats(
      naam: basis.naam,
      basisKosten: basis.basisKosten,
      bereik: basis.bereik * (1 + 0.10 * l),
      vuurInterval: basis.vuurInterval * intervalMult,
      schade: basis.schade * (1 + 0.5 * l),
      projectileSnelheid: basis.projectileSnelheid,
      vertragingPerTref: basis.vertragingPerTref,
      splashRadius: basis.splashRadius,
      spijkers: basis.spijkers,
      maxProjectielAfstand: basis.maxProjectielAfstand,
      icoonEmoji: basis.icoonEmoji,
    );
  }

  int upgradeKosten(int huidigLevel) =>
      (basisKosten * (huidigLevel + 1) * 0.8).round();

  static const Map<TorenType, TorenStats> _basisStats = {
    TorenType.dart: TorenStats(
      naam: 'Dart',
      basisKosten: GameBalance.kostenDart,
      bereik: 2.4,
      vuurInterval: 0.65,
      schade: 3, // doorslaat 3 lagen per dart (BTD-nerfje voor golf-10+)
      projectileSnelheid: 12,
      icoonEmoji: '🏹',
    ),
    TorenType.tack: TorenStats(
      naam: 'Tack',
      basisKosten: GameBalance.kostenTack,
      bereik: 1.9,
      vuurInterval: 0.85,
      schade: 1,
      projectileSnelheid: 10,
      spijkers: 8,
      maxProjectielAfstand: 2.0,
      icoonEmoji: '🎇',
    ),
    TorenType.ijs: TorenStats(
      naam: 'Ijs',
      basisKosten: GameBalance.kostenIjs,
      bereik: 2.4,
      vuurInterval: 1.3,
      schade: 1,
      projectileSnelheid: 9,
      vertragingPerTref: 2.0,
      icoonEmoji: '❄️',
    ),
    TorenType.gif: TorenStats(
      naam: 'Gif',
      basisKosten: GameBalance.kostenGif,
      bereik: 2.8,
      vuurInterval: 1.1,
      schade: 1,
      projectileSnelheid: 7,
      vertragingPerTref: 0,
      icoonEmoji: '🧪',
    ),
    TorenType.bom: TorenStats(
      naam: 'Bom',
      basisKosten: GameBalance.kostenBom,
      bereik: 2.6,
      vuurInterval: 1.2,
      schade: 3,
      projectileSnelheid: 8,
      splashRadius: 1.4,
      icoonEmoji: '💣',
    ),
    TorenType.sniper: TorenStats(
      naam: 'Sniper',
      basisKosten: GameBalance.kostenSniper,
      bereik: 5.5,
      vuurInterval: 1.0,
      schade: 12, // doorslaat ~12 lagen
      projectileSnelheid: 30,
      icoonEmoji: '🎯',
    ),
    TorenType.bliksem: TorenStats(
      naam: 'Bliksem',
      basisKosten: GameBalance.kostenBliksem,
      bereik: 3.2,
      vuurInterval: 1.1,
      schade: 4,
      projectileSnelheid: 30,
      icoonEmoji: '⚡',
    ),
  };
}