import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:tower_defense/game/game_config.dart';
import 'package:tower_defense/game/game_state.dart';
import 'package:tower_defense/game/levels.dart';

/// Realistische speler-simulatie: geen geld-cheat, torens bijkopen van wat je
/// verdient, mix van fysiek en magisch (zodat Gepantserd én Schild op te
/// vangen zijn). Dit is de maatstaf voor "is het spel eerlijk speelbaar?".
void main() {
  /// Speelt een kaart met een realistische economie. Geeft de eindstatus terug.
  ({GameStatus status, int golf, int levens, int torens}) speel(
    LevelConfig lvl, {
    required bool modifiers,
    int startBonus = 0,
  }) {
    final s = GameState(levelConfig: lvl);
    s.modifiersActief = modifiers;
    s.geld += startBonus;

    // Kandidaat-plekken: het hele raster, gesorteerd op afstand tot het pad
    // (dichtstbij eerst — dat is waar een speler bouwt).
    final kandidaten = <(double, double, double)>[];
    for (var x = 0.6; x < 16.0; x += 1.05) {
      for (var y = 0.6; y < 9.0; y += 1.05) {
        if (s.isPadCel(x, y)) continue;
        var dichtst = 999.0;
        for (var i = 0; i < lvl.pad.length - 1; i++) {
          final (x1, y1) = lvl.pad[i];
          final (x2, y2) = lvl.pad[i + 1];
          final dx = x2 - x1;
          final dy = y2 - y1;
          final lenSq = dx * dx + dy * dy;
          var t = lenSq == 0
              ? 0.0
              : ((x - x1) * dx + (y - y1) * dy) / lenSq;
          t = t.clamp(0.0, 1.0);
          final nx = x1 + dx * t;
          final ny = y1 + dy * t;
          final d = math.sqrt((x - nx) * (x - nx) + (y - ny) * (y - ny));
          if (d < dichtst) dichtst = d;
        }
        if (dichtst < 2.2) kandidaten.add((x, y, dichtst));
      }
    }
    kandidaten.sort((a, b) => a.$3.compareTo(b.$3));

    // Strategie: mix van fysiek en magisch, goedkoopste eerst zodat er snel
    // veel torens staan (dat is wat een echte speler ook doet).
    final mix = [
      TorenType.dart,
      TorenType.tack,
      TorenType.bliksem,
      TorenType.ijs,
      TorenType.bom,
      TorenType.gif,
      TorenType.sniper,
    ];
    var mi = 0;
    var ki = 0;

    void koopEnUpgrade() {
      var actie = true;
      while (actie) {
        actie = false;
        // Eerst upgraden als het geld het toelaat (beste DPS per euro).
        for (final t in s.torens) {
          if (t.level < GameBalance.maxTorenLevel &&
              s.geld >= t.stats.upgradeKosten(t.level) * 2) {
            s.upgradeToren(t);
            actie = true;
            break;
          }
        }
        if (actie) continue;
        // Nieuwe toren op de dichtstbijzijnde vrije plek.
        while (ki < kandidaten.length) {
          final (x, y, _) = kandidaten[ki];
          final type = mix[mi % mix.length];
          final prijs = TorenStats.van(type, 1).basisKosten;
          if (s.geld < prijs) return; // niets meer betaalbaar
          s.tePlaatsenType = type;
          final voor = s.torens.length;
          s.plaatsToren(x, y);
          if (s.torens.length > voor) {
            mi++;
            ki++;
            actie = true;
            break;
          }
          ki++; // plek bezet: volgende
        }
      }
    }

    for (var golf = 1; golf <= lvl.totaalGolven; golf++) {
      koopEnUpgrade();
      s.startGolf();
      for (var i = 0; i < 20000 && s.status == GameStatus.golfLoopt; i++) {
        s.update(0.05);
      }
      if (s.status == GameStatus.verloren || s.status == GameStatus.gewonnen) {
        break;
      }
    }
    return (
      status: s.status,
      golf: s.golfNummer,
      levens: s.levens,
      torens: s.torens.length,
    );
  }

  test('realistische speler: elke kaart blijft winbaar MET modifiers', () {
    for (final lvl in alleLevels) {
      final zonder = speel(lvl, modifiers: false);
      final met = speel(lvl, modifiers: true);
      // ignore: avoid_print
      print('${lvl.id}: ZONDER ${zonder.status.name} g${zonder.golf} '
          'lev${zonder.levens} t${zonder.torens}  ||  '
          'MET ${met.status.name} g${met.golf} lev${met.levens} t${met.torens}');
      expect(met.status, GameStatus.gewonnen,
          reason: '${lvl.id} moet winbaar blijven met golf-modifiers '
              '(eindigde op golf ${met.golf}, ${met.levens} levens)');
      // De speler mag niet leeglopen: minstens 1 leven over.
      expect(met.levens, greaterThan(0));
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('sweep: welk startgeld maakt de vallei eerlijk speelbaar?', skip: true, () {
    // Zoekt de band waarin de speler het haalt (met marge), met en zonder
    // modifiers — zodat de modifiers voelbaar zijn zonder oneerlijk te zijn.
    for (final bonus in [0, 200, 400, 600, 800]) {
      final zonder = speel(levelGroeneVallei, modifiers: false, startBonus: bonus);
      final met = speel(levelGroeneVallei, modifiers: true, startBonus: bonus);
      // ignore: avoid_print
      print('vallei startgeld=${200 + bonus}: ZONDER ${zonder.status.name} '
          'g${zonder.golf} lev${zonder.levens} t${zonder.torens}  ||  '
          'MET ${met.status.name} g${met.golf} lev${met.levens} t${met.torens}');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
