import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../game/entities.dart';
import '../game/game_config.dart';
import '../game/game_state.dart';
import '../game/levels.dart';

class GamePainter extends FlameGame with HasTappables {
  final GameState state;
  final Function(TorenType) onTorenGeselecteerd;
  final VoidCallback onUpgrade;
  final VoidCallback onVerkoop;
  final VoidCallback onStartGolf;
  final VoidCallback onTerugNaarMenu;
  final VoidCallback onToggleModifiers;
  final VoidCallback onToggleGeluid;

  bool geluidAan = true;
  final GameState state;

  late final AudioPlayer _audioPlayer;

  // Sprites
  late final Map<TorenType, Sprite> torenSprites;
  late final Map<String, Sprite> bloonSprites;
  late final Map<TorenType, Sprite> projectielSprites;
  late final Map<String, Sprite> padSprites;
  late final Map<String, ui.Image> achtergrondImages;

  // Animaties
  late final SpriteAnimationComponent regeneratieAnimatie;
  late final SpriteAnimationComponent explosieAnimatie;

  // Thema's
  final Map<String, String> levelThema = {
    'vallei': 'dirt',
    'kronkel': 'grass',
    'slang': 'sand',
  };

  GamePainter({
    required this.state,
    required this.onTorenGeselecteerd,
    required this.onUpgrade,
    required this.onVerkoop,
    required this.onStartGolf,
    required this.onTerugNaarMenu,
    required this.onToggleModifiers,
    required this.onToggleGeluid,
  }) : super() {
    _audioPlayer = AudioPlayer();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Laad alle sprites
    torenSprites = {
      for (final type in TorenType.values)
        type: await _loadSprite('assets/images/torens/toren_${type.name}_v2.png'),
    };

    bloonSprites = {
      for (final type in BloonType.values)
        type.name: await _loadSprite('assets/images/bloons/bloon_${type.name}.png'),
      'moab': await _loadSprite('assets/images/bloons/bloon_moab.png'),
      'bfb': await _loadSprite('assets/images/bloons/bloon_bfb.png'),
      'zomg': await _loadSprite('assets/images/bloons/bloon_zomg.png'),
      'bad': await _loadSprite('assets/images/bloons/bloon_bad.png'),
    };

    projectielSprites = {
      for (final type in TorenType.values)
        type: await _loadSprite('assets/images/projectielen/projectiel_${type.name}.png'),
    };

    padSprites = {
      for (final thema in ['dirt', 'grass', 'sand', 'snow', 'lava'])
        thema: await _loadSprite('assets/images/pad/pad_$thema.png'),
    };

    achtergrondImages = {
      for (final level in alleLevels)
        level.id: await _loadImage('assets/images/achtergronden/achtergrond_${level.id}.jpg'),
    };

    // Animaties
    regeneratieAnimatie = SpriteAnimationComponent.fromFrameData(
      await images.load('assets/images/bloons/bloon_regenboog.png'),
      SpriteAnimationData.sequenced(
        amount: 8,
        stepTime: 0.1,
        textureSize: Vector2(128, 128),
      ),
    )..anchor = Anchor.center;

    explosieAnimatie = SpriteAnimationComponent.fromFrameData(
      await images.load('assets/images/projectielen/projectiel_bom.png'),
      SpriteAnimationData.sequenced(
        amount: 6,
        stepTime: 0.08,
        textureSize: Vector2(128, 128),
        loop: false,
      ),
    )..anchor = Anchor.center;

    add(regeneratieAnimatie);
    add(explosieAnimatie);
  }

  Future<Sprite> _loadSprite(String path) async {
    final image = await images.load(path);
    return Sprite(image);
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await Flame.assets.readFile(path);
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(data.codeUnits));
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void speelGeluid(String pad) {
    if (!_geluidAan) return;
    _audioPlayer.play(AssetSource(pad));
  }

  @override
  void render(Canvas canvas) {
    final thema = levelThema[state.levelConfig.id] ?? 'dirt';
    final achtergrond = achtergrondImages[state.levelConfig.id];
    if (achtergrond != null) {
      canvas.drawImageRect(
        achtergrond,
        Rect.fromLTWH(0, 0, achtergrond.width.toDouble(), achtergrond.height.toDouble()),
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint(),
      );
    }

    // Donkere overlay voor tekstcontrast
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Pad tekenen
    _tekenPad(canvas, thema);

    // Torens tekenen
    for (final t in state.torens) {
      _tekenToren(canvas, t);
    }

    // Projectielen tekenen
    for (final p in state.projectielen) {
      _tekenProjectiel(canvas, p);
    }

    // Bloons tekenen
    for (final v in state.vijanden) {
      _tekenBloon(canvas, v);
    }

    // MOABs tekenen
    for (final m in state.moabs) {
      _tekenMoab(canvas, m);
    }

    // UI tekenen
    _tekenUI(canvas);
  }

