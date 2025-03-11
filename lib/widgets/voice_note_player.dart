// lib/widgets/voice_note_player.dart
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class VoiceNotePlayer extends StatefulWidget {
  final String audioPath;
  final VoidCallback? onDelete;
  final double maxWidth;

  const VoiceNotePlayer({
    Key? key,
    required this.audioPath,
    this.onDelete,
    this.maxWidth = 200.0,
  }) : super(key: key);

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer>
    with SingleTickerProviderStateMixin {
  bool _isPlaying = false;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Имитируем 3-секундную запись
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;

      if (_isPlaying) {
        _progressController.forward(from: 0.0);
      } else {
        _progressController.stop();
      }
    });

    // Показать сообщение о том, что воспроизведение не поддерживается
    if (_isPlaying) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Воспроизведение будет доступно в следующей версии'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Создаем уникальную длительность из имени файла для имитации
    final fileName = widget.audioPath.split('/').last;
    final fakeDuration =
        '0:${(fileName.hashCode % 50 + 10).toString().padLeft(2, '0')}';

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
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: AppColors.accentPrimary,
              size: 28,
            ),
            onPressed: _togglePlayback,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progressController.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    }),
                const SizedBox(height: 4),
                Text(
                  fakeDuration,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textOnLight,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onDelete != null)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
                size: 20,
              ),
              onPressed: widget.onDelete,
            ),
        ],
      ),
    );
  }
}
