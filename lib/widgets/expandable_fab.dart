import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/constants.dart';

/// Виджет расширяемой кнопки действия (FAB)
class ExpandableFab extends StatefulWidget {
  /// Дочерние кнопки, которые появляются при нажатии на основную кнопку
  final List<Widget> children;

  /// Расстояние между дочерними кнопками
  final double distance;

  /// Иконка для состояния "развернуто"
  final Widget? expandIcon;

  /// Иконка для состояния "свернуто"
  final Widget? collapseIcon;

  /// Радиус основной кнопки
  final double fabSize;

  /// Цвет основной кнопки
  final Color? backgroundColor;

  /// Начальное состояние (свернуто/развернуто)
  final bool initialOpen;

  /// Callback, вызываемый при изменении состояния
  final ValueChanged<bool>? onStateChanged;

  const ExpandableFab({
    Key? key,
    required this.children,
    this.distance = 100.0,
    this.expandIcon,
    this.collapseIcon,
    this.fabSize = 56.0,
    this.backgroundColor,
    this.initialOpen = false,
    this.onStateChanged,
  }) : super(key: key);

  @override
  ExpandableFabState createState() => ExpandableFabState();
}

class ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _open = widget.initialOpen;
    _controller = AnimationController(
      value: widget.initialOpen ? 1.0 : 0.0,
      duration: AppAnimations.mediumDuration,
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Программное переключение состояния
  void toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }

      if (widget.onStateChanged != null) {
        widget.onStateChanged!(_open);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.fabSize,
      height: widget.fabSize,
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          // Дочерние кнопки в развернутом состоянии
          ..._buildExpandingActionButtons(),

          // Основная кнопка, которая разворачивает/сворачивает
          _buildTapToOpenFab(),
        ],
      ),
    );
  }

  /// Создает основную кнопку FAB
  Widget _buildTapToOpenFab() {
    final defaultExpandIcon = Icon(
      Icons.add,
      color: AppColors.textBackground,
      size: widget.fabSize * 0.5,
    );

    final defaultCollapseIcon = Icon(
      Icons.close,
      color: AppColors.textBackground,
      size: widget.fabSize * 0.5,
    );

    return FloatingActionButton(
      heroTag: 'expandable_fab_main',
      backgroundColor: widget.backgroundColor ?? AppColors.accentPrimary,
      onPressed: toggle,
      child: AnimatedRotation(
        duration: AppAnimations.shortDuration,
        turns: _open ? 0.125 : 0.0,
        child: AnimatedSwitcher(
          duration: AppAnimations.shortDuration,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: animation,
                child: child,
              ),
            );
          },
          child: _open
              ? (widget.collapseIcon ?? defaultCollapseIcon)
              : (widget.expandIcon ?? defaultExpandIcon),
        ),
      ),
    );
  }

  /// Создает дочерние кнопки, которые анимированно появляются при нажатии
  List<Widget> _buildExpandingActionButtons() {
    final children = <Widget>[];
    final count = widget.children.length;

    for (int i = 0; i < count; i++) {
      final double factor = i / count;
      final double angle = factor * math.pi * 2;

      children.add(
        _ExpandingActionButton(
          directionInDegrees: angle * 180 / math.pi,
          maxDistance: widget.distance,
          progress: _expandAnimation,
          child: widget.children[i],
        ),
      );
    }

    return children;
  }
}

/// Виджет для дочерней кнопки, которая анимируется в развернутом состоянии
class _ExpandingActionButton extends StatelessWidget {
  final double directionInDegrees;
  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  const _ExpandingActionButton({
    required this.directionInDegrees,
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final offset = Offset.fromDirection(
          directionInDegrees * (math.pi / 180),
          progress.value * maxDistance,
        );

        // Вычисляем прозрачность при анимации
        final opacity = progress.value.clamp(0.0, 1.0);

        // Scale анимация для дочерних кнопок
        final scale = 0.7 + (progress.value * 0.3);

        return Positioned(
          right: offset.dx,
          bottom: offset.dy,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: this.child,
            ),
          ),
        );
      },
    );
  }
}

/// Виджет дочерней кнопки действия для ExpandableFab
class ActionButton extends StatelessWidget {
  /// Иконка кнопки
  final IconData icon;

  /// Цвет иконки
  final Color iconColor;

  /// Цвет фона кнопки
  final Color backgroundColor;

  /// Действие при нажатии
  final VoidCallback onPressed;

  /// Подсказка при долгом нажатии
  final String? tooltip;

  /// Размер кнопки
  final double size;

  const ActionButton({
    Key? key,
    required this.icon,
    this.iconColor = Colors.white,
    this.backgroundColor = Colors.blue,
    required this.onPressed,
    this.tooltip,
    this.size = 48.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      shape: const CircleBorder(),
      color: backgroundColor,
      elevation: 4.0,
      child: SizedBox(
        width: size,
        height: size,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Icon(
            icon,
            color: iconColor,
            size: size * 0.5,
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
