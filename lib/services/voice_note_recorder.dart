// lib/services/voice_note_recorder.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class VoiceNoteRecorder {
  bool _isRecording = false;
  String? _currentRecordingPath;
  StreamController<double>? _amplitudeStreamController;
  Timer? _amplitudeTimer;
  final Random _random = Random();

  bool get isRecording => _isRecording;
  Stream<double>? get amplitudeStream => _amplitudeStreamController?.stream;

  // Инициализация (имитация запроса разрешений)
  Future<bool> initialize() async {
    // Имитируем запрос разрешений и всегда возвращаем true
    await Future.delayed(const Duration(milliseconds: 300));
    return true;
  }

  // Начало записи
  Future<bool> startRecording() async {
    if (_isRecording) {
      return false;
    }

    try {
      final hasPermission = await initialize();
      if (!hasPermission) {
        return false;
      }

      // Генерируем имитацию пути к файлу
      _currentRecordingPath =
          'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      _isRecording = true;

      // Настраиваем поток для анимации уровня звука
      _amplitudeStreamController = StreamController<double>();
      _startAmplitudeListener();

      return true;
    } catch (e) {
      print('Ошибка при начале записи: $e');
      return false;
    }
  }

  // Остановка записи
  Future<String?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      // Останавливаем анимацию амплитуды
      _amplitudeTimer?.cancel();

      // Закрываем поток анимации
      await _amplitudeStreamController?.close();
      _amplitudeStreamController = null;

      final String? recordingPath = _currentRecordingPath;
      _currentRecordingPath = null;
      _isRecording = false;

      // Возвращаем имитацию пути к файлу
      return recordingPath;
    } catch (e) {
      print('Ошибка при остановке записи: $e');
      _isRecording = false;
      return null;
    }
  }

  // Отмена записи
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      _amplitudeTimer?.cancel();

      await _amplitudeStreamController?.close();
      _amplitudeStreamController = null;

      _currentRecordingPath = null;
      _isRecording = false;
    } catch (e) {
      print('Ошибка при отмене записи: $e');
    }
  }

  // Слушатель амплитуды для анимации
  void _startAmplitudeListener() {
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!_isRecording || _amplitudeStreamController == null) {
        timer.cancel();
        return;
      }

      try {
        // Генерируем случайный уровень амплитуды
        final double level = 0.2 + 0.8 * _random.nextDouble();
        _amplitudeStreamController?.add(level.clamp(0.0, 1.0));
      } catch (e) {
        // Игнорируем ошибки
      }
    });
  }

  // Освобождение ресурсов
  Future<void> dispose() async {
    await cancelRecording();
    _amplitudeTimer?.cancel();
    await _amplitudeStreamController?.close();
    _amplitudeStreamController = null;
  }
}
