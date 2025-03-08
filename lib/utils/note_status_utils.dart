import 'package:flutter/material.dart';
import '../models/note.dart';
import 'constants.dart';

class NoteStatusUtils {
  // Получение цвета для статуса заметки
  static Color getNoteStatusColor(Note note) {
    if (note.isCompleted) {
      return AppColors.completed;
    }

    if (!note.hasDeadline || note.deadlineDate == null) {
      return AppColors.secondary; // Обычный цвет для заметок без дедлайна
    }

    final now = DateTime.now();
    final daysUntilDeadline = note.deadlineDate!.difference(now).inDays;

    if (daysUntilDeadline < 0) {
      return AppColors.deadlineUrgent; // Просрочено
    } else if (daysUntilDeadline <= 2) {
      return AppColors.deadlineUrgent; // Срочно (красный)
    } else if (daysUntilDeadline <= 7) {
      return AppColors.deadlineNear; // Скоро (оранжевый)
    } else {
      return AppColors.deadlineFar; // Не срочно (желтый)
    }
  }

  // Получение фонового цвета для статуса заметки
  static Color getNoteStatusBackgroundColor(Note note) {
    return getNoteStatusColor(note).withOpacity(0.2);
  }

  // Получение текстового описания статуса заметки
  static String getNoteStatusText(Note note) {
    if (note.isCompleted) {
      return 'Выполнено';
    }

    if (!note.hasDeadline || note.deadlineDate == null) {
      return 'Без дедлайна';
    }

    final now = DateTime.now();
    final daysUntilDeadline = note.deadlineDate!.difference(now).inDays;

    if (daysUntilDeadline < 0) {
      return 'Просрочено';
    } else if (daysUntilDeadline == 0) {
      return 'Сегодня';
    } else if (daysUntilDeadline == 1) {
      return 'Завтра';
    } else if (daysUntilDeadline < 7) {
      return 'Через $daysUntilDeadline дн.';
    } else {
      final date = note.deadlineDate!;
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  // Проверка, является ли дедлайн срочным
  static bool isDeadlineUrgent(Note note) {
    if (!note.hasDeadline || note.deadlineDate == null || note.isCompleted) {
      return false;
    }

    final now = DateTime.now();
    final daysUntilDeadline = note.deadlineDate!.difference(now).inDays;

    return daysUntilDeadline <= 2;
  }

  // Проверка, просрочен ли дедлайн
  static bool isDeadlineOverdue(Note note) {
    if (!note.hasDeadline || note.deadlineDate == null || note.isCompleted) {
      return false;
    }

    final now = DateTime.now();
    final daysUntilDeadline = note.deadlineDate!.difference(now).inDays;

    return daysUntilDeadline < 0;
  }

  // Получение иконки для заметки на основе статуса
  static IconData getNoteStatusIcon(Note note) {
    if (note.isCompleted) {
      return Icons.check_circle;
    }

    if (!note.hasDeadline || note.deadlineDate == null) {
      return Icons.note;
    }

    if (isDeadlineOverdue(note)) {
      return Icons.warning;
    } else if (isDeadlineUrgent(note)) {
      return Icons.access_time;
    } else {
      return Icons.event;
    }
  }
}
