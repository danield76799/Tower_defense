import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Voortgang per level: sterren (0-3) en highscore.
class LevelVoortgang {
  final String levelId;
  final int sterren;
  final int highscore;

  const LevelVoortgang({
    required this.levelId,
    required this.sterren,
    required this.highscore,
  });
}

/// Bewaart lees voortgang in SharedPreferences (offline, per device).
class ProgressService {
  static const _key = 'tower_defense_voortgang_v1';

  static Future<Map<String, LevelVoortgang>> laad() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
            k,
            LevelVoortgang(
              levelId: k,
              sterren: (v['sterren'] as num?)?.toInt() ?? 0,
              highscore: (v['highscore'] as num?)?.toInt() ?? 0,
            ),
          ));
    } catch (_) {
      return {};
    }
  }

  /// Registreert een winst: bewaar de beste sterren + de hoogste score.
  static Future<void> registreerWinst({
    required String levelId,
    required int sterren,
    required int score,
  }) async {
    final huidig = await laad();
    final oude = huidig[levelId];
    final nieuwe = LevelVoortgang(
      levelId: levelId,
      sterren: sterren > (oude?.sterren ?? 0) ? sterren : (oude?.sterren ?? 0),
      highscore: score > (oude?.highscore ?? 0) ? score : (oude?.highscore ?? 0),
    );
    huidig[levelId] = nieuwe;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({
      for (final e in huidig.entries)
        e.key: {'sterren': e.value.sterren, 'highscore': e.value.highscore},
    }));
  }
}