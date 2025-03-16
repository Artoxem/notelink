// lib/widgets/audio_wave_preview.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../utils/constants.dart';

class AudioWavePreview extends StatelessWidget {
  final double width;
  final double height;
  final String? durationText;
  final Color color;
  final bool isAnimated;

  const AudioWavePreview({
    Key? key,
    this.width = 40,
    this.height = 20,
    this.durationText,
    this.color = Colors.purple,
    this.isAnimated = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Волновая форма
          CustomPaint(
            size: Size(width, height),
            painter: _AudioWavePainter(
              color: color,
              isAnimated: isAnimated,
            ),
          ),

          // Длительность (если указана)
          if (durationText != null)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  durationText!,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AudioWavePainter extends CustomPainter {
  final Color color;
  final bool isAnimated;
  final double animationOffset;

  _AudioWavePainter({
    required this.color,
    this.isAnimated = false,
  }) : animationOffset = isAnimated
            ? DateTime.now().millisecondsSinceEpoch % 1000 / 1000
            : 0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Размер волновой формы
    final width = size.width;
    final height = size.height;

    // Генерация случайных, но детерминированных высот волн
    final random = math.Random(42);
    final waveSegments = 12; // Количество сегментов волны
    final segmentWidth = width / waveSegments;

    // Базовая линия (центр)
    canvas.drawLine(
      Offset(0, height / 2),
      Offset(width, height / 2),
      linePaint,
    );

    // Рисуем волны
    for (int i = 0; i < waveSegments; i++) {
      final x = i * segmentWidth;

      // Генерируем высоту волны
      double amplitude;
      if (i == 0 || i == waveSegments - 1) {
        amplitude = 0.2; // Меньшая высота по краям
      } else {
        amplitude =
            0.2 + random.nextDouble() * 0.6; // Случайная высота в середине
      }

      // Если анимация включена, добавляем движущийся эффект
      if (isAnimated) {
        // Сдвиг фазы для создания эффекта движения
        final phase = (i / waveSegments + animationOffset) % 1.0;
        amplitude *= math.sin(phase * math.pi * 2) * 0.3 + 0.7;
      }

      final waveHeight = height * amplitude;

      // Рисуем линию для текущего сегмента
      canvas.drawLine(
        Offset(x, height / 2 - waveHeight / 2),
        Offset(x, height / 2 + waveHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AudioWavePainter oldDelegate) {
    return isAnimated || oldDelegate.color != color;
  }
}
