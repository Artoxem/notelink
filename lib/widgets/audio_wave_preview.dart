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

    // Размер волновой формы
    final width = size.width;
    final height = size.height;

    // Создаем один путь для всех линий вместо отдельных вызовов drawLine
    final Path wavePath = Path();
    final waveSegments = 8; // Уменьшаем количество сегментов с 12 до 8
    final segmentWidth = width / waveSegments;

    // Генерируем статические, а не случайные высоты
    final heights = [0.3, 0.5, 0.7, 0.9, 0.7, 0.5, 0.3, 0.2];

    for (int i = 0; i < waveSegments; i++) {
      final x = i * segmentWidth;
      double amplitude = heights[i % heights.length];

      if (isAnimated) {
        final phase = (i / waveSegments + animationOffset) % 1.0;
        amplitude *= math.sin(phase * math.pi) * 0.3 + 0.7;
      }

      final waveHeight = height * amplitude;
      final yStart = height / 2 - waveHeight / 2;
      final yEnd = height / 2 + waveHeight / 2;

      wavePath.moveTo(x, yStart);
      wavePath.lineTo(x, yEnd);
    }

    canvas.drawPath(wavePath, paint);
  }

  @override
  bool shouldRepaint(_AudioWavePainter oldDelegate) {
    return isAnimated || oldDelegate.color != color;
  }
}
