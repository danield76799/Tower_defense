
import 'package:flutter/material.dart';

import 'entities.dart';
import 'game_config.dart';
import 'game_state.dart';

/// Tekent het veld: gras, pad, torens, vijanden, projectielen, bereik-cirkels.
class GamePainter extends CustomPainter {
  final GameState state;
  final (double, double)? hoverCel; // cel onder vinger bij plaatsing

  GamePainter(this.state, this.hoverCel);

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / GameState.kolommen;
    final cellH = size.height / GameState.rijen;

    // Achtergrond: donker groen veld met subtiele ruiten.
    final veldPaint = Paint()..color = const Color(0xFF1E3A2A);
    canvas.drawRect(Offset.zero & size, veldPaint);
    final ruitPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke;
    for (var x = 0; x <= GameState.kolommen; x++) {
      canvas.drawLine(Offset(x * cellW, 0), Offset(x * cellW, size.height), ruitPaint);
    }
    for (var y = 0; y <= GameState.rijen; y++) {
      canvas.drawLine(Offset(0, y * cellH), Offset(size.width, y * cellH), ruitPaint);
    }

    // Pad: brede baan met donkerdere rand.
    final padPaint = Paint()
      ..color = const Color(0xFF8B7355)
      ..strokeWidth = cellW * 0.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final padRand = Paint()
      ..color = const Color(0xFF6B5344)
      ..strokeWidth = cellW * 0.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    var first = true;
    for (final (x, y) in levelPad) {
      final px = x * cellW;
      final py = y * cellH;
      if (first) {
        path.moveTo(px, py);
        first = false;
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, padRand);
    canvas.drawPath(path, padPaint);

    // Spawn / exit markers.
    _tekenMarker(canvas, levelPad.first, cellW, cellH, Colors.red.shade300, '→');
    _tekenMarker(canvas, levelPad.last, cellW, cellH, Colors.blue.shade300, '🏠');

    // Bereik-cirkel van geselecteerde toren of plaatsing-preview.
    if (state.geselecteerdeToren != null) {
      final t = state.geselecteerdeToren!;
      _tekenBereik(canvas, t.x, t.y, t.stats.bereik, cellW, cellH, Colors.white.withValues(alpha: 0.15));
    } else if (state.tePlaatsenType != null && hoverCel != null) {
      final stats = TorenStats.van(state.tePlaatsenType!, 1);
      final geldOk = state.geld >= stats.basisKosten;
      final kanHier = state.kanPlaatsen(hoverCel!.$1, hoverCel!.$2);
      final kleur = !geldOk
          ? Colors.red.withValues(alpha: 0.25)
          : kanHier
              ? Colors.green.withValues(alpha: 0.25)
              : Colors.red.withValues(alpha: 0.25);
      _tekenBereik(canvas, hoverCel!.$1, hoverCel!.$2, stats.bereik, cellW, cellH, kleur);
      // Ghost-toren.
      final cx = hoverCel!.$1 * cellW;
      final cy = hoverCel!.$2 * cellH;
      _tekenTorenLichaam(canvas, cx, cy, cellW, Colors.grey.withValues(alpha: 0.7), state.tePlaatsenType!);
    }

    // Torens.
    for (final t in state.torens) {
      final cx = t.x * cellW;
      final cy = t.y * cellH;
      final geselecteerd = state.geselecteerdeToren == t;
      if (geselecteerd) {
        canvas.drawCircle(
          Offset(cx, cy),
          cellW * 0.62,
          Paint()
            ..color = Colors.yellow.withValues(alpha: 0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      final kleur = switch (t.type) {
        TorenType.kanon => const Color(0xFFB85C4A),
        TorenType.ijs => const Color(0xFF5E9BD1),
        TorenType.sniper => const Color(0xFF7A5EA8),
      };
      _tekenTorenLichaam(canvas, cx, cy, cellW, kleur, t.type);
      // Level-pips.
      for (var i = 0; i < t.level; i++) {
        canvas.drawCircle(
          Offset(cx - cellW * 0.22 + i * cellW * 0.22, cy + cellW * 0.34),
          cellW * 0.06,
          Paint()..color = Colors.white,
        );
      }
    }

    // Vijanden.
    for (final v in state.vijanden) {
      final (px, py) = positieOpPad(v.afstand);
      final cx = px * cellW;
      final cy = py * cellH;
      final radius = switch (v.type) {
        VijandType.normaal => cellW * 0.26,
        VijandType.snel => cellW * 0.2,
        VijandType.tank => cellW * 0.36,
      };
      final kleur = switch (v.type) {
        VijandType.normaal => const Color(0xFFC94F4F),
        VijandType.snel => const Color(0xFFE0A83C),
        VijandType.tank => const Color(0xFF6E4A8E),
      };
      // Ijs-effect: blauwe halo.
      if (v.vertragingTijd > 0) {
        canvas.drawCircle(Offset(cx, cy), radius * 1.5, Paint()..color = Colors.cyan.withValues(alpha: 0.3));
      }
      canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = kleur);
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // HP-balkje.
      final hpFrac = (v.hp / v.hpMax).clamp(0.0, 1.0);
      final balkBreedte = radius * 2.4;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(cx, cy - radius - 6), width: balkBreedte, height: 4),
        Paint()..color = Colors.black.withValues(alpha: 0.5),
      );
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx - balkBreedte / 2 + balkBreedte * hpFrac / 2, cy - radius - 6),
          width: balkBreedte * hpFrac,
          height: 4,
        ),
        Paint()..color = hpFrac > 0.5 ? Colors.green : (hpFrac > 0.25 ? Colors.orange : Colors.red),
      );
    }

    // Projectielen.
    for (final p in state.projectielen) {
      final cx = p.x * cellW;
      final cy = p.y * cellH;
      final kleur = switch (p.type) {
        TorenType.kanon => Colors.yellow,
        TorenType.ijs => Colors.cyan,
        TorenType.sniper => Colors.purple,
      };
      canvas.drawCircle(Offset(cx, cy), cellW * 0.08, Paint()..color = kleur);
    }
  }

  void _tekenTorenLichaam(Canvas canvas, double cx, double cy, double cellW, Color kleur, TorenType type) {
    canvas.drawCircle(Offset(cx, cy), cellW * 0.36, Paint()..color = kleur);
    canvas.drawCircle(
      Offset(cx, cy),
      cellW * 0.36,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Loop/loopje richting: klein donkerder binnen-cirkel.
    canvas.drawCircle(Offset(cx, cy), cellW * 0.18, Paint()..color = kleur.withValues(alpha: 0.6));
  }

  void _tekenBereik(Canvas canvas, double cx, double cy, double bereik, double cellW, double cellH, Color kleur) {
    canvas.drawCircle(Offset(cx * cellW, cy * cellH), bereik * cellW, Paint()..color = kleur);
  }

  void _tekenMarker(Canvas canvas, (double, double) cel, double cellW, double cellH, Color kleur, String label) {
    final cx = cel.$1 * cellW;
    final cy = cel.$2 * cellH;
    canvas.drawCircle(Offset(cx, cy), cellW * 0.3, Paint()..color = kleur.withValues(alpha: 0.4));
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(fontSize: 18)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - textPainter.width / 2, cy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}