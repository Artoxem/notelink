import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/constants.dart';

class VoiceNotePlayer extends StatefulWidget {
  final String audioPath;
  final double maxWidth;
  final bool compact;

  const VoiceNotePlayer({
    Key? key,
    required this.audioPath,
    this.maxWidth = 280,
    this.compact = false,
  }) : super(key: key);

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _progress = 0.0;
  String _localPath = '';
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _loadAudioFile();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAudioFile() async {
    setState(() => _isLoading = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final path = widget.audioPath;

      if (path.startsWith('/')) {
        // Абсолютный путь к файлу
        _localPath = path;
      } else if (path.startsWith('file://')) {
        // URI формат
        _localPath = path.substring(7);
      } else {
        // Относительный путь в директории приложения
        _localPath = '${appDir.path}/$path';
      }

      // Проверяем, существует ли файл
      final file = File(_localPath);
      if (!await file.exists()) {
        throw Exception('Аудиофайл не найден');
      }

      // Устанавливаем источник аудио
      await _audioPlayer.setFilePath(_localPath);

      // Получаем длительность
      _duration = _audioPlayer.duration ?? Duration.zero;

      setState(() {
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      print('Ошибка загрузки аудио: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  void _initAudioPlayer() {
    // Обработчик окончания воспроизведения
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _progress = 0.0;
        });
        _audioPlayer.seek(Duration.zero);
      }
    });

    // Обработчик изменения состояния воспроизведения
    _audioPlayer.playingStream.listen((playing) {
      setState(() {
        _isPlaying = playing;
      });
    });

    // Обработчик изменения позиции воспроизведения
    _audioPlayer.positionStream.listen((position) {
      setState(() {
        _position = position;
        if (_duration.inMilliseconds > 0) {
          _progress = _position.inMilliseconds / _duration.inMilliseconds;
        }
      });
    });

    // Обработчик изменения длительности
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  void _seekTo(double value) async {
    final position =
        Duration(milliseconds: (value * _duration.inMilliseconds).round());
    await _audioPlayer.seek(position);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactPlayer();
    }

    return _buildFullPlayer();
  }

  Widget _buildCompactPlayer() {
    return Container(
      height: 40,
      width: widget.maxWidth,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.purple,
              size: 20,
            ),
            onPressed: _togglePlay,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.purple.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 8),
            child: Text(
              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.purple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPlayer() {
    if (_isLoading) {
      return Container(
        width: widget.maxWidth,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        width: widget.maxWidth,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Ошибка загрузки аудио',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    return Container(
      width: widget.maxWidth,
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Верхняя строка с типом и длительностью
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.mic, size: 16, color: Colors.purple),
                  SizedBox(width: 4),
                  Text(
                    'Голосовое сообщение',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Слайдер воспроизведения
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: Colors.purple,
              inactiveTrackColor: Colors.purple.withOpacity(0.3),
              thumbColor: Colors.purple,
              overlayColor: Colors.purple.withOpacity(0.3),
            ),
            child: Slider(
              value: _progress,
              onChanged: _seekTo,
            ),
          ),

          const SizedBox(height: 8),

          // Кнопки управления
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.purple),
                onPressed: () {
                  final newPosition = Duration(
                    milliseconds: math.max(0, _position.inMilliseconds - 10000),
                  );
                  _audioPlayer.seek(newPosition);
                },
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.purple,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: _togglePlay,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.purple),
                onPressed: () {
                  final newPosition = Duration(
                    milliseconds: math.min(
                      _duration.inMilliseconds,
                      _position.inMilliseconds + 10000,
                    ),
                  );
                  _audioPlayer.seek(newPosition);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
