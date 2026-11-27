import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/habit_models.dart';

enum ChimeKind { done, step, undo, grand }

class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();
  static const MethodChannel _audioChannel =
      MethodChannel('app.xhabit.tracker/audio');
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Uint8List> _pcmCache = {};
  String? _lastPath;

  Future<void> play(
    ChimeKind kind, {
    required bool enabled,
    required SoundProfile profile,
  }) async {
    if (!enabled) return;

    final cacheKey = '${kind.name}_${profile.name}';
    final pcm = _pcmCache.putIfAbsent(
      cacheKey,
      () => _synthesizePcm(kind, profile),
    );

    if (Platform.isAndroid) {
      try {
        final ok = await _audioChannel.invokeMethod<bool>('playPcm', {
          'key': cacheKey,
          'pcm': pcm,
          'sampleRate': 44100,
        });
        if (ok == true) return;
      } catch (_) {
        // Fall back safely to WAV file playback if channel is unavailable.
      }
    }

    try {
      final tmp = await getTemporaryDirectory();
      final wavFile = File('${tmp.path}/xhabit_chime_v3_$cacheKey.wav');
      if (!await wavFile.exists()) {
        await wavFile.writeAsBytes(_wrapWav(pcm, 44100), flush: true);
      }
      if (_lastPath == wavFile.path) {
        await _player.pause();
        await _player.seek(Duration.zero);
      } else {
        await _player.setFilePath(wavFile.path);
        _lastPath = wavFile.path;
      }
      await _player.play();
    } catch (_) {
      // Fallback safely if audio device is unavailable (e.g. headless test).
    }
  }

  /// Exact Web Audio `OscillatorNode` + `BiquadFilter(lowpass, Q=1)` synthesizer matching `index.html`.
  Uint8List _synthesizePcm(ChimeKind kind, SoundProfile profile) {
    const sampleRate = 44100;
    final notes = _notesFor(kind, profile);
    final endMs = notes.fold<int>(
      110,
      (m, n) => math.max(m, n.delayMs + n.durMs + 45),
    );
    final totalSamples = (endMs * sampleRate) ~/ 1000;
    final mix = Float64List(totalSamples);

    for (final n in notes) {
      final startIdx = (n.delayMs * sampleRate) ~/ 1000;
      final len = math.max(1, (n.durMs * sampleRate) ~/ 1000);
      final attackSamples = math.max(1, (0.005 * sampleRate).round());
      final tailSamples = math.max(1, (0.008 * sampleRate).round());
      final f0 = n.f0;
      final f1 = math.max(40.0, n.f1);
      final glideSamples = math.max(1, (len * 0.72).round());
      final expRatio = 0.0001 / math.max(0.001, n.vol);
      var phase = 0.0;

      for (var i = 0; i < len; i++) {
        final gFrac = (i / glideSamples).clamp(0.0, 1.0);
        final freq = f0 * math.pow(f1 / f0, gFrac);
        phase += 2.0 * math.pi * freq / sampleRate;

        final osc = n.triangle
            ? (2.0 / math.pi) * math.asin(math.sin(phase))
            : math.sin(phase);

        // Linear attack (5ms) + exponential decay (vol -> 0.0001 at dur)
        double env;
        if (i < attackSamples) {
          env = 0.0001 + (n.vol - 0.0001) * (i / attackSamples);
        } else {
          final decDenom = math.max(1, len - attackSamples);
          final decFrac = ((i - attackSamples) / decDenom).clamp(0.0, 1.0);
          env = n.vol * math.pow(expRatio, decFrac);
        }
        if ((len - i) < tailSamples) {
          env *= math.max(0.0, (len - i) / tailSamples);
        }

        final idx = startIdx + i;
        if (idx < mix.length) {
          mix[idx] += osc * env;
        }
      }
    }

    // 2nd-order RBJ low-pass biquad (Q = 1.0) matching Web Audio BiquadFilterNode
    final cutoffHz = switch (profile) {
      SoundProfile.wood => 1150.0,
      SoundProfile.drop => 2400.0,
      _ => 1850.0,
    };
    const q = 1.0;
    final w0 = 2.0 * math.pi * cutoffHz / sampleRate;
    final sinW0 = math.sin(w0);
    final cosW0 = math.cos(w0);
    final alpha = sinW0 / (2.0 * q);
    final a0 = 1.0 + alpha;
    final b0 = ((1.0 - cosW0) * 0.5) / a0;
    final b1 = (1.0 - cosW0) / a0;
    final b2 = b0;
    final a1 = (-2.0 * cosW0) / a0;
    final a2 = (1.0 - alpha) / a0;

    var x1 = 0.0;
    var x2 = 0.0;
    var y1 = 0.0;
    var y2 = 0.0;

    final out = ByteData(totalSamples * 2);
    // Clean linear headroom (max ~0.18 full-scale -> crisp without speaker buzz)
    const masterGain = 2.1;
    for (var i = 0; i < totalSamples; i++) {
      final x0 = mix[i];
      final y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
      x2 = x1;
      x1 = x0;
      y2 = y1;
      y1 = y0;
      final scaled = (y0 * masterGain).clamp(-0.80, 0.80);
      out.setInt16(i * 2, (scaled * 32767).round(), Endian.little);
    }
    return out.buffer.asUint8List();
  }

  Uint8List _wrapWav(Uint8List pcmBytes, int sampleRate) {
    final wav = Uint8List(44 + pcmBytes.length);
    final bd = ByteData.sublistView(wav);
    void writeAscii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        bd.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    bd.setUint32(4, 36 + pcmBytes.length, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, 1, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * 2, Endian.little);
    bd.setUint16(32, 2, Endian.little);
    bd.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    bd.setUint32(40, pcmBytes.length, Endian.little);
    wav.setRange(44, wav.length, pcmBytes);
    return wav;
  }

  List<_ToneSpec> _notesFor(ChimeKind kind, SoundProfile profile) {
    if (kind == ChimeKind.undo) {
      return switch (profile) {
        SoundProfile.minimal => const [_ToneSpec(360, 220, 24, 0.032, 0, true)],
        SoundProfile.wood => const [_ToneSpec(250, 170, 36, 0.038, 0, false)],
        SoundProfile.drop => const [_ToneSpec(430, 290, 40, 0.035, 0, false)],
        SoundProfile.pop => const [_ToneSpec(300, 190, 34, 0.036, 0, false)],
      };
    }
    if (kind == ChimeKind.step) {
      return switch (profile) {
        SoundProfile.minimal => const [_ToneSpec(760, 620, 18, 0.030, 0, true)],
        SoundProfile.wood => const [_ToneSpec(480, 440, 35, 0.042, 0, false)],
        SoundProfile.drop => const [_ToneSpec(680, 880, 38, 0.040, 0, false)],
        SoundProfile.pop => const [_ToneSpec(480, 640, 28, 0.045, 0, false)],
      };
    }
    if (kind == ChimeKind.grand) {
      return switch (profile) {
        SoundProfile.wood => const [
            _ToneSpec(330, 440, 140, 0.075, 0, false),
            _ToneSpec(440, 587.33, 160, 0.060, 55, false),
            _ToneSpec(523.25, 659.25, 220, 0.055, 110, true),
          ],
        SoundProfile.drop => const [
            _ToneSpec(440, 659.25, 130, 0.075, 0, false),
            _ToneSpec(587.33, 880, 150, 0.060, 55, false),
            _ToneSpec(783.99, 1046.5, 200, 0.050, 110, false),
          ],
        SoundProfile.minimal => const [
            _ToneSpec(523.25, 493.88, 90, 0.060, 0, true),
            _ToneSpec(659.25, 622.25, 100, 0.050, 50, true),
            _ToneSpec(783.99, 739.99, 130, 0.045, 100, true),
          ],
        SoundProfile.pop => const [
            _ToneSpec(392, 523.25, 140, 0.075, 0, false),
            _ToneSpec(493.88, 659.25, 160, 0.060, 60, false),
            _ToneSpec(587.33, 783.99, 220, 0.055, 120, true),
          ],
      };
    }
    return switch (profile) {
      SoundProfile.drop => const [_ToneSpec(540, 1060, 85, 0.085, 0, false)],
      SoundProfile.wood => const [
          _ToneSpec(392, 388, 75, 0.075, 0, false),
          _ToneSpec(784, 770, 45, 0.028, 4, true),
        ],
      SoundProfile.minimal => const [
          _ToneSpec(620, 420, 26, 0.055, 0, true),
          _ToneSpec(920, 740, 22, 0.030, 12, false),
        ],
      SoundProfile.pop => const [
          _ToneSpec(330, 720, 68, 0.085, 0, false),
          _ToneSpec(660, 880, 38, 0.028, 12, true),
        ],
    };
  }
}

class _ToneSpec {
  const _ToneSpec(
    this.f0,
    this.f1,
    this.durMs,
    this.vol,
    this.delayMs,
    this.triangle,
  );
  final double f0;
  final double f1;
  final int durMs;
  final double vol;
  final int delayMs;
  final bool triangle;
}
