/// Een speelbare kaart: pad, balans en naam.
class LevelConfig {
  final String id;
  final String naam;
  final List<(double, double)> pad;
  final int startGeld;
  final int startLevens;
  final int totaalGolven;

  const LevelConfig({
    required this.id,
    required this.naam,
    required this.pad,
    required this.startGeld,
    required this.startLevens,
    required this.totaalGolven,
  });
}

/// Kaart 1: Groene Vallei — het bekende S-pad, makkelijkst.
const levelGroeneVallei = LevelConfig(
  id: 'vallei',
  naam: 'Groene Vallei',
  pad: [
    (-1.0, 4.0),
    (2.0, 4.0),
    (2.0, 1.5),
    (6.0, 1.5),
    (6.0, 7.5),
    (9.5, 7.5),
    (9.5, 4.0),
    (13.0, 4.0),
    (13.0, 1.5),
    (17.0, 1.5),
  ],
  startGeld: 200,
  startLevens: 20,
  totaalGolven: 20,
);

/// Kaart 2: Dubbele Kronkel — langer pad, minder startgeld.
const levelDubbeleKronkel = LevelConfig(
  id: 'kronkel',
  naam: 'Dubbele Kronkel',
  pad: [
    (-1.0, 2.0),
    (3.0, 2.0),
    (3.0, 7.0),
    (7.0, 7.0),
    (7.0, 1.0),
    (11.0, 1.0),
    (11.0, 6.0),
    (14.0, 6.0),
    (14.0, 3.0),
    (17.0, 3.0),
  ],
  startGeld: 180,
  startLevens: 18,
  totaalGolven: 20,
);

/// Kaart 3: Slang — lang serpentine-pad, min startgeld, 25 golven.
const levelSlang = LevelConfig(
  id: 'slang',
  naam: 'Slang',
  pad: [
    (-1.0, 7.5),
    (14.0, 7.5),
    (14.0, 1.5),
    (2.0, 1.5),
    (2.0, 4.5),
    (17.0, 4.5),
  ],
  startGeld: 160,
  startLevens: 15,
  totaalGolven: 25,
);

const alleLevels = [levelGroeneVallei, levelDubbeleKronkel, levelSlang];