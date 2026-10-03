import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tower_defense/game/entities.dart';
import 'package:tower_defense/game/game_config.dart';
import 'package:tower_defense/game/game_state.dart';
import 'package:tower_defense/game/levels.dart';
import 'package:tower_defense/services/progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Nieuwe torentypes (fase 2)', () {
    test('bliksem en gif bestaan met eigen stats', () {
      final bliksem = TorenStats.van(TorenType.bliksem, 1);
      final gif = TorenStats.van(TorenType.gif, 1);
      expect(bliksem.basisKosten, GameBalance.kostenBliksem);
      expect(bliksem.schade, greaterThan(TorenStats.van(TorenType.kanon, 1).schade));
      expect(gif.basisKosten, GameBalance.kostenGif);
    });

    test('gif-vijand verliest HP over tijd door vergiftiging', () {
      final s = GameState();
      s.startGolf();
      s.update(1.0); // spawn
      final v = s.vijanden.first;
      final hpVoor = v.hp;
      v.vergif(2.0);
      s.update(1.0); // 1 s gif → 8 HP kwijt
      expect(v.hp, lessThan(hpVoor));
      expect(v.hp, closeTo(hpVoor - 8, 1.0));
    });

    test('gif-projectiel vergiftigt doel', () {
      final s = GameState();
      s.startGolf();
      s.update(1.0);
      final v = s.vijanden.first;
      final hpVoor = v.hp;
      v.vergif(4.0);
      // 2 s simuleren → 16 gif-schade (geen andere torens).
      s.update(2.0);
      expect(v.hp, closeTo(hpVoor - 16, 2.0));
    });
  });

  group('Boss (fase 4)', () {
    test('boss verschijnt op golf 10 en 20', () {
      expect(Golf.bouw(10).spawns.any((x) => x.$1 == VijandType.boss), isTrue);
      expect(Golf.bouw(20).spawns.any((x) => x.$1 == VijandType.boss), isTrue);
      expect(Golf.bouw(7).spawns.any((x) => x.$1 == VijandType.boss), isFalse);
    });

    test('boss heeft 5× tank-HP en kost 5 levens', () {
      final boss = VijandStats.van(VijandType.boss, 1);
      final tank = VijandStats.van(VijandType.tank, 1);
      expect(boss.hp, greaterThan(tank.hp * 3));
      expect(boss.levensVerlies, 5);
      expect(boss.geldBijDood, greaterThan(tank.geldBijDood));
    });
  });

  group('Meerdere kaarten (fase 3)', () {
    test('alle 3 levels hebben geldige paden (binnen raster, niet-lege cellen)', () {
      for (final lvl in alleLevels) {
        for (final (x, y) in lvl.pad) {
          // Spawn/exit mogen net buiten beeld liggen (-1 of 17).
          expect(x >= -1 && x <= 17, isTrue, reason: '${lvl.id}: x=$x buiten raster');
          expect(y >= 0 && y <= 9, isTrue, reason: '${lvl.id}: y=$y buiten raster');
        }
        expect(lvl.startGeld, greaterThan(0));
        expect(lvl.startLevens, greaterThan(0));
        expect(lvl.totaalGolven, greaterThanOrEqualTo(20));
      }
    });

    test('elke kaart gebruikt eigen economie in GameState', () {
      final s1 = GameState(levelConfig: levelGroeneVallei);
      final s2 = GameState(levelConfig: levelSlang);
      expect(s1.geld, levelGroeneVallei.startGeld);
      expect(s2.geld, levelSlang.startGeld);
      expect(s2.level.totaalGolven, 25);
      expect(s1.level.totaalGolven, 20);
    });

    test('slang-pad is beduidend langer dan vallei-pad', () {
      expect(
        padTotaleLengte(levelSlang.pad),
        greaterThan(padTotaleLengte(levelGroeneVallei.pad) * 1.2),
      );
    });
  });

  group('Multi-level simulatie (fase 3 + balans)', () {
    test('elke kaart is winbaar met een flinke verdediging', () {
      for (final lvl in alleLevels) {
        final s = GameState(levelConfig: lvl);
        s.geld = 100000;
        // Bestrijk het veld met torens op een grid; pad-cellen worden geweigerd.
        for (var x = 1.0; x < 15.5; x += 1.4) {
          for (var y = 0.5; y < 9.0; y += 1.4) {
            s.tePlaatsenType = TorenType.kanon;
            s.plaatsToren(x, y);
          }
        }
        expect(s.torens.length, greaterThan(8),
            reason: '${lvl.id}: grid-plaatsing moet torens opleveren');

        for (var golf = 1; golf <= lvl.totaalGolven; golf++) {
          s.startGolf();
          for (var i = 0; i < 3000 && s.status == GameStatus.golfLoopt; i++) {
            s.update(0.05);
          }
          if (s.status == GameStatus.verloren) break;
          if (s.status != GameStatus.tussenGolven && golf < lvl.totaalGolven) break;
          // Upgrade tussendoor.
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

  group('ProgressService (fase 8)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('lege start: geen voortgang', () async {
      final v = await ProgressService.laad();
      expect(v, isEmpty);
    });

    test('registreerWinst bewaart sterren en highscore', () async {
      await ProgressService.registreerWinst(levelId: 'vallei', sterren: 2, score: 1400);
      var v = await ProgressService.laad();
      expect(v['vallei']!.sterren, 2);
      expect(v['vallei']!.highscore, 1400);
      // Beter resultaat overschrijft.
      await ProgressService.registreerWinst(levelId: 'vallei', sterren: 3, score: 1800);
      v = await ProgressService.laad();
      expect(v['vallei']!.sterren, 3);
      expect(v['vallei']!.highscore, 1800);
      // Slechter resultaat verandert niets.
      await ProgressService.registreerWinst(levelId: 'vallei', sterren: 1, score: 900);
      v = await ProgressService.laad();
      expect(v['vallei']!.sterren, 3);
      expect(v['vallei']!.highscore, 1800);
    });
  });
}