import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:io';

class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  final Map<String, AudioPlayer> _players = {};
  final StreamController<String> _currentPlayingController =
      StreamController<String>.broadcast();

  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal();

  Stream<String> get currentPlayingStream => _currentPlayingController.stream;
  String? _currentPlayingPath;
  String? get currentPlayingPath => _currentPlayingPath;

  // Получение плеера для конкретного аудиофайла
  Future<AudioPlayer> _getPlayer(String audioPath) async {
    if (!_players.containsKey(audioPath)) {
      _players[audioPath] = AudioPlayer();

      // Подписываемся на события завершения воспроизведения
      _players[audioPath]!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (_currentPlayingPath == audioPath) {
            _currentPlayingPath = null;
            _currentPlayingController.add('');
          }
        }
      });
    }
    return _players[audioPath]!;
  }

  // Начать воспроизведение
  Future<void> play(String audioPath) async {
    try {
      // Останавливаем текущее воспроизведение
      if (_currentPlayingPath != null && _currentPlayingPath != audioPath) {
        await stop(_currentPlayingPath!);
      }

      final file = File(audioPath);
      if (!await file.exists()) {
        print('Аудиофайл не найден: $audioPath');
        return;
      }

      final player = await _getPlayer(audioPath);

      // Если плеер уже настроен на этот файл, просто возобновляем воспроизведение
      if (player.playing) {
        await player.pause();
        _currentPlayingPath = null;
        _currentPlayingController.add('');
        return;
      } else if (await player.position > Duration.zero) {
        await player.seek(Duration.zero);
      }

      // Устанавливаем источник и начинаем воспроизведение
      await player.setFilePath(audioPath);
      await player.play();

      _currentPlayingPath = audioPath;
      _currentPlayingController.add(audioPath);
    } catch (e) {
      print('Ошибка при воспроизведении: $e');
    }
  }

  // Пауза
  Future<void> pause(String audioPath) async {
    try {
      if (_players.containsKey(audioPath)) {
        await _players[audioPath]!.pause();

        if (_currentPlayingPath == audioPath) {
          _currentPlayingPath = null;
          _currentPlayingController.add('');
        }
      }
    } catch (e) {
      print('Ошибка при паузе: $e');
    }
  }

  // Остановка
  Future<void> stop(String audioPath) async {
    try {
      if (_players.containsKey(audioPath)) {
        await _players[audioPath]!.stop();

        if (_currentPlayingPath == audioPath) {
          _currentPlayingPath = null;
          _currentPlayingController.add('');
        }
      }
    } catch (e) {
      print('Ошибка при остановке: $e');
    }
  }

  // Получение длительности аудио
  Future<Duration?> getDuration(String audioPath) async {
    try {
      final player = await _getPlayer(audioPath);
      return player.duration;
    } catch (e) {
      print('Ошибка при получении длительности: $e');
      return null;
    }
  }

  // Получение текущей позиции
  Future<Duration> getPosition(String audioPath) async {
    try {
      if (_players.containsKey(audioPath)) {
        return _players[audioPath]!.position;
      }
      return Duration.zero;
    } catch (e) {
      print('Ошибка при получении позиции: $e');
      return Duration.zero;
    }
  }

  // Освобождение ресурсов
  Future<void> dispose() async {
    _currentPlayingPath = null;

    for (final player in _players.values) {
      await player.dispose();
    }
    _players.clear();

    await _currentPlayingController.close();
  }

  // Освобождение конкретного плеера
  Future<void> disposePlayer(String audioPath) async {
    if (_players.containsKey(audioPath)) {
      await _players[audioPath]!.dispose();
      _players.remove(audioPath);

      if (_currentPlayingPath == audioPath) {
        _currentPlayingPath = null;
        _currentPlayingController.add('');
      }
    }
  }
}
