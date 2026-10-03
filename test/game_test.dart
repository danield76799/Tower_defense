import 'package:flutter_test/flutter_test.dart';

import 'package:tower_defense/game/entities.dart';
import 'package:tower_defense/game/game_config.dart';
import 'package:tower_defense/game/game_state.dart';
import 'package:tower_defense/game/levels.dart';

void main() {
  group('Pad', () {
    test('totale padlengte is positief en consistent', () {
      final lengte = padTotaleLengte(levelGroeneVallei.pad);
      expect(lengte, greaterThan(30));
    });

    test('positieOpPad bij afstand 0 is de eerste marker', () {
      final (x, y) = positieOpPad(levelGroeneVallei.pad, 0.0);
      expect(x, closeTo(levelGroeneVallei.pad.first.$1, 0.01));
      expect(y, closeTo(levelGroeneVallei.pad.first.$2, 0.01));
    });

    test('positieOpPad voorbij einde geeft laatste punt', () {
      final (x, y) = positieOpPad(
          levelGroeneVallei.pad, padTotaleLengte(levelGroeneVallei.pad) + 100);
      expect(x, closeTo(levelGroeneVallei.pad.last.$1, 0.01));
      expect(y, closeTo(levelGroeneVallei.pad.last.$2, 0.01));
    });
  });

  group('GameState basaal', () {
    test('startwaarden kloppen', () {
      final s = GameState();
      expect(s.geld, GameBalance.startGeld);
      expect(s.levens, GameBalance.startLevens);
      expect(s.status, GameStatus.klaarVoorStart);
      expect(s.torens, isEmpty);
    });

    test('plaatsen kost geld en staat op vrij veld', () {
      final s = GameState();
      s.tePlaatsenType = TorenType.kanon;
      // Cel (4, 4) ligt naar verluidt vrij — check eerst.
      expect(s.isPadCel(4, 4), isFalse, reason: '(4,4) hoort buiten het pad te liggen');
      final geldVoor = s.geld;
      s.plaatsToren(4, 4);
      expect(s.torens.length, 1);
      expect(s.geld, geldVoor - GameBalance.kostenKanon);
    });

    test('plaatsen op pad is verboden', () {
      final s = GameState();
      s.tePlaatsenType = TorenType.kanon;
      // Midden van het eerste horizontale segment: (0.5, 4.0)-richting.
      expect(s.isPadCel(1.0, 4.0), isTrue);
      final torensVoor = s.torens.length;
      s.plaatsToren(1.0, 4.0);
      expect(s.torens.length, torensVoor);
    });

    test('te duur plaatsen is verboden', () {
      final s = GameState();
      s.geld = 10;
      s.tePlaatsenType = TorenType.kanon;
      s.plaatsToren(4, 4);
      expect(s.torens, isEmpty);
    });

    test('upgrade kost geld en verhoogt level', () {
      final s = GameState();
      s.tePlaatsenType = TorenType.kanon;
      s.plaatsToren(4, 4);
      final t = s.torens.first;
      s.geld = 10000;
      final kosten = t.stats.upgradeKosten(t.level);
      s.upgradeToren(t);
      expect(t.level, 2);
      expect(s.geld, 10000 - kosten);
      // Nog een keer → level 3 (max).
      s.upgradeToren(t);
      expect(t.level, 3);
      // Nog een keer → geen verandering.
      s.upgradeToren(t);
      expect(t.level, 3);
    });

    test('verkoop geeft 60% terug en verwijdert toren', () {
      final s = GameState();
      s.tePlaatsenType = TorenType.kanon;
      s.plaatsToren(4, 4);
      final t = s.torens.first;
      final waarde = t.verkoopWaarde();
      final geldVoor = s.geld;
      s.verkoopToren(t);
      expect(s.torens, isEmpty);
      expect(s.geld, geldVoor + waarde);
    });
  });

  group('Vijanden en golven', () {
    test('startGolf spawnt vijanden na verloop van tijd', () {
      final s = GameState();
      s.startGolf();
      expect(s.status, GameStatus.golfLoopt);
      // Nog geen spawns op t=0 (eerste spawn op t=0 kan direct zijn).
      s.update(0.0);
      final eersteAantal = s.vijanden.length;
      expect(eersteAantal, greaterThanOrEqualTo(1));
      // Na 2 s zijn er meer.
      s.update(2.0);
      expect(s.vijanden.length, greaterThan(eersteAantal));
    });

    test('vijand zonder torens ontsnapt en kost levens', () {
      final s = GameState();
      s.startGolf();
      // Speedrun de hele golf: veel updates met grote dt.
      for (var i = 0; i < 600; i++) {
        s.update(0.05);
      }
      // Golf is voorbij; er zijn levens verloren gegaan.
      expect(s.levens, lessThan(GameBalance.startLevens));
      final tussenGolf = s.status == GameStatus.tussenGolven ||
          s.status == GameStatus.golfLoopt ||
          s.status == GameStatus.verloren;
      expect(tussenGolf, isTrue);
    });

    test('ijs-vertraging remt vijand', () {
      final s = GameState();
      s.startGolf();
      s.update(1.0); // spawn
      final v = s.vijanden.first;
      final afstandVoor = v.afstand;
      v.vertrag(2.0);
      s.update(0.5);
      final afstandGetrapt = v.afstand - afstandVoor;
      // Geschaald met 0.45.
      final verwacht = VijandStats.van(v.type, s.golfNummer).snelheid * 0.45 * 0.5;
      expect(afstandGetrapt, closeTo(verwacht, 0.01));
    });

    test('20 golven genereren unieke, oplopende curves', () {
      final g1 = Golf.bouw(1);
      final g10 = Golf.bouw(10);
      final g20 = Golf.bouw(20);
      expect(g1.spawns.length, lessThan(g10.spawns.length));
      expect(g10.spawns.length, lessThan(g20.spawns.length));
      // Golf 5 bevat een tank.
      expect(Golf.bouw(5).spawns.any((s) => s.$1 == VijandType.tank), isTrue);
      // Golf 3 bevat snelle vijanden.
      expect(Golf.bouw(3).spawns.any((s) => s.$1 == VijandType.snel), isTrue);
    });

    test('vijanden op schaal: tank heeft meeste HP', () {
      final n = VijandStats.van(VijandType.normaal, 1);
      final q = VijandStats.van(VijandType.snel, 1);
      final t = VijandStats.van(VijandType.tank, 1);
      expect(t.hp, greaterThan(n.hp));
      expect(n.hp, greaterThan(q.hp));
      expect(q.snelheid, greaterThan(n.snelheid));
      expect(n.snelheid, greaterThan(t.snelheid));
    });
  });

  group('Toren-stats en schaling', () {
    test('level 2 heeft meer schade dan level 1', () {
      expect(TorenStats.van(TorenType.kanon, 2).schade,
          greaterThan(TorenStats.van(TorenType.kanon, 1).schade));
      expect(TorenStats.van(TorenType.sniper, 3).bereik,
          greaterThan(TorenStats.van(TorenType.sniper, 1).bereik));
    });

    test('upgradekosten zijn altijd betaalbaar op termijn maar stijgen', () {
      final l1 = TorenStats.van(TorenType.kanon, 1).upgradeKosten(1);
      final l2 = TorenStats.van(TorenType.kanon, 2).upgradeKosten(2);
      expect(l2, greaterThan(l1));
    });
  });

  group('Volledige gamesimulatie (rode draad)', () {
    test('een spel met torens kan gewonnen worden (sanity: economie werkt)', () {
      final s = GameState();
      // Plaats een paar kanonnen langs het pad.
      s.tePlaatsenType = TorenType.kanon;
      // Vrije cellen naast het eerste rechte stuk (pad op y=4).
      s.plaatsToren(3.0, 2.7); // boven pad-segment (2,4)→(6,4)... check isPadCel
      if (s.torens.isEmpty) {
        // Fallback: probeer iets verder van het pad.
        s.plaatsToren(4.0, 2.3);
      }
      s.geld = 100000; // veel geld voor de test
      for (final pos in [(2.5, 6.0), (7.0, 3.0), (8.0, 6.2), (10.5, 5.5), (12.0, 2.7), (14.0, 3.0)]) {
        s.tePlaatsenType = TorenType.kanon;
        s.plaatsToren(pos.$1, pos.$2);
        s.tePlaatsenType = TorenType.ijs;
        s.plaatsToren(pos.$1 + 0.0, pos.$2 - 1.0);
        s.tePlaatsenType = TorenType.sniper;
        s.plaatsToren(pos.$1 + 1.5, pos.$2 + 1.0);
      }
      expect(s.torens.length, greaterThan(3), reason: 'testen veronderstellen een verdediging');

      // Simuleer alle 20 golven met tussenstappen.
      var maxGolven = 0;
      for (var golf = 1; golf <= GameBalance.totaalGolven; golf++) {
        s.startGolf();
        maxGolven = golf;
        // Max 120 s per golf, in stappen van 50 ms.
        for (var i = 0; i < 2400 && s.status == GameStatus.golfLoopt; i++) {
          s.update(0.05);
        }
        // Upgrades met het opgelopen geld.
        s.geld = 100000;
        for (final t in s.torens) {
          while (t.level < GameBalance.maxTorenLevel) {
            final voor = t.level;
            s.upgradeToren(t);
            if (t.level == voor) break;
          }
        }
        if (s.status == GameStatus.verloren) break;
        if (s.status == GameStatus.gewonnen) break;
        // Anders: tussenGolven → volgende golf.
      }
      expect(
        s.status == GameStatus.gewonnen || s.status == GameStatus.verloren,
        isTrue,
        reason: 'na alle golven is het spel gewonnen of verloren (golf $maxGolven)',
      );
      // Met 100k geld en tig torens HOORT hij te winnen; als dat faalt is de
      // balans of de logica stuk.
      expect(s.status, GameStatus.gewonnen,
          reason: 'maximale verdediging moet alle 20 golven aankunnen');
    });

    test('een spel zonder torens wordt verloren', () {
      final s = GameState();
      for (var golf = 1; golf <= 3 && s.status != GameStatus.verloren; golf++) {
        s.startGolf();
        for (var i = 0; i < 2400 && s.status == GameStatus.golfLoopt; i++) {
          s.update(0.05);
        }
      }
      expect(s.status, GameStatus.verloren);
    });
  });
}