  void _tekenPad(Canvas canvas, String thema) {
    final padSprite = padSprites[thema];
    if (padSprite == null) return;

    final pad = state.levelConfig.pad;
    for (var i = 0; i < pad.length - 1; i++) {
      final (x1, y1) = pad[i];
      final (x2, y2) = pad[i + 1];
      final dx = x2 - x1;
      final dy = y2 - y1;
      final afstand = math.sqrt(dx * dx + dy * dy);
      final stappen = (afstand / 0.3).ceil();

      for (var s = 0; s <= stappen; s++) {
        final t = s / stappen;
        final x = x1 + dx * t;
        final y = y1 + dy * t;
        padSprite.render(
          canvas,
          position: Vector2(x, y),
          size: Vector2(1.0, 1.0),
          overridePaint: Paint()..color = Colors.white.withOpacity(0.8),
        );
      }
    }
  }

  void _tekenToren(Canvas canvas, Toren t) {
    final sprite = torenSprites[t.type];
    if (sprite == null) return;

    // Schaduw
    canvas.drawCircle(
      Offset(t.x, t.y + 0.2),
      0.4,
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Toren-sprite
    sprite.render(
      canvas,
      position: Vector2(t.x, t.y),
      size: Vector2(1.0, 1.0),
      overridePaint: Paint()..color = Colors.white,
    );

    // Level-indicator (sterretjes)
    for (var i = 0; i < t.level; i++) {
      final x = t.x - 0.3 + i * 0.2;
      final y = t.y - 0.4;
      TextPainter(
        text: TextSpan(
          text: '★',
          style: TextStyle(color: Colors.yellow, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset(x, y));
    }

    // Bereik-cirkel (als geselecteerd)
    if (state.geselecteerdeToren == t) {
      canvas.drawCircle(
        Offset(t.x, t.y),
        t.stats.bereik,
        Paint()
          ..color = Colors.blue.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.05,
      );
    }
  }

  void _tekenProjectiel(Canvas canvas, Projectiel p) {
    final sprite = projectielSprites[p.type];
    if (sprite == null) return;

    // Trail-effect (dart/tack)
    if (p.type == TorenType.dart || p.type == TorenType.tack) {
      final trailPaint = Paint()
        ..color = p.type == TorenType.dart ? Colors.brown : Colors.grey
        ..strokeWidth = 0.1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(p.vorigeX, p.vorigeY),
        Offset(p.x, p.y),
        trailPaint,
      );
    }

    // Projectiel-sprite
    sprite.render(
      canvas,
      position: Vector2(p.x, p.y),
      size: Vector2(0.4, 0.4),
      overridePaint: Paint()..color = Colors.white,
    );

    // Explosie (bom)
    if (p.type == TorenType.bom && p.weg) {
      explosieAnimatie
        ..position = Vector2(p.x, p.y)
        ..size = Vector2(1.2, 1.2)
        ..update(0);
      explosieAnimatie.render(canvas);
      speelGeluid('audio/projectiel_bom_hit.wav');
    }
  }

  void _tekenBloon(Canvas canvas, Vijand v) {
    final sprite = bloonSprites[v.type.name];
    if (sprite == null) return;

    // Modifier-ringen
    _tekenModifierRingen(canvas, v);

    // Bloon-sprite
    sprite.render(
      canvas,
      position: Vector2(v.x, v.y),
      size: Vector2(v.straal * 2, v.straal * 2),
      overridePaint: Paint()..color = Colors.white,
    );

    // HP-bar
    final hpBarWidth = v.straal * 1.8;
    final hpBarHeight = 0.15;
    final hpPercentage = v.hp / v.hpMax;
    canvas.drawRect(
      Rect.fromLTWH(
        v.x - hpBarWidth / 2,
        v.y - v.straal - 0.2,
        hpBarWidth,
        hpBarHeight,
      ),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        v.x - hpBarWidth / 2,
        v.y - v.straal - 0.2,
        hpBarWidth * hpPercentage,
        hpBarHeight,
      ),
      Paint()..color = _kleurVoorBloon(v),
    );

    // Regen-animatie (als regenererend)
    if (v.heeft(GolfModifier.regenererend) && v.hp < v.hpMax) {
      regeneratieAnimatie
        ..position = Vector2(v.x, v.y)
        ..size = Vector2(v.straal * 2.2, v.straal * 2.2)
        ..update(0); // Forceer frame-update
      regeneratieAnimatie.render(canvas);
    }

    // Pop-geluid
    if (v.weg) {
      speelGeluid('audio/bloon_${v.type.name}_pop.wav');
    }
  }

  void _tekenMoab(Canvas canvas, Moab m) {
    final sprite = bloonSprites[m.type.name];
    if (sprite == null) return;

    // Modifier-ringen
    _tekenModifierRingen(canvas, m);

    // MOAB-sprite
    sprite.render(
      canvas,
      position: Vector2(m.x, m.y),
      size: Vector2(m.straal * 2, m.straal * 2),
      overridePaint: Paint()..color = Colors.white,
    );

    // HP-bar
    final hpBarWidth = m.straal * 1.8;
    final hpBarHeight = 0.2;
    final hpPercentage = m.hp / m.hpMax;
    canvas.drawRect(
      Rect.fromLTWH(
        m.x - hpBarWidth / 2,
        m.y - m.straal - 0.3,
        hpBarWidth,
        hpBarHeight,
      ),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        m.x - hpBarWidth / 2,
        m.y - m.straal - 0.3,
        hpBarWidth * hpPercentage,
        hpBarHeight,
      ),
      Paint()..color = _kleurVoorMoab(m),
    );
  }

