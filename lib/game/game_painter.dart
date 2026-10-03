import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'entities.dart';
import 'game_config.dart';
import 'game_state.dart';

/// Tekent het veld in Bloons TD-cartoonstijl:
/// - gras + zandpad (zoals eerder)
/// - bloons als glanzende ballonnen met lagen (zebra/regenboog/keramiek apart)
/// - MOAB als blimp met vinnen + HP-balk
/// - torens als monkeys met type-hoofdband (dart/tack/ijs/gif/bom/sniper/bliksem)
/// - projectielen: darts, spijkers, bommen, zigzag-bliksem
class GamePainter extends CustomPainter {
  final GameState state;
  final (double, double)? hoverCel;

  GamePainter(this.state, this.hoverCel);

  // Vaste pseudo-random-volgorde zodat decoraties NIET flikkeren per frame.
  static final _rng = math.Random(42);
  static final _decoratie = List.generate(90, (_) => (
    _rng.nextDouble() * GameState.kolommen,
    _rng.nextDouble() * GameState.rijen,
    _rng.nextDouble(),
  ));

  static const _regenboogKleuren = [
    Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835),
    Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / GameState.kolommen;
    final ch = size.height / GameState.rijen;

    _tekenGras(canvas, size, cw, ch);
    _tekenPad(canvas, cw, ch);
    _tekenSpawnExit(canvas, cw, ch);

    for (final t in state.torens) {
      _tekenToren(canvas, t, cw, ch);
    }

    if (state.geselecteerdeToren == null &&
        state.tePlaatsenType != null &&
        hoverCel != null) {
      _tekenPlaatsPreview(canvas, cw, ch);
    }

    for (final p in state.projectielen) {
      _tekenProjectiel(canvas, p, cw, ch);
    }

