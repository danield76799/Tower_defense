library;

import 'entities.dart';
export 'entities.dart';
import 'package:flutter/material.dart';

/// Bloon-types, van klein naar groot.
enum BloonType {
  rood(Color(0xFFE53935)),
  blauw(Color(0xFF1E88E5)),
  groen(Color(0xFF43A047)),
  geel(Color(0xFFFDD835)),
  roze(Color(0xFFE91E63)),
  zwart(Color(0xFF212121)),
  wit(Color(0xFFFFFFFF)),
  zebra(Color(0xFFFFFFFF)),
  regenboog(Color(0xFFFFD54F)),
  keramiek(Color(0xFF795548)),
  moab(Color(0xFF37474F)),
  leider(Color(0xFF6D4C41));

  final Color kleur;

  const BloonType(this.kleur);
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
      naam: 'Rood',
      hp: 1,
      snelheid: 0.85,
      geldPerPop: 1,
      levensVerlies: 1,
      kleur: Color(0xFFE53935),
    ),
    BloonType.blauw: BloonStats(
      naam: 'Blauw',
      hp: 1,
      snelheid: 0.95,
      geldPerPop: 2,
      levensVerlies: 1,
      childType: BloonType.rood,
      childAantal: 1,
      kleur: Color(0xFF1E88E5),
    ),
    BloonType.groen: BloonStats(
      naam: 'Groen',
      hp: 1,
      snelheid: 1.05,
      geldPerPop: 3,
      levensVerlies: 1,
      childType: BloonType.blauw,
      childAantal: 1,
      kleur: Color(0xFF43A047),
    ),
    BloonType.geel: BloonStats(
      naam: 'Geel',
      hp: 1,
      snelheid: 1.15,
      geldPerPop: 4,
      levensVerlies: 1,
      childType: BloonType.groen,
      childAantal: 1,
      kleur: Color(0xFFFDD835),
    ),
    BloonType.roze: BloonStats(
      naam: 'Roze',
      hp: 1,
      snelheid: 1.25,
      geldPerPop: 5,
      levensVerlies: 1,
      childType: BloonType.geel,
      childAantal: 1,
      kleur: Color(0xFFE91E63),
    ),
    BloonType.zwart: BloonStats(
      naam: 'Zwart',
      hp: 1,
      snelheid: 1.35,
      geldPerPop: 11,
      levensVerlies: 1,
      childType: BloonType.roze,
      childAantal: 2,
      kleur: Color(0xFF212121),
    ),
    BloonType.wit: BloonStats(
      naam: 'Wit',
      hp: 1,
      snelheid: 1.35,
      geldPerPop: 11,
      levensVerlies: 1,
      childType: BloonType.roze,
      childAantal: 2,
      kleur: Color(0xFFFFFFFF),
    ),
    BloonType.zebra: BloonStats(
      naam: 'Zebra',
      hp: 2,
      snelheid: 1.45,
      geldPerPop: 23,
      levensVerlies: 2,
      childType: BloonType.zwart,
      childAantal: 2,
      kleur: Color(0xFFFFFFFF),
      stijl: BloonStijl.zebra,
    ),
    BloonType.regenboog: BloonStats(
      naam: 'Regenboog',
      hp: 4,
      snelheid: 1.55,
      geldPerPop: 47,
      levensVerlies: 4,
      childType: BloonType.zebra,
      childAantal: 2,
      kleur: Color(0xFFFFD54F),
      stijl: BloonStijl.regenboog,
    ),
    BloonType.keramiek: BloonStats(
      naam: 'Keramiek',
      hp: 10,
      snelheid: 1.65,
      geldPerPop: 95,
      levensVerlies: 10,
      kleur: Color(0xFF795548),
    ),
    BloonType.moab: BloonStats(
      naam: 'MOAB',
      hp: 200,
      snelheid: 1.75,
      geldPerPop: 400,
      levensVerlies: 6,
      kleur: Color(0xFF37474F),
      stijl: BloonStijl.moab,
    ),
    BloonType.leider: BloonStats(
      naam: 'Leider',
      hp: 1000,
      snelheid: 1.85,
      geldPerPop: 2000,
      levensVerlies: 10,
      kleur: Color(0xFF6D4C41),
    ),
  };
}

/// Toren-types: dart, tack, ijs, gif, bom, sniper, bliksem.
enum TorenType {
  dart,
  tack,
  ijs,
  gif,
  bom,
  sniper,
  bliksem,
}

