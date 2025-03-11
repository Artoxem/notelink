import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class VoiceNoteRecorder {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _currentRecordingPath;
  StreamController<double>? _amplitudeStreamController;
  Timer? _amplitudeTimer;

  bool get isRecording => _isRecording;
  Stream<double>? get amplitudeStream => _amplitudeStreamController?.stream;

  // Инициализация и запрос разрешений
  Future<bool> initialize() async {
    try {
      // Запрашиваем разрешение на использование микрофона
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      print('Ошибка при запросе разрешений: $e');
      return false;
    }
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

      // Создаем директорию для хранения аудиозаписей, если её нет
      final directory = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${directory.path}/voice_notes');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      // Генерируем имя файла на основе текущего времени
      final fileName =
          'voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = path.join(audioDir.path, fileName);

      // Проверка значения перед передачей
      if (_currentRecordingPath != null) {
        // Настраиваем запись
        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path:
              _currentRecordingPath!, // Используем ! для утверждения ненулевого значения
        );

        // Настраиваем поток для анимации уровня звука
        _amplitudeStreamController = StreamController<double>();
        _startAmplitudeListener();

        _isRecording = true;
        return true;
      } else {
        print('Ошибка: путь к файлу не определен');
        return false;
      }
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

      // Останавливаем запись
      final path = await _audioRecorder.stop();
      final String? recordingPath = path;
      _currentRecordingPath = null;
      _isRecording = false;

      // Возвращаем путь к файлу
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

      await _audioRecorder.stop();

      // Удаляем файл, если он был создан
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

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
        final amplitude = await _audioRecorder.getAmplitude();
        final double level = amplitude.current / 100; // Нормализация значения
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
    _audioRecorder.dispose();
  }
}
