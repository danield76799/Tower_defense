/// Game-constanten en het level-pad.
///
/// Het veld is een logisch raster van 16 x 9 cellen (landschap, tablet).
/// Alles (pad, torens, bereik) rekent in cel-coördinaten; de painter schaalt
/// naar schermpixels. Zo werkt de game op elke tablet-grootte identiek.
library;

class GameBalance {
  // Begin-economie (per kaart via LevelConfig, dit is de fallback).
  static const int startGeld = 200;
  static const int startLevens = 20;

  // Torenkosten (basis) en verkooppercentage.
  static const int kostenKanon = 80;
  static const int kostenIjs = 120;
  static const int kostenSniper = 160;
  static const int kostenBliksem = 220;
  static const int kostenGif = 140;
  static const double verkoopFactor = 0.6; // 60% van geïnvesteerde terug

  // Upgrade-mults per level (level 1..3). Kosten = basis * level.
  static const int maxTorenLevel = 3;

  // Golven (per kaart via LevelConfig, dit is de fallback).
  static const int totaalGolven = 20;

  // Levensverlies per doorgestane vijand.
  static const int levensVerliesNormaal = 1;
  static const int levensVerliesTank = 2;
  static const int levensVerliesBoss = 5;
}

/// Wegen door het raster in cel-middelpunten (x + 0.5, y + 0.5).
/// S-vorm: van links naar rechts, met twee bochten.
const List<(double, double)> levelPad = [
  (-1.0, 4.0), // spawn net buiten beeld
  (2.0, 4.0),
  (2.0, 1.5),
  (6.0, 1.5),
  (6.0, 7.5),
  (9.5, 7.5),
  (9.5, 4.0),
  (13.0, 4.0),
  (13.0, 1.5),
  (17.0, 1.5), // exit net buiten beeld
];

/// Vijand-types.
enum VijandType { normaal, snel, tank, boss }

/// Toren-types.
enum TorenType { kanon, ijs, sniper, bliksem, gif }

/// Per-toren statische statistieken, geschaald per level (1-based).
class TorenStats {
  final String naam;
  final int basisKosten;
  final double bereik; // in cellen
  final double vuurInterval; // seconden tussen schoten
  final double schade;
  final double projectileSnelheid; // cellen per seconde
  final double? vertragingPerTref; // ijs: seconden traager
  final String icoonEmoji;

  const TorenStats({
    required this.naam,
    required this.basisKosten,
    required this.bereik,
    required this.vuurInterval,
    required this.schade,
    required this.projectileSnelheid,
    this.vertragingPerTref,
    required this.icoonEmoji,
  });

  static TorenStats van(TorenType type, int level) {
    // Level-schaal: bereik +10%, schade +40% per extra level,
    // vuurinterval -12% per extra level.
    final l = level - 1;
    const stats = _basisStats;
    final basis = stats[type]!;
    return TorenStats(
      naam: basis.naam,
      basisKosten: basis.basisKosten,
      bereik: basis.bereik * (1 + 0.10 * l),
      vuurInterval: basis.vuurInterval * _intervalMult(l),
      schade: basis.schade * (1 + 0.40 * l),
      projectileSnelheid: basis.projectileSnelheid,
      vertragingPerTref: basis.vertragingPerTref,
      icoonEmoji: basis.icoonEmoji,
    );
  }

  static double _intervalMult(int l) {
    var m = 1.0;
    for (var i = 0; i < l; i++) {
      m *= 0.88;
    }
    return m;
  }

    static const Map<TorenType, TorenStats> _basisStats = {
    TorenType.kanon: TorenStats(
      naam: 'Kanon',
      basisKosten: GameBalance.kostenKanon,
      bereik: 2.6,
      vuurInterval: 0.9,
      schade: 12,
      projectileSnelheid: 9,
      icoonEmoji: '💥',
    ),
    TorenType.ijs: TorenStats(
      naam: 'Ijs',
      basisKosten: GameBalance.kostenIjs,
      bereik: 2.2,
      vuurInterval: 1.1,
      schade: 4,
      projectileSnelheid: 8,
      vertragingPerTref: 1.2,
      icoonEmoji: '❄️',
    ),
    TorenType.sniper: TorenStats(
      naam: 'Sniper',
      basisKosten: GameBalance.kostenSniper,
      bereik: 4.5,
      vuurInterval: 2.2,
      schade: 40,
      projectileSnelheid: 18,
      icoonEmoji: '🎯',
    ),
    TorenType.bliksem: TorenStats(
      naam: 'Bliksem',
      basisKosten: GameBalance.kostenBliksem,
      bereik: 3.2,
      vuurInterval: 1.5,
      schade: 22,
      projectileSnelheid: 30, // bliksem = vrijwel instant
      icoonEmoji: '⚡',
    ),
    TorenType.gif: TorenStats(
      naam: 'Gif',
      basisKosten: GameBalance.kostenGif,
      bereik: 2.8,
      vuurInterval: 1.3,
      schade: 6, // + gif-ticks via vertragingMechanica
      projectileSnelheid: 7,
      vertragingPerTref: 0, // geen ijs-vertraging; gif-werkt via VergifStatus
      icoonEmoji: '🧪',
    ),
  };

  int upgradeKosten(int huidigLevel) => (basisKosten * (huidigLevel + 1) * 0.8).round();
}

/// Vijand-statistieken per type.
class VijandStats {
  final int hp;
  final double snelheid; // cellen per seconde
  final int geldBijDood;
  final int levensVerlies; // als hij de basis bereikt

  const VijandStats({
    required this.hp,
    required this.snelheid,
    required this.geldBijDood,
    required this.levensVerlies,
  });

  static VijandStats van(VijandType type, int golfNummer) {
    // Schaal HP op met het golfnummer: +12% per golf boven 1.
    final hpMult = 1 + 0.12 * (golfNummer - 1);
    switch (type) {
      case VijandType.normaal:
        return VijandStats(
          hp: (30 * hpMult).round(),
          snelheid: 1.4,
          geldBijDood: 12,
          levensVerlies: GameBalance.levensVerliesNormaal,
        );
      case VijandType.snel:
        return VijandStats(
          hp: (18 * hpMult).round(),
          snelheid: 2.5,
          geldBijDood: 15,
          levensVerlies: GameBalance.levensVerliesNormaal,
        );
      case VijandType.tank:
        return VijandStats(
          hp: (110 * hpMult).round(),
          snelheid: 0.8,
          geldBijDood: 35,
          levensVerlies: GameBalance.levensVerliesTank,
        );
      case VijandType.boss:
        return VijandStats(
          hp: (600 * hpMult).round(),
          snelheid: 0.55,
          geldBijDood: 150,
          levensVerlies: GameBalance.levensVerliesBoss,
        );
    }
  }
}