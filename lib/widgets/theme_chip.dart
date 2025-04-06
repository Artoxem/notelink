import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../models/theme.dart';

/// Виджет отображения чипа темы
class ThemeChip extends StatelessWidget {
  /// Модель темы
  final NoteTheme theme;

  /// Выбран ли чип
  final bool isSelected;

  /// Callback при нажатии на чип
  final VoidCallback? onTap;

  /// Callback при долгом нажатии на чип
  final VoidCallback? onLongPress;

  /// Размер чипа
  final ThemeChipSize size;

  /// Показывать ли иконку удаления
  final bool showDeleteIcon;

  /// Callback при нажатии на иконку удаления
  final VoidCallback? onDelete;

  const ThemeChip({
    Key? key,
    required this.theme,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.size = ThemeChipSize.medium,
    this.showDeleteIcon = false,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Получаем параметры размера
    final double height = _getHeight();
    final double iconSize = _getIconSize();
    final double fontSize = _getFontSize();
    final EdgeInsets padding = _getPadding();

    // Парсим цвет из строки
    Color themeColor;
    try {
      themeColor = Color(int.parse(theme.color));
    } catch (e) {
      themeColor = Colors.blue;
    }

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: isSelected
              ? themeColor.withOpacity(0.7)
              : themeColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(
            color: isSelected ? themeColor : themeColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Цветовой индикатор темы
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: themeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),

            // Название темы
            Text(
              theme.name,
              style: TextStyle(
                color:
                    isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),

            // Иконка удаления (если нужна)
            if (showDeleteIcon && onDelete != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(iconSize),
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: iconSize * 0.7,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Получает высоту чипа в зависимости от размера
  double _getHeight() {
    switch (size) {
      case ThemeChipSize.small:
        return 24.0;
      case ThemeChipSize.medium:
        return 32.0;
      case ThemeChipSize.large:
        return 40.0;
    }
  }

  /// Получает размер иконки в зависимости от размера чипа
  double _getIconSize() {
    switch (size) {
      case ThemeChipSize.small:
        return 14.0;
      case ThemeChipSize.medium:
        return 18.0;
      case ThemeChipSize.large:
        return 22.0;
    }
  }

  /// Получает размер шрифта в зависимости от размера чипа
  double _getFontSize() {
    switch (size) {
      case ThemeChipSize.small:
        return 12.0;
      case ThemeChipSize.medium:
        return 14.0;
      case ThemeChipSize.large:
        return 16.0;
    }
  }

  /// Получает отступы в зависимости от размера чипа
  EdgeInsets _getPadding() {
    switch (size) {
      case ThemeChipSize.small:
        return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0);
      case ThemeChipSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0);
      case ThemeChipSize.large:
        return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0);
    }
  }
}

/// Перечисление размеров чипа темы
enum ThemeChipSize {
  /// Маленький
  small,

  /// Средний
  medium,

  /// Большой
  large,
}
