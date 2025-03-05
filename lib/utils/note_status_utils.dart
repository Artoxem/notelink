import 'package:flutter/material.dart';
import '../models/note.dart';
import 'constants.dart';

class NoteStatusUtils {
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
}
