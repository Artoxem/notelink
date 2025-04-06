import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Виджет анимированной галочки для визуального подтверждения
class AnimatedCheck extends StatefulWidget {
  /// Размер иконки
  final double size;

  /// Цвет иконки
  final Color color;

  /// Длительность анимации
  final Duration duration;

  /// Активна ли анимация при первом показе
  final bool active;

  /// Callback при завершении анимации
  final VoidCallback? onAnimationComplete;

  const AnimatedCheck({
    Key? key,
    this.size = 32.0,
    this.color = Colors.green,
    this.duration = const Duration(milliseconds: 300),
    this.active = false,
    this.onAnimationComplete,
  }) : super(key: key);

  @override
  AnimatedCheckState createState() => AnimatedCheckState();
}

class AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    if (widget.active) {
      _controller.forward().then((_) {
        if (widget.onAnimationComplete != null) {
          widget.onAnimationComplete!();
        }
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedCheck oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Если состояние изменилось, запускаем/отменяем анимацию
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller.forward().then((_) {
          if (widget.onAnimationComplete != null) {
            widget.onAnimationComplete!();
          }
        });
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Метод для программного запуска анимации
  void activate() {
    _controller.forward().then((_) {
      if (widget.onAnimationComplete != null) {
        widget.onAnimationComplete!();
      }
    });
  }

  /// Метод для программного сброса анимации
  void deactivate() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: CheckPainter(
            progress: _animation.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

/// Кастомный painter для рисования анимированной галочки
class CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Рисуем круг
    final Paint circlePaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final double circleProgress = progress > 0.5 ? 1.0 : progress * 2;
    final double circleSize = size.width * circleProgress;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      circleSize / 2,
      circlePaint,
    );

    // Рисуем галочку
    if (progress > 0.5) {
      final Paint checkPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width / 10
        ..strokeCap = StrokeCap.round;

      final double checkProgress =
          (progress - 0.5) * 2; // масштабируем от 0 до 1

      final Path checkPath = Path();

      // Точки для галочки (относительно размера)
      final double leftPoint = size.width * 0.3;
      final double middlePoint = size.width * 0.5;
      final double rightPoint = size.width * 0.7;
      final double topPoint = size.height * 0.4;
      final double bottomPoint = size.height * 0.6;

      // Первая линия галочки
      final double firstLineProgress =
          checkProgress < 0.5 ? checkProgress * 2 : 1.0;
      checkPath.moveTo(leftPoint, middlePoint);
      checkPath.lineTo(
        leftPoint + (middlePoint - leftPoint) * firstLineProgress,
        middlePoint + (bottomPoint - middlePoint) * firstLineProgress,
      );

      // Вторая линия галочки
      if (checkProgress > 0.5) {
        final double secondLineProgress = (checkProgress - 0.5) * 2;
        checkPath.moveTo(middlePoint, bottomPoint);
        checkPath.lineTo(
          middlePoint + (rightPoint - middlePoint) * secondLineProgress,
          bottomPoint + (topPoint - bottomPoint) * secondLineProgress,
        );
      }

      canvas.drawPath(checkPath, checkPaint);
    }
  }

  @override
  bool shouldRepaint(CheckPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