extension TorenTypeSchade on TorenType {
  /// Schade-type: fysiek of magisch.
  SchadeType get schadeType => switch (this) {
        TorenType.dart || TorenType.tack || TorenType.bom || TorenType.sniper => SchadeType.fysiek,
        TorenType.ijs || TorenType.gif || TorenType.bliksem => SchadeType.magisch,
      };
}

enum SchadeType { fysiek, magisch }

/// Toren-statistieken: bereik, schade, snelheid, kosten.
class TorenStats {
  final String naam;
  final double bereik;
  final double schade;
  final double snelheid; // seconden tussen schoten
  final int basisKosten;
  final double? vertragingPerTref;
  final double? splashRadius;
  final SchadeType schadeType;

  const TorenStats({
    required this.naam,
    required this.bereik,
    required this.schade,
    required this.snelheid,
    required this.basisKosten,
    this.vertragingPerTref,
    this.splashRadius,
    required this.schadeType,
  });

  /// Upgrade-kosten voor niveau [n] (1-indexed).
  int upgradeKosten(int n) => (basisKosten * (1.5 + n * 0.2)).round();

  /// Verkoop-prijs voor niveau [n] (1-indexed).
  int verkoopPrijs(int n) => (basisKosten * n * 0.7).round();
}

/// Balans-constanten (afgestemd op 16x9 veld, 20 golven).
class GameBalance {
  static const kostenDart = 100;
  static const kostenTack = 120;
  static const kostenIjs = 140;
  static const kostenGif = 160;
  static const kostenBom = 200;
  static const kostenSniper = 240;
  static const kostenBliksem = 280;

  static const maxTorenLevel = 5;

  static const Map<TorenType, TorenStats> _basisStats = {
    TorenType.dart: TorenStats(
      naam: 'Dart',
      basisKosten: kostenDart,
      bereik: 2.4,
      schade: 1,
      snelheid: 0.8,
      schadeType: SchadeType.fysiek,
    ),
    TorenType.tack: TorenStats(
      naam: 'Tack',
      basisKosten: kostenTack,
      bereik: 1.8,
      schade: 1,
      snelheid: 0.2,
      schadeType: SchadeType.fysiek,
    ),
    TorenType.ijs: TorenStats(
      naam: 'IJs',
      basisKosten: kostenIjs,
      bereik: 2.2,
      schade: 1,
      snelheid: 1.2,
      vertragingPerTref: 0.3,
      schadeType: SchadeType.magisch,
    ),
    TorenType.gif: TorenStats(
      naam: 'Gif',
      basisKosten: kostenGif,
      bereik: 2.0,
      schade: 1,
      snelheid: 1.0,
      schadeType: SchadeType.magisch,
    ),
    TorenType.bom: TorenStats(
      naam: 'Bom',
      basisKosten: kostenBom,
      bereik: 2.6,
      schade: 1,
      snelheid: 1.5,
      splashRadius: 1.2,
      schadeType: SchadeType.fysiek,
    ),
    TorenType.sniper: TorenStats(
      naam: 'Sniper',
      basisKosten: kostenSniper,
      bereik: 9.0,
      schade: 5,
      snelheid: 1.8,
      schadeType: SchadeType.fysiek,
    ),
    TorenType.bliksem: TorenStats(
      naam: 'Bliksem',
      basisKosten: kostenBliksem,
      bereik: 3.0,
      schade: 1,
      snelheid: 0.5,
      schadeType: SchadeType.magisch,
    ),
  };

  static TorenStats van(TorenType type, int level) {
    final basis = _basisStats[type]!;
    return TorenStats(
      naam: basis.naam,
      bereik: basis.bereik + (level - 1) * 0.1,
      schade: basis.schade + (level - 1) * (type == TorenType.sniper ? 2 : 0.5),
      snelheid: math.max(0.1, basis.snelheid - (level - 1) * 0.05),
      basisKosten: basis.basisKosten,
      vertragingPerTref: basis.vertragingPerTref,
      splashRadius: basis.splashRadius,
      schadeType: basis.schadeType,
    );
  }
}

