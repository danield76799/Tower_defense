import 'package:flutter_test/flutter_test.dart';

import 'package:tower_defense/game/entities.dart';
import 'package:tower_defense/game/game_config.dart';
import 'package:tower_defense/game/game_state.dart';
import 'package:tower_defense/game/levels.dart';

void main() {
  group('Golf-modifiers — schema', () {
    test('vroege golven (1-4) hebben geen modifiers', () {
      for (var g = 1; g <= 4; g++) {
        expect(modifiersVoorGolf(g, 20), isEmpty, reason: 'golf $g');
      }
    });

    test('elke modifier wordt minstens één keer geïntroduceerd', () {
      final gezien = <GolfModifier>{};
      for (var g = 1; g <= 20; g++) {
        gezien.addAll(modifiersVoorGolf(g, 20));
      }
      expect(gezien, containsAll(GolfModifier.values));
    });

    test('finale heeft drie modifiers tegelijk', () {
      final finale = modifiersVoorGolf(20, 20);
      expect(finale.length, greaterThanOrEqualTo(3));
      expect(finale, contains(GolfModifier.gepantserd));
      expect(finale, contains(GolfModifier.sterk));
      expect(finale, contains(GolfModifier.snel));
    });

    test('schema is deterministisch (zelfde invoer = zelfde uitkomst)', () {
      expect(modifiersVoorGolf(12, 20), modifiersVoorGolf(12, 20));
      expect(modifiersVoorGolf(20, 20), modifiersVoorGolf(20, 20));
    });

    test('geen dubbele modifiers per golf', () {
      for (var g = 1; g <= 20; g++) {
        final m = modifiersVoorGolf(g, 20);
        expect(m.toSet().length, m.length, reason: 'golf $g');
      }
    });

    test('25-golf-kaart (Slang) houdt hetzelfde ritme', () {
      final finale = modifiersVoorGolf(25, 25);
      expect(finale, contains(GolfModifier.gepantserd));
      // Combo-golven bestaan ook op 25 golven.
      final combos = <int>[];
      for (var g = 1; g <= 25; g++) {
        if (modifiersVoorGolf(g, 25).length >= 2 && g != 25) combos.add(g);
      }
      expect(combos.length, greaterThanOrEqualTo(2));
    });
  });

  group('Vijand — modifier-effecten', () {
    test('Sterk geeft +25% HP', () {
      final normaal = Vijand(BloonType.keramiek, BloonStats.van(BloonType.keramiek), 0);
      final sterk = Vijand(BloonType.keramiek, BloonStats.van(BloonType.keramiek), 0,
          modifiers: [GolfModifier.sterk]);
      expect(normaal.hpMax, 10);
      expect(sterk.hpMax, closeTo(12.5, 0.001));
    });

    test('Gepantserd verlaagt fysieke schade met 35%, laat magische heel', () {
      final v = Vijand(BloonType.keramiek, BloonStats.van(BloonType.keramiek), 0,
          modifiers: [GolfModifier.gepantserd]);
      expect(v.schadeNaWeerstand(10, SchadeType.fysiek), closeTo(6.5, 0.001));
      expect(v.schadeNaWeerstand(10, SchadeType.magisch), 10);
    });

    test('Schild verlaagt magische schade met 35%, laat fysieke heel', () {
      final v = Vijand(BloonType.keramiek, BloonStats.van(BloonType.keramiek), 0,
          modifiers: [GolfModifier.magischSchild]);
      expect(v.schadeNaWeerstand(10, SchadeType.magisch), closeTo(6.5, 0.001));
      expect(v.schadeNaWeerstand(10, SchadeType.fysiek), 10);
    });

    test('zonder modifiers geen weerstand', () {
      final v = Vijand(BloonType.keramiek, BloonStats.van(BloonType.keramiek), 0);
      expect(v.schadeNaWeerstand(10, SchadeType.fysiek), 10);
      expect(v.schadeNaWeerstand(10, SchadeType.magisch), 10);
    });

    test('Snel verhoogt de loopsnelheid met 35%', () {
      final v = Vijand(BloonType.rood, BloonStats.van(BloonType.rood), 0,
          modifiers: [GolfModifier.snel]);
      expect(v.effectieveSnelheid,
          closeTo(BloonStats.van(BloonType.rood).snelheid * 1.35, 0.001));
    });

    test('Regenererend herstelt 0,5 hp/s tot het maximum, niet erboven', () {
      final v = Vijand(BloonType.keramiek, BloonStats.van(BloonType.keramiek), 0,
          modifiers: [GolfModifier.regenererend]);
      v.schade(5); // 10 → 5
      expect(v.hp, 5);
      // 2 seconden regenereren = +1 hp.
      v.update(1.0);
      v.update(1.0);
      expect(v.hp, closeTo(6, 0.01));
      // Ver genoeg doorlopen: nooit boven het startmaximum.
      for (var i = 0; i < 60; i++) {
        v.update(1.0);
      }
      expect(v.hp, lessThanOrEqualTo(v.hpMax));
      expect(v.hp, closeTo(10, 0.01));
    });

    test('zonder Regen herstelt niets', () {
      final v = Vijand(BloonType.keramiek, BloonStats.van(BloonType.keramiek), 0);
      v.schade(5);
      v.update(2.0);
      expect(v.hp, 5);
    });
  });

  group('Schade-type per toren', () {
    test('fysiek: dart, tack, bom, sniper', () {
      expect(TorenType.dart.schadeType, SchadeType.fysiek);
      expect(TorenType.tack.schadeType, SchadeType.fysiek);
      expect(TorenType.bom.schadeType, SchadeType.fysiek);
      expect(TorenType.sniper.schadeType, SchadeType.fysiek);
    });

    test('magisch: ijs, gif, bliksem', () {
      expect(TorenType.ijs.schadeType, SchadeType.magisch);
      expect(TorenType.gif.schadeType, SchadeType.magisch);
      expect(TorenType.bliksem.schadeType, SchadeType.magisch);
    });
  });

  group('GameState — modifiers in de golf', () {
    /// Zet een sterke verdediging neer zodat de simulatie niet vroegtijdig
    /// verliest (levens op 0 → startGolf doet niets meer).
    void verdedig(GameState s) {
      s.geld = 100000;
      for (final (bx, by) in [(1.0, 2.6), (3.2, 1.5), (3.2, 3.4), (5.0, 0.6),
        (5.0, 2.8), (7.2, 7.5), (7.2, 6.1), (8.4, 6.6)]) {
        s.tePlaatsenType = TorenType.sniper;
        s.plaatsToren(bx, by);
      }
      s.geld = 100000;
    }

    test('startGolf zet de modifiers van het schema op de golf', () {
      final s = GameState(levelConfig: levelGroeneVallei);
      verdedig(s);
      for (var i = 0; i < 5; i++) {
        s.geld = 100000;
        s.startGolf();
        s.update(0.05);
        while (s.status == GameStatus.golfLoopt) {
          s.update(0.05);
        }
      }
      expect(s.golfNummer, 5, reason: 'simulatie moet golf 5 halen');
      // Golf 5 = Snel.
      expect(s.actieveModifiers, contains(GolfModifier.snel));
    });

    test('gespawnde bloons dragen de golf-modifiers', () {
      final s = GameState(levelConfig: levelGroeneVallei);
      verdedig(s);
      // Doorlopen tot golf 5 (Snel) — dan moet elke nieuwe bloon Snel hebben.
      for (var g = 1; g < 5; g++) {
        s.geld = 100000;
        s.startGolf();
        for (var i = 0; i < 3000 && s.status == GameStatus.golfLoopt; i++) {
          s.update(0.05);
        }
      }
      s.geld = 100000;
      s.startGolf();
      s.update(0.05);
      s.update(0.05);
      expect(s.golfNummer, 5);
      expect(s.vijanden, isNotEmpty);
      expect(s.vijanden.every((v) => v.heeft(GolfModifier.snel)), isTrue);
    });

    test('kinderen erven de modifiers van hun ouder', () {
      final s = GameState(levelConfig: levelGroeneVallei);
      verdedig(s);
      // Golf 7 = Gepantserd.
      for (var g = 1; g < 7; g++) {
        s.geld = 100000;
        s.startGolf();
        for (var i = 0; i < 3000 && s.status == GameStatus.golfLoopt; i++) {
          s.update(0.05);
        }
      }
      s.geld = 100000;
      s.startGolf();
      // Direct na de spawn kijken: de snipers ruimen de golf razendsnel op.
      var gezien = false;
      for (var i = 0; i < 600; i++) {
        s.update(0.05);
        if (s.vijanden.any((v) => v.heeft(GolfModifier.gepantserd))) {
          gezien = true;
          break;
        }
      }
      expect(s.golfNummer, 7, reason: 'simulatie moet golf 7 halen');
      expect(gezien, isTrue,
          reason: 'golf 7 is Gepantserd: de bloons moeten de modifier dragen');
    });
  });
}
