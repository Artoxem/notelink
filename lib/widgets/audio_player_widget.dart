import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/audio_player_service.dart';
import 'dart:async';

class AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final double maxWidth;
  final VoidCallback? onDeletePressed;

  const AudioPlayerWidget({
    Key? key,
    required this.audioPath,
    this.maxWidth = 200.0,
    this.onDeletePressed,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayerService _audioService = AudioPlayerService();
  bool _isPlaying = false;
  bool _isFileExists = false;
  bool _isLoading = true;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _playingSubscription;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    _checkFileAndLoadDuration();
    _initializePlayingStream();
  }

  Future<void> _checkFileAndLoadDuration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final file = File(widget.audioPath);
      _isFileExists = await file.exists();

      if (_isFileExists) {
        final duration = await _audioService.getDuration(widget.audioPath);
        if (duration != null) {
          setState(() {
            _duration = duration;
          });
        }
      }
    } catch (e) {
      print('Ошибка при загрузке аудиофайла: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializePlayingStream() {
    _playingSubscription =
        _audioService.currentPlayingStream.listen((playingPath) {
      if (mounted) {
        setState(() {
          _isPlaying = playingPath == widget.audioPath;
          if (!_isPlaying) {
            _stopPositionTimer();
          } else {
            _startPositionTimer();
          }
        });
      }
    });
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _updatePosition();
    });
    _updatePosition();
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  Future<void> _updatePosition() async {
    if (!mounted) return;
    final position = await _audioService.getPosition(widget.audioPath);
    setState(() {
      _position = position;
    });
  }

  void _togglePlayback() async {
    if (!_isFileExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Аудиофайл не найден'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_isPlaying) {
      await _audioService.pause(widget.audioPath);
    } else {
      await _audioService.play(widget.audioPath);
    }
  }

  @override
  void dispose() {
    _playingSubscription?.cancel();
    _stopPositionTimer();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: widget.maxWidth),
      decoration: BoxDecoration(
        color: AppColors.textBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(AppColors.accentPrimary),
                    ),
                  )
                : Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color:
                        _isFileExists ? AppColors.accentPrimary : Colors.grey,
                    size: 28,
                  ),
            onPressed: _isLoading ? null : _togglePlayback,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _duration.inMilliseconds > 0
                        ? _position.inMilliseconds / _duration.inMilliseconds
                        : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textOnLight,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textOnLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.onDeletePressed != null)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: widget.onDeletePressed,
            ),
        ],
      ),
    );
  }
}
