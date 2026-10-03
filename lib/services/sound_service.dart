import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Geluidseffecten voor de game. Genereert tonen via sinustonen
/// (geen asset-bestanden nodig) — simpel 8-bit-achtig retro-gevoel.
enum SoundEffect {
  plaats, // toren geplaatst
  upgrade,
  golfStart,
  levenKwijt,
  winst,
  verlies,
}

class SoundService {
  final AudioPlayer _player = AudioPlayer();
  bool _muted = false; // standaard AAN; voorkeur wordt bewaard in prefs

  bool setMuted(bool muted) => _muted = muted;
  bool get muted => _muted;

  void speel(SoundEffect effect) {
    if (_muted) return;
    switch (effect) {
      case SoundEffect.plaats:
        _speelTonen([520, 660], [0.07, 0.07]);
      case SoundEffect.upgrade:
        _speelTonen([420, 560, 700], [0.08, 0.08, 0.11]);
      case SoundEffect.golfStart:
        _speelTonen([300, 380, 480], [0.1, 0.1, 0.15]);
      case SoundEffect.levenKwijt:
        _speelTonen([220, 160], [0.12, 0.16]);
      case SoundEffect.winst:
        _speelTonen([520, 660, 780, 1040], [0.12, 0.12, 0.12, 0.25]);
      case SoundEffect.verlies:
        _speelTonen([330, 260, 190, 130], [0.16, 0.16, 0.2, 0.3]);
    }
  }

  /// Speelt een reeks tonen achter elkaar (frequentie Hz + duur s).
  void _speelTonen(List<int> frequenties, List<double> duur) {
    for (var i = 0; i < frequenties.length; i++) {
      _player.play(BytesSource(_wavBytes(frequenties[i], duur[i])));
    }
  }

  /// Genereert een mono PCM WAV-buffer met een sinustoon + envelope.
  Uint8List _wavBytes(int freqHz, double secDuur) {
    const sampleRate = 22050;
    final n = (sampleRate * secDuur).round();
    final data = BytesBuilder();
    for (var i = 0; i < n; i++) {
      const piek = 0.45;
      final t = i / sampleRate;
      const fade = 0.015;
      var amp = piek;
      if (t < fade) amp *= t / fade;
      if (t > secDuur - fade) amp *= (secDuur - t) / fade;
      final sample = (math.sin(2 * math.pi * freqHz * t) * amp * 32767).round();
      data.addByte(sample & 0xFF);
      data.addByte((sample >> 8) & 0xFF);
    }
    final pcm = data.takeBytes();
    // WAV-header (PCM 16-bit mono).
    final header = BytesBuilder();
    header.add([0x52, 0x49, 0x46, 0x46]); // 'RIFF'
    _le32(header, 36 + pcm.length);
    header.add([0x57, 0x41, 0x56, 0x45]); // 'WAVE'
    header.add([0x66, 0x6D, 0x74, 0x20]); // 'fmt '
    _le32(header, 16); // fmt-chunk size
    _le16(header, 1); // PCM
    _le16(header, 1); // mono
    _le32(header, sampleRate);
    _le32(header, sampleRate * 2); // byte rate
    _le16(header, 2); // block align
    _le16(header, 16); // bits per sample
    header.add([0x64, 0x61, 0x74, 0x61]); // 'data'
    _le32(header, pcm.length);
    return Uint8List.fromList([...header.toBytes(), ...pcm]);
  }

  void _le32(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  void _le16(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);

  void sluit() {
    _player.dispose();
  }
}