  void _tekenModifierRingen(Canvas canvas, dynamic vijand) {
    final modifiers = vijand is Vijand ? vijand.modifiers : vijand.modifiers;
    if (modifiers.isEmpty) return;

    final center = Offset(vijand.x, vijand.y);
    final straal = vijand.straal + 0.1;

    for (final modifier in modifiers) {
      final kleur = modifier.kleur.withOpacity(0.6);
      canvas.drawCircle(
        center,
        straal + 0.05 * modifiers.indexOf(modifier),
        Paint()
          ..color = kleur
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.08,
      );
    }
  }

  Color _kleurVoorBloon(Vijand v) {
    if (v.heeft(GolfModifier.gepantserd)) return Colors.grey;
    if (v.heeft(GolfModifier.magischSchild)) return Colors.purple;
    return v.type.kleur;
  }

  Color _kleurVoorMoab(Moab m) {
    if (m.heeft(GolfModifier.gepantserd)) return Colors.grey[800]!;
    if (m.heeft(GolfModifier.magischSchild)) return Colors.purple[800]!;
    return Colors.blueGrey;
  }

  void _tekenUI(Canvas canvas) {
    final textStyle = TextStyle(color: Colors.white, fontSize: 16);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Geld
    textPainter.text = TextSpan(text: '€${state.geld}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(10, 10));

    // Levens
    textPainter.text = TextSpan(text: '❤️${state.levens}', style: textStyle);
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.x - 100, 10));

