import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tower_defense/game/entities.dart';
import 'package:tower_defense/game/game_config.dart';
import 'package:tower_defense/game/game_state.dart';
import 'package:tower_defense/game/levels.dart';
import 'package:tower_defense/services/progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    test('startwaarden kloppen (BTD-economie)', () {
      final s = GameState();
      expect(s.geld, levelGroeneVallei.startGeld);
      expect(s.levens, levelGroeneVallei.startLevens);
      expect(s.status, GameStatus.klaarVoorStart);
      expect(s.torens, isEmpty);
    });

    test('plaatsen kost geld en staat op vrij veld', () {
      final s = GameState();
      s.tePlaatsenType = TorenType.dart;
      expect(s.isPadCel(4, 4), isFalse, reason: '(4,4) hoort buiten het pad te liggen');
      final geldVoor = s.geld;
      s.plaatsToren(4, 4);
      expect(s.torens.length, 1);
      expect(s.geld, geldVoor - GameBalance.kostenDart);
    });

    test('plaatsen op pad is verboden', () {
      final s = GameState();
      s.tePlaatsenType = TorenType.dart;
      expect(s.isPadCel(1.0, 4.0), isTrue);
      s.plaatsToren(1.0, 4.0);
      expect(s.torens, isEmpty);
    });

    test('upgrade kost geld en verhoogt level (max 3)', () {
      final s = GameState();
      s.tePlaatsenType = TorenType.dart;
      s.plaatsToren(4, 4);
      final t = s.torens.first;
      s.geld = 10000;
      final kosten = t.stats.upgradeKosten(t.level);
      s.upgradeToren(t);
      expect(t.level, 2);
      expect(s.geld, 10000 - kosten);
      s.upgradeToren(t);
      expect(t.level, 3);
      s.upgradeToren(t);
      expect(t.level, 3);
    });

    test('verkoop geeft 70% terug', () {
      final s = GameState();
      s.tePlaatsenType = TorenType.dart;
      s.plaatsToren(4, 4);
      final t = s.torens.first;
      final waarde = t.verkoopWaarde();
      final geldVoor = s.geld;
      s.verkoopToren(t);
      expect(s.torens, isEmpty);
      expect(s.geld, geldVoor + waarde);
      expect(waarde, (GameBalance.kostenDart * GameBalance.verkoopFactor).round());
    });
  });

  group('Bloon-lagen (Bloons-kern!)', () {
    test('rood heeft geen kinderen; blauw → 1 rood', () {
      final rood = BloonStats.van(BloonType.rood);
      final blauw = BloonStats.van(BloonType.blauw);
      expect(rood.childType, isNull);
      expect(blauw.childType, BloonType.rood);
      expect(blauw.childAantal, 1);
    });

    test('zwart → 2 roze; MOAB → 4 keramiek', () {
      final zwart = BloonStats.van(BloonType.zwart);
      expect(zwart.childAantal, 2);
      expect(zwart.childType, BloonType.roze);

      final moab = BloonStats.van(BloonType.moab);
      expect(moab.childType, BloonType.keramiek);
      expect(moab.childAantal, 4);
      expect(moab.hp, greaterThan(100));
      expect(moab.levensVerlies, greaterThanOrEqualTo(10));
    });

    test('laag-keten is aaneengesloten', () {
      for (final type in BloonType.values) {
        final st = BloonStats.van(type);
        if (st.childType != null) {
          expect(BloonStats.alle.containsKey(st.childType), isTrue,
              reason: '${st.naam} wijst naar onbekend kind');
        }
      }
    });

    test('pop bloon → kinderen verschijnen', () {
      final s = GameState();
      s.startGolf();
      s.update(1.0);
      expect(s.vijanden, isNotEmpty);
      final blauw = s.vijanden.where((v) => v.type == BloonType.blauw).toList();
      if (blauw.isNotEmpty) {
        blauw.first.schade(999);
        s.update(0.016);
        expect(s.vijanden.any((v) => v.type == BloonType.rood), isTrue,
            reason: 'blauw-kind (rood) moet verschijnen na pop');
      }
    });

    test('MOAB-pop spawnt 4 keramiek + popt-teller stijgt', () {
      final s = GameState();
      s.startGolf();
      s.vijanden.clear();
      final moab = Vijand(BloonType.moab, BloonStats.van(BloonType.moab), 0);
      s.vijanden.add(moab);
      moab.schade(999);
      s.update(0.016);
      expect(
          s.vijanden.where((v) => v.type == BloonType.keramiek).length, 4);
      expect(s.poptsTotaal, greaterThanOrEqualTo(1));
    });
  });

  group('Torens (BTD-set)', () {
    test('tack heeft 8 spijkers + max-afstand; bom heeft splash', () {
      final tack = TorenStats.van(TorenType.tack, 1);
      expect(tack.spijkers, 8);
      expect(tack.maxProjectielAfstand, isNotNull);

      final bom = TorenStats.van(TorenType.bom, 1);
      expect(bom.splashRadius, isNotNull);
      expect(bom.splashRadius!, greaterThan(0.5));
    });

    test('sniper doorslaat veel lagen (schade >= 10)', () {
      expect(TorenStats.van(TorenType.sniper, 1).schade, greaterThanOrEqualTo(10));
    });

    test('levels verbeteren schade', () {
      expect(TorenStats.van(TorenType.dart, 2).schade,
          greaterThan(TorenStats.van(TorenType.dart, 1).schade));
    });

    test('7 torentypes bestaan met eigen kosten', () {
      final kosten = {
        TorenType.dart: GameBalance.kostenDart,
        TorenType.tack: GameBalance.kostenTack,
        TorenType.ijs: GameBalance.kostenIjs,
        TorenType.gif: GameBalance.kostenGif,
        TorenType.bom: GameBalance.kostenBom,
        TorenType.sniper: GameBalance.kostenSniper,
        TorenType.bliksem: GameBalance.kostenBliksem,
      };
      for (final type in TorenType.values) {
        expect(kosten.containsKey(type), isTrue, reason: '$type mist kosten');
        expect(kosten[type]!, greaterThan(0));
      }
    });
  });

  group('Golven (BTD-curve)', () {
    test('golf 10 bevat een MOAB; golf 20 twee', () {
      final g10 = Golf.bouw(10, totaalGolven: 20);
      final g20 = Golf.bouw(20, totaalGolven: 20);
      expect(g10.spawns.where((x) => x.$1 == BloonType.moab).length, 1);
      expect(g20.spawns.where((x) => x.$1 == BloonType.moab).length, 2);
    });

    test('latere golven hebben hogere lagen', () {
      final g2 = Golf.bouw(2);
      final g16 = Golf.bouw(16);
      expect(g2.spawns.first.$1, BloonType.rood);
      expect(g16.spawns.first.$1, BloonType.regenboog);
    });
  });

  group('Zonder verdediging', () {
    test('levens verliezen', () {
      final s = GameState();
      s.startGolf();
      for (var i = 0; i < 800; i++) {
        s.update(0.05);
        if (s.status == GameStatus.verloren) break;
      }
      expect(s.levens, lessThan(s.level.startLevens));
    });
  });

  group('Multi-level simulatie', () {
    test('elke kaart is winbaar met een grid vol torens', () {
      for (final lvl in alleLevels) {
        final s = GameState(levelConfig: lvl);
        s.geld = 100000;
        for (var x = 1.0; x < 15.5; x += 1.4) {
          for (var y = 0.5; y < 9.0; y += 1.4) {
            s.tePlaatsenType = TorenType.sniper;
            s.plaatsToren(x, y);
          }
        }
        expect(s.torens.length, greaterThan(8),
            reason: '${lvl.id}: grid-plaatsing moet torens opleveren');

        for (var golf = 1; golf <= lvl.totaalGolven; golf++) {
          s.startGolf();
          for (var i = 0; i < 6000 && s.status == GameStatus.golfLoopt; i++) {
            s.update(0.05);
          }
          if (s.status == GameStatus.verloren) break;
          if (s.status != GameStatus.tussenGolven && golf < lvl.totaalGolven) break;
          s.geld = 100000;
          for (final t in s.torens) {
            while (t.level < GameBalance.maxTorenLevel) {
              final voor = t.level;
              s.upgradeToren(t);
              if (t.level == voor) break;
            }
          }
        }
        expect(s.status, GameStatus.gewonnen, reason: '${lvl.id} moet winbaar zijn');
      }
    });
  });

  group('ProgressService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('registreerWinst bewaart beste sterren + highscore', () async {
      await ProgressService.registreerWinst(levelId: 'vallei', sterren: 2, score: 1400);
      var v = await ProgressService.laad();
      expect(v['vallei']!.sterren, 2);
      expect(v['vallei']!.highscore, 1400);
      await ProgressService.registreerWinst(levelId: 'vallei', sterren: 3, score: 1800);
      v = await ProgressService.laad();
      expect(v['vallei']!.sterren, 3);
      expect(v['vallei']!.highscore, 1800);
      await ProgressService.registreerWinst(levelId: 'vallei', sterren: 1, score: 900);
      v = await ProgressService.laad();
      expect(v['vallei']!.sterren, 3);
      expect(v['vallei']!.highscore, 1800);
    });
  });
}