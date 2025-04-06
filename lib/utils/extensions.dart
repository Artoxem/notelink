import 'package:flutter/material.dart';
import 'dart:io';

/// Расширения для работы с DateTime
extension DateTimeExtensions on DateTime {
  /// Проверяет, является ли текущая дата сегодняшней
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Проверяет, является ли текущая дата вчерашней
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Проверяет, является ли текущая дата завтрашней
  bool get isTomorrow {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  /// Возвращает форматированную строку даты в российском формате
  String get formattedDate {
    return '${day.toString().padLeft(2, '0')}.${month.toString().padLeft(2, '0')}.$year';
  }

  /// Проверяет, находится ли дата в текущей неделе
  bool get isThisWeek {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final lastDayOfWeek = firstDayOfWeek.add(const Duration(days: 6));
    return isAfter(firstDayOfWeek.subtract(const Duration(days: 1))) &&
        isBefore(lastDayOfWeek.add(const Duration(days: 1)));
  }
}

/// Расширения для работы со String
extension StringExtensions on String {
  /// Преобразует первую букву строки в заглавную
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Проверяет, является ли строка валидным URL
  bool get isValidUrl {
    final urlPattern = RegExp(
      r'^(http|https)://[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(this);
  }

  /// Проверяет, является ли строка валидным email
  bool get isValidEmail {
    final emailPattern = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );
    return emailPattern.hasMatch(this);
  }

  /// Проверяет, является ли строка изображением по расширению
  bool get isImageFile {
    final ext = toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp');
  }

  /// Возвращает имя файла из пути
  String get fileName {
    return split('/').last.split('\\').last;
  }
}

/// Расширения для работы с Color
extension ColorExtensions on Color {
  /// Возвращает контрастный цвет (черный или белый) для текущего цвета
  Color get contrastColor {
    int d = 0;
    // Перцептивная яркость (яркость как воспринимается людьми)
    // https://www.w3.org/TR/AERT/#color-contrast
    double luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;

    if (luminance > 0.5) {
      d = 0; // черный для светлых цветов
    } else {
      d = 255; // белый для темных цветов
    }

    return Color.fromARGB(alpha, d, d, d);
  }

  /// Затемняет цвет на указанный процент
  Color darken(double percent) {
    assert(percent >= 0 && percent <= 1);

    final f = 1 - percent;

    return Color.fromARGB(
      alpha,
      (red * f).round(),
      (green * f).round(),
      (blue * f).round(),
    );
  }

  /// Осветляет цвет на указанный процент
  Color lighten(double percent) {
    assert(percent >= 0 && percent <= 1);

    final f = percent;

    return Color.fromARGB(
      alpha,
      (red + (255 - red) * f).round(),
      (green + (255 - green) * f).round(),
      (blue + (255 - blue) * f).round(),
    );
  }
}

/// Расширения для работы с File
extension FileExtensions on File {
  /// Возвращает размер файла в удобочитаемом формате
  Future<String> get readableSize async {
    final bytes = await length();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Проверяет, является ли файл изображением по расширению
  bool get isImage {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp');
  }

  /// Проверяет, является ли файл аудио по расширению
  bool get isAudio {
    final ext = path.toLowerCase();
    return ext.endsWith('.mp3') ||
        ext.endsWith('.wav') ||
        ext.endsWith('.m4a') ||
        ext.endsWith('.aac') ||
        ext.endsWith('.ogg');
  }
}
