// lib/widgets/audio_player_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class AudioPlayerWidget extends StatelessWidget {
  final String audioPath;
  final double maxWidth;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onPlayPressed;

  const AudioPlayerWidget({
    Key? key,
    required this.audioPath,
    this.maxWidth = 200.0,
    this.onDeletePressed,
    this.onPlayPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
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
              Icons.play_circle_filled,
              color: AppColors.accentPrimary,
              size: 28,
            ),
            onPressed: onPlayPressed ??
                () {
                  // Показать сообщение о недоступности воспроизведения
                  final snackBar = SnackBar(
                    content: const Text(
                        'Воспроизведение будет доступно в следующей версии'),
                    duration: const Duration(seconds: 2),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (onDeletePressed != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: InkWell(
                onTap: onDeletePressed,
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
