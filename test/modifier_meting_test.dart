import 'package:flutter_test/flutter_test.dart';

import 'package:tower_defense/game/game_config.dart';
import 'package:tower_defense/game/game_state.dart';
import 'package:tower_defense/game/levels.dart';

/// Vergelijkingsmeting: dezelfde opstelling, met en zonder golf-modifiers.
/// Doel: kwantificeren hoeveel zwaarder de modifiers de golven maken, zodat
/// de balans gericht bijgesteld kan worden in plaats van op gevoel.
void main() {
  void meet(LevelConfig lvl, {required bool modifiers, double density = 1.0, bool printResult = true}) {
    final s = GameState(levelConfig: lvl);
    s.modifiersActief = modifiers;
    s.geld = 1000000;

    // Raster plaatsen: alles wat vrij is krijgt een toren, in een vaste mix
    // van fysiek en magisch zodat Gepantserd én Schild opgevangen worden.
    // [density] < 1 laat cellen over (om een speler met minder geld na te
    // bootsen — daar wordt het effect van de modifiers pas meetbaar).
    final types = [
      TorenType.dart,
      TorenType.bliksem,
      TorenType.gif,
      TorenType.sniper,
      TorenType.bom,
      TorenType.ijs,
      TorenType.tack,
    ];
    var ti = 0;
    var cel = 0;
    for (var x = 0.6; x < 16.0; x += 1.1) {
      for (var y = 0.6; y < 9.0; y += 1.1) {
        cel++;
        if (density < 1.0 && (cel % 100) >= (density * 100).round()) continue;
        final type = types[ti % types.length];
        s.tePlaatsenType = type;
        final voor = s.torens.length;
        s.plaatsToren(x, y);
        if (s.torens.length > voor) ti++;
      }
    }
    for (final t in s.torens) {
      while (t.level < GameBalance.maxTorenLevel) {
        s.upgradeToren(t);
      }
    }

    for (var golf = 1; golf <= lvl.totaalGolven; golf++) {
      s.startGolf();
      for (var i = 0; i < 20000 && s.status == GameStatus.golfLoopt; i++) {
        s.update(0.05);
      }
      if (s.status == GameStatus.verloren || s.status == GameStatus.gewonnen) {
        break;
      }
      for (final t in s.torens) {
        while (t.level < GameBalance.maxTorenLevel) {
          s.upgradeToren(t);
        }
      }
    }
    if (printResult) {
      // ignore: avoid_print
      print('${lvl.id} d=$density modifiers=${modifiers ? 'AAN' : 'uit'}: '
          '${s.status.name} golf=${s.golfNummer}/${lvl.totaalGolven} '
          'levens=${s.levens} torens=${s.torens.length}');
    }
  }

  test('meting: kantelpunt — waar maken modifiers het verschil?', skip: true, () {
    // Vallei bij afnemende dichtheid: zoekt de band waarin de modifiers
    // daadwerkelijk uitmaken (boven: alles wint, onder: alles verliest).
    for (final d in [0.5, 0.35, 0.25]) {
      meet(levelGroeneVallei, modifiers: false, density: d);
      meet(levelGroeneVallei, modifiers: true, density: d);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('meting: modifiers aan vs. uit per kaart', skip: true, () {
    for (final lvl in alleLevels) {
      meet(lvl, modifiers: false);
      meet(lvl, modifiers: true);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