/// Golf-modifiers (YouTD2-geïnspireerd): elke golf kan eigenschappen op zijn
/// bloons zetten, zodat golven verschillen in *karakter* in plaats van alleen
/// "meer HP". Ze zijn deterministisch per golfnummer (geen random), zodat
/// de balans meetbaar en testbaar blijft.
///
/// Balans (gemeten 2026-10-03, test/speler_balans_test.dart): met een
/// realistische economie (geen geld-cheat, torens bijkopen van wat je
/// verdient) winnen alle drie de kaarten met deze modifiers aan — kronkel
/// met 3 levens (spannend), vallei en slang ruim. De effecten zijn bewust
/// bescheiden (35% weerstand, +35% snelheid, +25% HP): het karakter van de
/// golf verandert, de winbaarheid niet.
enum GolfModifier {
  /// Fysieke schade (dart/tack/bom/sniper) doet 35% minder.
  gepantserd,

  /// Magische schade (ijs/gif/bliksem) doet 35% minder.
  magischSchild,

  /// +35% loopsnelheid.
  snel,

  /// +25% HP.
  sterk,

  /// Herstelt 0,5 hp/s tot maximaal zijn start-HP.
  regenererend,

  /// Verdubbelt de geld-opbrengst per pop.
  rijk,
}

extension GolfModifierInfo on GolfModifier {
  String get naam => switch (this) {
        GolfModifier.gepantserd => 'Gepantserd',
        GolfModifier.magischSchild => 'Schild',
        GolfModifier.snel => 'Snel',
        GolfModifier.sterk => 'Sterk',
        GolfModifier.regenererend => 'Regen',
        GolfModifier.rijk => 'Rijk',
      };

  /// Korte uitleg voor in de HUD-tooltip.
  String get uitleg => switch (this) {
        GolfModifier.gepantserd => 'Fysieke schade −35%',
        GolfModifier.magischSchild => 'Magische schade −35%',
        GolfModifier.snel => 'Loopsnelheid +35%',
        GolfModifier.sterk => 'HP +25%',
        GolfModifier.regenererend => 'Herstelt 0,5 hp/s',
        GolfModifier.rijk => 'Dubbele opbrengst',
      };

  /// Kleur van de ring om de bloon (painter).
  Color get kleur => Color(kleurArgb);

  int get kleurArgb => switch (this) {
        GolfModifier.gepantserd => 0xFF9E9E9E,
        GolfModifier.magischSchild => 0xFF9C27B0,
        GolfModifier.snel => 0xFFFFEB3B,
        GolfModifier.sterk => 0xFFFF5722,
        GolfModifier.regenererend => 0xFF4CAF50,
        GolfModifier.rijk => 0xFFFFC107,
      };
}

/// Het golf-schema: welke modifiers horen bij welke golf.
/// Opbouw (20 golven): rustig begin, vanaf golf 5 telkens één nieuw idee,
/// laatste vijf golven combinaties, finale met drie tegelijk.
/// Alles deterministisch per golfnummer (geen random) — testbaar en meetbaar.
List<GolfModifier> modifiersVoorGolf(int golf, int totaalGolven) {
  final m = <GolfModifier>[];
  // Eerste kennismaking per modifier (vroege golven = 1 tegelijk).
  if (golf == 5) m.add(GolfModifier.snel);
  if (golf == 7) m.add(GolfModifier.gepantserd);
  if (golf == 9) m.add(GolfModifier.rijk);
  if (golf == 11) m.add(GolfModifier.regenererend);
  if (golf == 12) m.add(GolfModifier.magischSchild);
  if (golf == 14) m.add(GolfModifier.sterk);

  // Laatste vijf golven: combinaties (eindbaas-opbouw), als fractie van het
  // totaal zodat 20- en 25-golf-kaarten hetzelfde ritme houden.
  final combo1 = (totaalGolven * 0.80).round();
  final combo2 = (totaalGolven * 0.90).round();
  final combo3 = (totaalGolven * 0.95).round();
  final finale = totaalGolven;

  if (golf == combo1) m.addAll([GolfModifier.gepantserd, GolfModifier.snel]);
  if (golf == combo2) m.addAll([GolfModifier.regenererend, GolfModifier.rijk]);
  if (golf == combo3 && combo3 != combo2) {
    m.addAll([GolfModifier.sterk, GolfModifier.magischSchild]);
  }

  // Finale: drie eigenschappen tegelijk — het eindbaas-gevoel.
  if (golf == finale) {
    m.addAll([
      GolfModifier.gepantserd,
      GolfModifier.sterk,
      GolfModifier.snel,
    ]);
  }
  // Dedupliceer (finale kan overlappen met een combinatiegolf).
  return m.toSet().toList();
}