    // Golf
    textPainter.text = TextSpan(
      text: 'Golf ${state.golfNummer}/${state.levelConfig.totaalGolven}',
      style: textStyle,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.x / 2 - 70, 10));

    // Modifiers
    _tekenModifierChips(canvas);

    // Toren-selectie
    _tekenTorenSelectie(canvas);

    // Actie-buttons
    _tekenActieButtons(canvas);
  }

  void _tekenModifierChips(Canvas canvas) {
    final actieve = state.actieveModifiers;
    final volgende = state.volgendeModifiers;
    final textStyle = TextStyle(color: Colors.white, fontSize: 12);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    if (actieve.isNotEmpty) {
      textPainter.text = TextSpan(text: 'Deze golf:', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, 50));

      var x = 100;
      for (final modifier in actieve) {
        final kleur = modifier.kleur;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x.toDouble(), 45, 20, 20),
            Radius.circular(10),
          ),
          Paint()..color = kleur.withOpacity(0.7),
        );
        textPainter.text = TextSpan(
          text: modifier.uitleg,
          style: textStyle.copyWith(fontSize: 10),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x.toDouble(), 70));
        x += 25;
      }
    }

    if (volgende.isNotEmpty && state.status == GameStatus.pauze) {
      textPainter.text = TextSpan(text: 'Straks:', style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, 90));

      var x = 100;
      for (final modifier in volgende) {
        final kleur = modifier.kleur;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x.toDouble(), 85, 20, 20),
            Radius.circular(10),
          ),
          Paint()..color = kleur.withOpacity(0.7),
        );
        x += 25;
      }
    }
  }

  void _tekenTorenSelectie(Canvas canvas) {
    final torenTypes = TorenType.values;
    final buttonWidth = 60.0;
    final buttonHeight = 40.0;
    final startX = size.x - (torenTypes.length * (buttonWidth + 10)) - 10;
    final startY = size.y - buttonHeight - 10;

    for (var i = 0; i < torenTypes.length; i++) {
      final type = torenTypes[i];
      final x = startX + i * (buttonWidth + 10);
      final y = startY;

      // Button achtergrond
      final isGeselecteerd = state.tePlaatsenType == type;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, buttonWidth, buttonHeight),
          Radius.circular(8),
        ),
        Paint()
          ..color = isGeselecteerd ? Colors.blue : Colors.black.withOpacity(0.5),
      );

      // Toren-sprite
      final sprite = torenSprites[type];
      if (sprite != null) {
        sprite.render(
          canvas,
          position: Vector2(x + buttonWidth / 2, y + buttonHeight / 2),
          size: Vector2(20, 20),
          overridePaint: Paint()..color = Colors.white,
        );
      }

      // Prijs
      final prijs = TorenStats.van(type, 1).basisKosten;
      TextPainter(
        text: TextSpan(
          text: '€$prijs',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset(x + 5, y + 5));
    }
  }

  void _tekenActieButtons(Canvas canvas) {
    final buttonWidth = 100.0;
    final buttonHeight = 40.0;
    final startX = size.x - buttonWidth - 10;
    final startY = 10.0;

    // Start/Volgende golf
    if (state.status == GameStatus.pauze) {
      _tekenButton(
        canvas,
        x: startX,
        y: startY,
        width: buttonWidth,
        height: buttonHeight,
        text: 'Start golf',
        kleur: Colors.green,
        onTap: onStartGolf,
      );
    } else {
      _tekenButton(
        canvas,
        x: startX,
        y: startY,
        width: buttonWidth,
        height: buttonHeight,
        text: 'Volgende',
        kleur: Colors.orange,
        onTap: () {
          state.startGolf();
          speelGeluid('audio/golf_start.wav');
        },
      );
    }

    // Upgrade
    if (state.geselecteerdeToren != null) {
      _tekenButton(
        canvas,
        x: startX,
        y: startY + buttonHeight + 10,
        width: buttonWidth,
        height: buttonHeight,
        text: 'Upgrade (€${state.geselecteerdeToren!.stats.upgradeKosten(state.geselecteerdeToren!.level)})',
        kleur: Colors.blue,
        onTap: () {
          onUpgrade();
          speelGeluid('audio/button_click.wav');
        },
      );

      // Verkoop
      _tekenButton(
        canvas,
        x: startX,
        y: startY + 2 * (buttonHeight + 10),
        width: buttonWidth,
        height: buttonHeight,
        text: 'Verkoop (€${state.geselecteerdeToren!.stats.verkoopPrijs(state.geselecteerdeToren!.level)})',
        kleur: Colors.red,
        onTap: () {
          onVerkoop();
          speelGeluid('audio/button_click.wav');
        },
      );
    }

    // Terug naar menu
    _tekenButton(
      canvas,
      x: 10,
      y: size.y - buttonHeight - 10,
      width: buttonWidth,
      height: buttonHeight,
      text: 'Menu',
      kleur: Colors.grey,
      onTap: onTerugNaarMenu,
    );

    // Modifiers aan/uit
    _tekenButton(
      canvas,
      x: 10 + buttonWidth + 10,
      y: size.y - buttonHeight - 10,
      width: buttonWidth,
      height: buttonHeight,
      text: state.modifiersActief ? 'Modifiers: AAN' : 'Modifiers: UIT',
      kleur: state.modifiersActief ? Colors.green : Colors.red,
      onTap: onToggleModifiers,
    );

    // Geluid aan/uit
    _tekenButton(
      canvas,
      x: 10 + 2 * (buttonWidth + 10),
      y: size.y - buttonHeight - 10,
      width: buttonWidth,
      height: buttonHeight,
      text: _geluidAan ? 'Geluid: AAN' : 'Geluid: UIT',
      kleur: _geluidAan ? Colors.green : Colors.red,
      onTap: () {
        _geluidAan = !_geluidAan;
        onToggleGeluid();
        speelGeluid('audio/button_click.wav');
      },
    );
  }

  void _tekenButton(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    String text,
    Color kleur,
    VoidCallback onTap,
  ) {
    // Achtergrond
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        Radius.circular(8),
      ),
      Paint()..color = kleur.withOpacity(0.7),
    );

    // Tekst
    TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    )
      ..layout(maxWidth: width - 10)
      ..paint(canvas, Offset(x + 5, y + height / 2 - 10));
  }

  @override
  void update(double dt) {
    super.update(dt);
    regeneratieAnimatie.update(dt);
    explosieAnimatie.update(dt);
  }

  void dispose() {
    _audioPlayer.dispose();
  }
    final pos = info.eventPosition.game;
    final x = pos.x;
    final y = pos.y;

    // Check of een toren geselecteerd is
    for (final t in state.torens) {
      final afstand = math.sqrt(math.pow(t.x - x, 2) + math.pow(t.y - y, 2));
      if (afstand <= 0.5) {
        state.geselecteerdeToren = t;
        return;
      }
    }

    // Check of een toren-type geselecteerd is
    final torenTypes = TorenType.values;
    final buttonWidth = 60.0;
    final buttonHeight = 40.0;
    final startX = size.x - (torenTypes.length * (buttonWidth + 10)) - 10;
    final startY = size.y - buttonHeight - 10;

    for (var i = 0; i < torenTypes.length; i++) {
      final type = torenTypes[i];
      final bx = startX + i * (buttonWidth + 10);
      final by = startY;
      if (x >= bx && x <= bx + buttonWidth && y >= by && y <= by + buttonHeight) {
        onTorenGeselecteerd(type);
        speelGeluid('audio/button_click.wav');
        return;
      }
    }

    // Check of een actie-button aangeklikt is
    final buttonWidthActie = 100.0;
    final buttonHeightActie = 40.0;
    final startXActie = size.x - buttonWidthActie - 10;

    // Start/Volgende golf
    if (x >= startXActie && x <= startXActie + buttonWidthActie &&
        y >= 10 && y <= 10 + buttonHeightActie) {
      if (state.status == GameStatus.pauze) {
        onStartGolf();
      } else {
        state.startGolf();
      }
      speelGeluid('audio/golf_start.wav');
      return;
    }

    // Upgrade
    if (state.geselecteerdeToren != null) {
      if (x >= startXActie && x <= startXActie + buttonWidthActie &&
          y >= 10 + buttonHeightActie + 10 &&
          y <= 10 + 2 * buttonHeightActie + 10) {
        onUpgrade();
        speelGeluid('audio/button_click.wav');
        return;
      }

      // Verkoop
      if (x >= startXActie && x <= startXActie + buttonWidthActie &&
          y >= 10 + 2 * (buttonHeightActie + 10) &&
          y <= 10 + 3 * buttonHeightActie + 20) {
        onVerkoop();
        speelGeluid('audio/button_click.wav');
        return;
      }
    }

    // Terug naar menu
    if (x >= 10 && x <= 10 + buttonWidthActie &&
        y >= size.y - buttonHeightActie - 10 &&
        y <= size.y - 10) {
      onTerugNaarMenu();
      speelGeluid('audio/button_click.wav');
      return;
    }

    // Modifiers aan/uit
    if (x >= 10 + buttonWidthActie + 10 &&
        x <= 10 + 2 * buttonWidthActie + 10 &&
        y >= size.y - buttonHeightActie - 10 &&
        y <= size.y - 10) {
      onToggleModifiers();
      speelGeluid('audio/button_click.wav');
      return;
    }

    // Geluid aan/uit
    if (x >= 10 + 2 * (buttonWidthActie + 10) &&
        x <= 10 + 3 * buttonWidthActie + 20 &&
        y >= size.y - buttonHeightActie - 10 &&
        y <= size.y - 10) {
      _geluidAan = !_geluidAan;
      onToggleGeluid();
      speelGeluid('audio/button_click.wav');
      return;
    }

    // Plaats toren (als er geld is en het geen pad-cel is)
    if (state.tePlaatsenType != null && state.geld >= TorenStats.van(state.tePlaatsenType!, 1).basisKosten) {
      state.plaatsToren(x, y);
      speelGeluid('audio/button_click.wav');
    }
  }
}