    for (final v in state.vijanden) {
      _tekenBloon(canvas, v, cw, ch);
    }
  }

  // ---------------- gras ----------------
  void _tekenGras(Canvas canvas, Size size, double cw, double ch) {
    // Basis: fris grasgroen (CoC-achtig, helder).
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF63B14E),
    );

    // Donkerder checkerboard-ruiten.
    final donker = Paint()..color = const Color(0xFF58A346).withValues(alpha: 0.55);
    for (var x = 0; x < GameState.kolommen; x++) {
      for (var y = 0; y < GameState.rijen; y++) {
        if ((x + y) % 2 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x * cw, y * ch, cw, ch),
            donker,
          );
        }
      }
    }

    // Vignette voor diepte (licht boven, donker onder).
    final vignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.07),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.10),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    // Grasbosjes.
    final bos = Paint()
      ..color = const Color(0xFF3D8B33)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy, v) in _decoratie) {
      final px = dx * cw;
      final py = dy * ch;
      if (state.isPadCel(dx, dy)) continue;
      final h = 3.0 + v * 3.0;
      canvas.drawLine(Offset(px, py), Offset(px - 2, py - h), bos);
      canvas.drawLine(Offset(px, py), Offset(px, py - h * 1.25), bos);
      canvas.drawLine(Offset(px, py), Offset(px + 2, py - h), bos);
    }

    // Bloemetjes (wit/geel).
    for (var i = 0; i < _decoratie.length; i += 7) {
      final (dx, dy, v) = _decoratie[i];
      if (state.isPadCel(dx, dy)) continue;
      final px = dx * cw;
      final py = dy * ch;
      canvas.drawCircle(
        Offset(px, py),
        1.6 + v,
        Paint()..color = v > 0.5 ? Colors.white : const Color(0xFFFFE082),
      );
      canvas.drawCircle(
        Offset(px, py),
        0.7,
        Paint()..color = const Color(0xFFF9A825),
      );
    }
  }

  // ---------------- pad ----------------
  void _tekenPad(Canvas canvas, double cw, double ch) {
    final path = Path();
    var first = true;
    for (final (x, y) in state.pad) {
      final px = x * cw;
      final py = y * ch;
      if (first) {
        path.moveTo(px, py);
        first = false;
      } else {
        path.lineTo(px, py);
      }
    }

    // Donkerbruine rand.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8A6844)
        ..strokeWidth = cw * 0.82
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Zandbaan.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD9B779)
        ..strokeWidth = cw * 0.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Lichte middenstreep.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE8CE92).withValues(alpha: 0.5)
        ..strokeWidth = cw * 0.34
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Steentjes.
    final steen = Paint()..color = const Color(0xFFB39B6B);
    final steenDonker = Paint()..color = const Color(0xFF9C8558);
    var i = 0;
    for (var seg = 0; seg < state.pad.length - 1; seg++) {
      final (x1, y1) = state.pad[seg];
      final (x2, y2) = state.pad[seg + 1];
      for (var f = 0.15; f < 1.0; f += 0.22) {
        i++;
        final px = (x1 + (x2 - x1) * f) * cw;
        final py = (y1 + (y2 - y1) * f) * ch + (i % 2 == 0 ? cw * 0.16 : -cw * 0.18);
        canvas.drawCircle(Offset(px, py), 1.8 + (i % 3), i % 2 == 0 ? steen : steenDonker);
      }
    }
  }

  void _tekenSpawnExit(Canvas canvas, double cw, double ch) {
    final (sx, sy) = state.pad.first;
    final (ex, ey) = state.pad.last;

    // Spawn: rood portaal.
    final sxPx = sx * cw;
    final syPx = sy * ch;
    canvas.drawCircle(
      Offset(sxPx, syPx),
      cw * 0.42,
      Paint()..color = Colors.red.withValues(alpha: 0.25),
    );
    canvas.drawCircle(Offset(sxPx, syPx), cw * 0.3, Paint()..color = const Color(0xFFB71C1C));
    canvas.drawCircle(
      Offset(sxPx, syPx),
      cw * 0.3,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _tekst(canvas, '⚔️', sxPx, syPx, 15);

    // Exit: huisje (basis).
    final exPx = ex * cw;
    final eyPx = ey * ch;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(exPx + 2.5, eyPx + ch * 0.28),
        width: cw * 0.7,
        height: ch * 0.3,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );
    final muur = Rect.fromLTWH(exPx - cw * 0.34, eyPx - ch * 0.12, cw * 0.68, ch * 0.52);
    canvas.drawRect(muur, Paint()..color = const Color(0xFFBCAAA4));
    final dak = Path()
      ..moveTo(exPx - cw * 0.4, eyPx - ch * 0.1)
      ..lineTo(exPx, eyPx - ch * 0.45)
      ..lineTo(exPx + cw * 0.4, eyPx - ch * 0.1)
      ..close();
    canvas.drawPath(dak, Paint()..color = const Color(0xFFAD5A45));
    _tekst(canvas, '🏠', exPx, eyPx + 2, 15);
  }

  // ---------------- toren ----------------
  void _tekenToren(Canvas canvas, Toren t, double cw, double ch) {
    final cx = t.x * cw;
    final cy = t.y * ch;

    if (state.geselecteerdeToren == t) {
      canvas.drawCircle(
        Offset(cx, cy),
        cw * 0.55,
        Paint()
          ..color = Colors.yellow.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2,
      );
    }

    final bandKleur = switch (t.type) {
      TorenType.dart => const Color(0xFFB85C4A),
      TorenType.tack => const Color(0xFFFF7043),
      TorenType.ijs => const Color(0xFF4FA3D1),
      TorenType.gif => const Color(0xFF7CB342),
      TorenType.bom => const Color(0xFF37474F),
      TorenType.sniper => const Color(0xFF8B6BC7),
      TorenType.bliksem => const Color(0xFFFFD600),
    };
    const donker = Color(0xFF5D4037);
    const licht = Color(0xFF8D6E63);

    // Grondschaduw.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + cw * 0.06, cy + ch * 0.3),
        width: cw * 0.78,
        height: ch * 0.34,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    // Basis/platform.
    final basis = Rect.fromCenter(
      center: Offset(cx, cy + ch * 0.1),
      width: cw * 0.72,
      height: ch * 0.62,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(basis, const Radius.circular(5)),
      Paint()..color = donker,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(basis.deflate(2.4), const Radius.circular(4)),
      Paint()..color = licht,
    );

    // Monkey-kopje.
    final torenR = cw * 0.3;
    final torenCx = cx;
    final torenCy = cy - ch * 0.05;
    canvas.drawCircle(Offset(torenCx, torenCy), torenR, Paint()..color = donker);
    canvas.drawCircle(Offset(torenCx, torenCy), torenR - 2.4, Paint()..color = licht);
    // Beige bek-strook.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(torenCx, torenCy + torenR * 0.42),
        width: torenR * 0.95,
        height: torenR * 0.55,
      ),
      Paint()..color = const Color(0xFFD7CCC8),
    );
    // Oogjes.
    canvas.drawCircle(Offset(torenCx - torenR * 0.32, torenCy - torenR * 0.15),
        torenR * 0.13, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(torenCx + torenR * 0.32, torenCy - torenR * 0.15),
        torenR * 0.13, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(torenCx - torenR * 0.32, torenCy - torenR * 0.15),
        torenR * 0.06, Paint()..color = Colors.black);
    canvas.drawCircle(Offset(torenCx + torenR * 0.32, torenCy - torenR * 0.15),
        torenR * 0.06, Paint()..color = Colors.black);
    // Hoofdband in type-kleur.
    canvas.drawCircle(
      Offset(torenCx, torenCy),
      torenR + 1,
      Paint()
        ..color = bandKleur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4,
    );

    // Draaiend loopje.
    final richting = t.loopRichting;
    final loopLengte = cw * (t.type == TorenType.sniper ? 0.55 : 0.42);
    final loopDikte = cw * (t.type == TorenType.sniper ? 0.11 : 0.15);
    final loopX = torenCx + math.cos(richting) * loopLengte;
    final loopY = torenCy + math.sin(richting) * loopLengte;

    switch (t.type) {
      case TorenType.ijs:
        // Kristal-bol die zacht knippert.
        final knipoog = (math.sin(t.animTijd * 3) + 1) / 2;
        canvas.drawCircle(
          Offset(torenCx, torenCy - 2),
          torenR * 0.48,
          Paint()
            ..color = Color.lerp(const Color(0xFFB3E5FC), Colors.white, knipoog * 0.5)!,
        );
      case TorenType.bliksem:
        // Tesla-coil: bol + fonkelende vonken.
        canvas.drawCircle(
          Offset(torenCx, torenCy - 2),
          torenR * 0.42,
          Paint()..color = const Color(0xFFFFF59D),
        );
        for (var i = 0; i < 3; i++) {
          final hoek = t.animTijd * 5 + i * 2.1;
          canvas.drawLine(
            Offset(torenCx, torenCy - 2),
            Offset(
              torenCx + math.cos(hoek) * torenR * 0.9,
              torenCy - 2 + math.sin(hoek) * torenR * 0.9,
            ),
            Paint()
              ..color = Colors.yellowAccent.withValues(alpha: 0.75)
              ..strokeWidth = 1.4,
          );
        }
      case TorenType.gif:
        // Gifkolf met bobbeltjes.
        canvas.drawCircle(
          Offset(torenCx, torenCy - 2),
          torenR * 0.42,
          Paint()..color = const Color(0xFF9CCC65),
        );
        for (var i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(torenCx - torenR * 0.2 + i * torenR * 0.2, torenCy - 4 - (i % 2) * 3),
            2.0,
            Paint()..color = const Color(0xFF558B2F),
          );
        }
      case TorenType.tack:
        // 8 spijkerstompen in een cirkel.
        for (var i = 0; i < 8; i++) {
          final hoek = i * math.pi / 4 + t.animTijd * 0.3;
          canvas.drawLine(
            Offset(torenCx + math.cos(hoek) * torenR * 0.6,
                torenCy + math.sin(hoek) * torenR * 0.6),
            Offset(torenCx + math.cos(hoek) * torenR * 1.0,
                torenCy + math.sin(hoek) * torenR * 1.0),
            Paint()
              ..color = const Color(0xFFFF8A65)
              ..strokeWidth = 2.6
              ..strokeCap = StrokeCap.round,
          );
        }
      case TorenType.bom:
        // Zwarte bom-bal.
        canvas.drawCircle(Offset(loopX, loopY), cw * 0.13, Paint()..color = const Color(0xFF263238));
        canvas.drawCircle(
          Offset(loopX - cw * 0.04, loopY - cw * 0.04),
          cw * 0.04,
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );
      default:
        canvas.drawLine(
          Offset(torenCx, torenCy),
          Offset(loopX, loopY),
          Paint()
            ..color = donker
            ..strokeWidth = loopDikte * 1.7
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(torenCx, torenCy),
          Offset(loopX, loopY),
          Paint()
            ..color = bandKleur
            ..strokeWidth = loopDikte
            ..strokeCap = StrokeCap.round,
        );
    }

    // Muzzle-flits.
    if (t.schietFlits > 0) {
      final flitsR = cw * 0.16 * t.schietFlits;
      canvas.drawCircle(
        Offset(loopX, loopY),
        flitsR,
        Paint()..color = Colors.orange.withValues(alpha: 0.85 * t.schietFlits),
      );
      canvas.drawCircle(
        Offset(loopX, loopY),
        flitsR * 0.5,
        Paint()..color = Colors.yellow.withValues(alpha: t.schietFlits),
      );
    }

    // Niveau-vlaggetje.
    final vlagX = cx + cw * 0.3;
    final vlagY = cy - ch * 0.32;
    canvas.drawLine(
      Offset(vlagX, vlagY + ch * 0.16),
      Offset(vlagX, vlagY - ch * 0.1),
      Paint()
        ..color = const Color(0xFF5D4037)
        ..strokeWidth = 1.6,
    );
    canvas.drawPath(
      Path()
        ..moveTo(vlagX, vlagY - ch * 0.1)
        ..lineTo(vlagX + cw * 0.16, vlagY - ch * 0.05)
        ..lineTo(vlagX, vlagY),
      Paint()..color = Colors.amber.shade600,
    );

    // Level-sterren.
    for (var s = 0; s < t.level; s++) {
      _ster(canvas, cx - cw * 0.2 + s * cw * 0.2, cy + ch * 0.34, cw * 0.075);
    }
  }

  void _ster(Canvas canvas, double cx, double cy, double r) {
    final pad = Path();
    for (var i = 0; i < 5; i++) {
      final hb = -math.pi / 2 + i * 2 * math.pi / 5;
      final hi = hb + math.pi / 5;
      final bx = cx + math.cos(hb) * r;
      final by = cy + math.sin(hb) * r;
      final ix = cx + math.cos(hi) * r * 0.45;
      final iy = cy + math.sin(hi) * r * 0.45;
      if (i == 0) {
        pad.moveTo(bx, by);
      } else {
        pad.lineTo(bx, by);
      }
      pad.lineTo(ix, iy);
    }
    pad.close();
    canvas.drawPath(pad, Paint()..color = const Color(0xFFFFD54F));
  }

  void _tekenPlaatsPreview(Canvas canvas, double cw, double ch) {
    final (cx, cy) = hoverCel!;
    final type = state.tePlaatsenType!;
    final stats = TorenStats.van(type, 1);
    final betaalbaar = state.geld >= stats.basisKosten;
    final kanHier = state.kanPlaatsen(cx, cy);
    final ok = betaalbaar && kanHier;

    final kleur = ok ? Colors.green : Colors.red;
    canvas.drawCircle(
      Offset(cx * cw, cy * ch),
      stats.bereik * cw,
      Paint()..color = kleur.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      Offset(cx * cw, cy * ch),
      stats.bereik * cw,
      Paint()
        ..color = kleur.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    // Ghost-toren (half-transparent): teken op saveLayer.
    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: 0.62),
    );
    _tekenToren(canvas, Toren(type, cx, cy), cw, ch);
    canvas.restore();
  }

  // ---------------- projectiel ----------------
  void _tekenProjectiel(Canvas canvas, Projectiel p, double cw, double ch) {
    final px = p.x * cw;
    final py = p.y * ch;
    final sx = p.vorigeX * cw;
    final sy = p.vorigeY * ch;

    switch (p.type) {
      case TorenType.dart:
        const kleur = Color(0xFFE65100);
        canvas.drawLine(
          Offset(sx, sy),
          Offset(px, py),
          Paint()
            ..color = kleur
            ..strokeWidth = cw * 0.07
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(Offset(px, py), cw * 0.055, Paint()..color = kleur);
      case TorenType.tack:
        canvas.drawLine(
          Offset(sx, sy),
          Offset(px, py),
          Paint()
            ..color = const Color(0xFFFF8A65)
            ..strokeWidth = cw * 0.05
            ..strokeCap = StrokeCap.round,
        );
      case TorenType.bom:
        canvas.drawCircle(Offset(px, py), cw * 0.11, Paint()..color = const Color(0xFF263238));
        canvas.drawCircle(
          Offset(px - cw * 0.035, py - cw * 0.035),
          cw * 0.035,
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );
      case TorenType.gif:
        canvas.drawCircle(Offset(px, py), cw * 0.09, Paint()..color = const Color(0xFF8BC34A));
        canvas.drawCircle(
          Offset(px - cw * 0.03, py - cw * 0.03),
          cw * 0.03,
          Paint()..color = Colors.white.withValues(alpha: 0.8),
        );
      case TorenType.bliksem:
        final zigzag = Path()
          ..moveTo(sx, sy)
          ..lineTo(sx + (px - sx) * 0.3, sy + (py - sy) * 0.3 - cw * 0.08)
          ..lineTo(sx + (px - sx) * 0.6, sy + (py - sy) * 0.6 + cw * 0.08)
          ..lineTo(px, py);
        canvas.drawPath(
          zigzag,
          Paint()
            ..color = Colors.yellowAccent
            ..strokeWidth = cw * 0.05
            ..style = PaintingStyle.stroke,
        );
      default:
        canvas.drawLine(
          Offset(sx, sy),
          Offset(px, py),
          Paint()
            ..color = const Color(0xFFB388FF)
            ..strokeWidth = cw * 0.04
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(Offset(px, py), cw * 0.04, Paint()..color = const Color(0xFFB388FF));
    }
  }

  // ---------------- bloon ----------------
  void _tekenBloon(Canvas canvas, Vijand v, double cw, double ch) {
    final (px, py) = positieOpPad(state.pad, v.afstand);
    final cx = px * cw;
    final cy = py * ch;
    final st = v.stats;

    if (st.stijl == BloonStijl.moab) {
      _tekenMoab(canvas, v, cx, cy, cw, ch);
      return;
    }

    // Grondschaduw.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + ch * 0.16),
        width: cw * 0.42,
        height: ch * 0.16,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );

    // Hoppeltje.
    final hop = math.sin(v.fase * math.pi).abs() * ch * 0.06;
    final cy2 = cy - hop;

    final hoofdR = cw *
        switch (st.stijl) {
          BloonStijl.regenboog || BloonStijl.zebra => 0.3,
          _ => 0.26,
        };

    // Gif-bellen.
    if (v.gifTijd > 0) {
      for (var i = 0; i < 2; i++) {
        final bubbelH = (v.fase * 0.25 + i * 0.5) % 1.0;
        canvas.drawCircle(
          Offset(cx + (i == 0 ? -hoofdR * 0.5 : hoofdR * 0.4),
              cy2 - bubbelH * hoofdR * 1.6),
          2.0 + i,
          Paint()..color = const Color(0xFF8BC34A).withValues(alpha: 0.6 - bubbelH * 0.4),
        );
      }
    }

    // Ijs-halo.
    if (v.vertragingTijd > 0) {
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(cx, cy2),
          hoofdR * (1.3 + i * 0.25),
          Paint()..color = Colors.cyan.withValues(alpha: 0.16 - i * 0.04),
        );
      }
    }

    // Ballon-lichaam per stijl.
    if (st.stijl == BloonStijl.regenboog) {
      // Concentrische regenboog-ringen.
      var idx = 0;
      for (var i = _regenboogKleuren.length - 1; i >= 0; i--) {
        idx++;
        canvas.drawCircle(
          Offset(cx, cy2),
          hoofdR * (idx / _regenboogKleuren.length),
          Paint()..color = _regenboogKleuren[i],
        );
      }
      canvas.drawCircle(
        Offset(cx, cy2),
        hoofdR,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    } else if (st.stijl == BloonStijl.zebra) {
      canvas.drawCircle(Offset(cx, cy2), hoofdR, Paint()..color = const Color(0xFF212121));
      canvas.save();
      canvas.clipPath(Path()
        ..addOval(Rect.fromCircle(center: Offset(cx, cy2), radius: hoofdR)));
      final wit = Paint()..color = Colors.white;
      for (var i = -1; i <= 1; i++) {
        canvas.drawRect(
          Rect.fromLTWH(cx - hoofdR + (i + 1.5) * hoofdR * 0.66, cy2 - hoofdR,
              hoofdR * 0.3, hoofdR * 2),
          wit,
        );
      }
      canvas.restore();
    } else {
      canvas.drawCircle(Offset(cx, cy2), hoofdR, Paint()..color = st.kleur);
      canvas.drawCircle(
        Offset(cx, cy2),
        hoofdR,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        Offset(cx - hoofdR * 0.32, cy2 - hoofdR * 0.34),
        hoofdR * 0.22,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }

    // Keramiek: barstjes bij HP-verlies.
    if (v.type == BloonType.keramiek) {
      final frac = (v.hp / v.hpMax).clamp(0.0, 1.0);
      if (frac < 0.99) {
        final barst = Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.3
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(cx - hoofdR * 0.5, cy2 - hoofdR * 0.3),
            Offset(cx - hoofdR * 0.1, cy2 + hoofdR * 0.1), barst);
        if (frac < 0.6) {
          canvas.drawLine(Offset(cx + hoofdR * 0.2, cy2 - hoofdR * 0.5),
              Offset(cx + hoofdR * 0.55, cy2 + hoofdR * 0.05), barst);
        }
        if (frac < 0.3) {
          canvas.drawLine(Offset(cx - hoofdR * 0.3, cy2 + hoofdR * 0.4),
              Offset(cx + hoofdR * 0.3, cy2 + hoofdR * 0.55), barst);
        }
      }
    }

    // HP-balkje alleen bij meerlagige bloons.
    if (st.hp > 1) {
      final hpFrac = (v.hp / v.hpMax).clamp(0.0, 1.0);
      final balkBreedte = hoofdR * 2.2;
      final balkY = cy2 - hoofdR - ch * 0.14;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, balkY), width: balkBreedte, height: 4),
          const Radius.circular(2),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.55),
      );
      final hpKleur =
          hpFrac > 0.5 ? Colors.green : (hpFrac > 0.25 ? Colors.orange : Colors.red);
      if (hpFrac > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(cx - balkBreedte / 2 + balkBreedte * hpFrac / 2, balkY),
              width: (balkBreedte - 1) * hpFrac,
              height: 3,
            ),
            const Radius.circular(1.5),
          ),
          Paint()..color = hpKleur,
        );
      }
    }
  }

  void _tekenMoab(Canvas canvas, Vijand v, double cx, double cy, double cw, double ch) {
    // MOAB: blimp-lichaam met vinnen, rood streep en HP-balk.
    final breedte = cw * 1.5;
    final hoogte = ch * 0.75;
    final hoek = _moabRichting(state.pad, v.afstand);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(hoek);

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, hoogte * 0.75), width: breedte, height: hoogte * 0.4),
      Paint()..color = Colors.black.withValues(alpha: 0.25),
    );

    final romp = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 0), width: breedte, height: hoogte),
      Radius.circular(hoogte / 2),
    );
    canvas.drawRRect(romp, Paint()..color = const Color(0xFF37474F));
    canvas.drawRRect(romp.deflate(2.5), Paint()..color = const Color(0xFF546E7A));
    canvas.drawRect(
      Rect.fromCenter(center: Offset(0, 0), width: breedte - 12, height: hoogte * 0.22),
      Paint()..color = const Color(0xFFB71C1C),
    );
    canvas.drawCircle(Offset(breedte / 2, 0), hoogte * 0.22, Paint()..color = const Color(0xFF263238));
    for (final sgn in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(-breedte / 2 + 4, 0)
          ..lineTo(-breedte / 2 - 8, sgn * hoogte * 0.55)
          ..lineTo(-breedte / 2 + 10, sgn * hoogte * 0.18)
          ..close(),
        Paint()..color = const Color(0xFF263238),
      );
    }

    // HP-balk.
    final hpFrac = (v.hp / v.hpMax).clamp(0.0, 1.0);
    final balkBreedte = breedte;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -hoogte * 0.9), width: balkBreedte, height: 6),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    final hpKleur =
        hpFrac > 0.5 ? Colors.green : (hpFrac > 0.25 ? Colors.orange : Colors.red);
    if (hpFrac > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-balkBreedte / 2 + balkBreedte * hpFrac / 2, -hoogte * 0.9),
            width: (balkBreedte - 1.5) * hpFrac,
            height: 4.6,
          ),
          const Radius.circular(2.3),
        ),
        Paint()..color = hpKleur,
      );
    }

    canvas.restore();
  }

  double _moabRichting(List<(double, double)> pad, double afstand) {
    const epsilon = 0.1;
    final (x1, y1) = positieOpPad(pad, math.max(0.0, afstand - epsilon));
    final (x2, y2) = positieOpPad(pad, afstand + epsilon);
    return math.atan2(y2 - y1, x2 - x1);
  }

  void _tekst(Canvas canvas, String label, double cx, double cy, double size) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: TextStyle(fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}