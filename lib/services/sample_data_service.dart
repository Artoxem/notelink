// lib/services/sample_data_service.dart

import 'package:intl/intl.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';

class SampleDataService {
  final NotesProvider notesProvider;
  final ThemesProvider themesProvider;

  SampleDataService({
    required this.notesProvider,
    required this.themesProvider,
  });

  Future<void> loadSampleData() async {
    await _createSampleThemes();
    await _createSampleNotes();
  }

  Future<void> _createSampleThemes() async {
    // Создаем 2 темы
    await themesProvider.createTheme(
      'Работа',
      'Рабочие задачи и проекты',
      '0xFF4CAF50', // Зеленый
      [],
      ThemeLogoType.icon01,
    );

    await themesProvider.createTheme(
      'Личное',
      'Личные заметки и задачи',
      '0xFF2196F3', // Синий
      [],
      ThemeLogoType.icon02,
    );
  }

  Future<void> _createSampleNotes() async {
    // Получаем ID созданных тем
    final themes = themesProvider.themes;
    if (themes.length < 2) return;

    final workThemeId = themes[0].id;
    final personalThemeId = themes[1].id;

    // Текущий месяц для создания дат
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    // Создаем 4 заметки для рабочей темы
    await notesProvider.createNote(
      content:
          '# Важная встреча с клиентом\nОбсудить новые требования проекта и уточнить сроки.',
      themeIds: [workThemeId],
      hasDeadline: true,
      deadlineDate: DateTime(currentYear, currentMonth, now.day + 2),
      mediaUrls: [],
    );

    await notesProvider.createNote(
      content:
          '# Финансовый отчет\nПодготовить ежемесячный финансовый отчет для руководства.\n\n*Примечание: добавлен файл отчета за прошлый месяц*',
      themeIds: [workThemeId],
      hasDeadline: true,
      deadlineDate: DateTime(currentYear, currentMonth, now.day + 5),
      mediaUrls: ['sample_report.pdf'], // Пример файла
    );

    await notesProvider.createNote(
      content:
          '# Идеи для презентации\nСобрать ключевые пункты для презентации нового проекта.\n\n*Прикреплен скриншот с примером оформления*',
      themeIds: [workThemeId],
      hasDeadline: false,
      mediaUrls: ['sample_presentation.jpg'], // Пример изображения
    );

    await notesProvider.createNote(
      content:
          '# Заметки со встречи\nОсновные итоги встречи команды от ${DateFormat('dd.MM.yyyy').format(DateTime(currentYear, currentMonth, now.day - 3))}\n\n![voice](voice:sample_meeting_voice)',
      themeIds: [workThemeId],
      hasDeadline: false,
      mediaUrls: [],
    );

    // Создаем 4 заметки для личной темы
    await notesProvider.createNote(
      content: '# Список покупок\n- Молоко\n- Хлеб\n- Овощи\n- Фрукты',
      themeIds: [personalThemeId],
      hasDeadline: false,
      mediaUrls: [],
    );

    await notesProvider.createNote(
      content:
          '# День рождения друга\nПодготовить подарок и организовать встречу.\n\n*Фото идеи для подарка:*',
      themeIds: [personalThemeId],
      hasDeadline: true,
      deadlineDate: DateTime(currentYear, currentMonth, now.day + 7),
      mediaUrls: ['sample_gift.jpg'], // Пример изображения
    );

    await notesProvider.createNote(
      content:
          '# Идеи для отпуска\nВозможные направления:\n- Горы\n- Море\n- Экскурсионный тур\n\n*Прикреплены фото из интернета*',
      themeIds: [personalThemeId],
      hasDeadline: false,
      mediaUrls: [
        'sample_vacation1.jpg',
        'sample_vacation2.jpg'
      ], // Несколько изображений
    );

    await notesProvider.createNote(
      content:
          '# Рецепт пирога\nИнгредиенты и пошаговая инструкция приготовления.\n\n*Аудио с пояснениями:*\n\n![voice](voice:sample_recipe_voice)',
      themeIds: [personalThemeId],
      hasDeadline: false,
      mediaUrls: ['sample_recipe.jpg'], // Изображение
    );
  }
}
