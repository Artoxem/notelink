// lib/services/voice_note_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class VoiceNoteService {
  static final VoiceNoteService _instance = VoiceNoteService._internal();

  factory VoiceNoteService() => _instance;

  VoiceNoteService._internal();

  bool _isRecording = false;
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  Timer? _amplitudeTimer;
  final Random _random = Random();

  bool get isRecording => _isRecording;
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Future<bool> startRecording() async {
    if (_isRecording) return false;

    _isRecording = true;
    _startAmplitudeSimulation();

    return true;
  }

  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _amplitudeTimer?.cancel();
    _isRecording = false;

    // Симулируем создание файла и возвращаем идентификатор
    return 'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
  }

  void cancelRecording() {
    _amplitudeTimer?.cancel();
    _isRecording = false;
  }

  void _startAmplitudeSimulation() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }

      // Имитируем случайные значения амплитуды между 0.2 и 0.9
      final amplitude = 0.2 + (0.7 * _random.nextDouble());
      _amplitudeController.add(amplitude);
    });
  }

  void dispose() {
    _amplitudeTimer?.cancel();
    _amplitudeController.close();
  }
}
