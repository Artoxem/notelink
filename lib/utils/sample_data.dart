import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/theme.dart';

class SampleData {
  // Генерация ID
  static String generateId() => const Uuid().v4();

  // Создание 4 тем
  static List<NoteTheme> generateThemes() {
    return [
      NoteTheme(
        id: generateId(),
        name: 'Работа',
        description: 'Рабочие задачи и проекты',
        color: '0xFFAE4727', // Burnt Sienna
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
        noteIds: [],
      ),
      NoteTheme(
        id: generateId(),
        name: 'Личное',
        description: 'Личные заметки и идеи',
        color: '0xFF8D957E', // Sage Green
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
        updatedAt: DateTime.now().subtract(const Duration(days: 25)),
        noteIds: [],
      ),
      NoteTheme(
        id: generateId(),
        name: 'Учеба',
        description: 'Учебные материалы и заметки',
        color: '0xFF78898F', // Stormy Sky
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        updatedAt: DateTime.now().subtract(const Duration(days: 20)),
        noteIds: [],
      ),
      NoteTheme(
        id: generateId(),
        name: 'Идеи',
        description: 'Творческие идеи и вдохновение',
        color: '0xFFC38423', // Golden
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        updatedAt: DateTime.now().subtract(const Duration(days: 15)),
        noteIds: [],
      ),
    ];
  }

  // Создание 20 заметок с разными темами, датами и дедлайнами
  static List<Note> generateNotes(List<NoteTheme> themes) {
    final workTheme = themes[0];
    final personalTheme = themes[1];
    final studyTheme = themes[2];
    final ideasTheme = themes[3];

    final notes = <Note>[];
    final now = DateTime.now();

    // 1. Рабочие заметки с дедлайнами
    notes.add(Note(
      id: generateId(),
      content:
          '# Встреча с клиентом\n\nОбсудить требования к новому проекту и составить план работы. Подготовить презентацию и демо-версию.',
      themeIds: [workTheme.id],
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 5)),
      hasDeadline: true,
      deadlineDate: now.add(const Duration(days: 2)),
      hasDateLink: true,
      linkedDate: now.add(const Duration(days: 2)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Отчет за квартал\n\nПодготовить отчет о проделанной работе за квартал:\n- Реализованные проекты\n- Текущие задачи\n- Планы на следующий квартал',
      themeIds: [workTheme.id],
      createdAt: now.subtract(const Duration(days: 10)),
      updatedAt: now.subtract(const Duration(days: 10)),
      hasDeadline: true,
      deadlineDate: now.add(const Duration(days: 5)),
      hasDateLink: true,
      linkedDate: now.add(const Duration(days: 5)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Обновление сайта\n\nОбновить дизайн главной страницы сайта компании. Добавить новые разделы и оптимизировать мобильную версию.',
      themeIds: [workTheme.id],
      createdAt: now.subtract(const Duration(days: 15)),
      updatedAt: now.subtract(const Duration(days: 15)),
      hasDeadline: true,
      deadlineDate: now.add(const Duration(days: 10)),
      hasDateLink: true,
      linkedDate: now.add(const Duration(days: 10)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Собеседование с кандидатом\n\nПровести собеседование с кандидатом на должность разработчика. Подготовить технические вопросы и тестовое задание.',
      themeIds: [workTheme.id],
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(days: 3)),
      hasDeadline: true,
      deadlineDate: now.subtract(const Duration(days: 1)),
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 1)),
      isCompleted: true,
      mediaUrls: [],
    ));

    // 2. Личные заметки
    notes.add(Note(
      id: generateId(),
      content:
          '# Список покупок\n\n- Молоко\n- Хлеб\n- Яблоки\n- Мясо\n- Макароны\n- Сыр',
      themeIds: [personalTheme.id],
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
      hasDeadline: false,
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 2)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Планы на отпуск\n\n1. Забронировать отель\n2. Купить билеты\n3. Составить маршрут поездки\n4. Подготовить документы\n5. Обменять валюту',
      themeIds: [personalTheme.id],
      createdAt: now.subtract(const Duration(days: 20)),
      updatedAt: now.subtract(const Duration(days: 20)),
      hasDeadline: true,
      deadlineDate: now.add(const Duration(days: 30)),
      hasDateLink: true,
      linkedDate: now.add(const Duration(days: 30)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Тренировки на неделю\n\n- **Понедельник**: бег 5 км\n- **Среда**: силовая тренировка\n- **Пятница**: плавание\n- **Воскресенье**: йога',
      themeIds: [personalTheme.id],
      createdAt: now.subtract(const Duration(days: 7)),
      updatedAt: now.subtract(const Duration(days: 7)),
      hasDeadline: false,
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 7)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Рецепт пасты с морепродуктами\n\n**Ингредиенты:**\n- Спагетти - 400 г\n- Мидии - 300 г\n- Креветки - 200 г\n- Чеснок - 3 зубчика\n- Помидоры - 2 шт\n- Белое вино - 100 мл\n- Оливковое масло - 2 ст.л.\n- Петрушка - пучок\n- Соль, перец по вкусу',
      themeIds: [personalTheme.id],
      createdAt: now.subtract(const Duration(days: 12)),
      updatedAt: now.subtract(const Duration(days: 12)),
      hasDeadline: false,
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 12)),
      isCompleted: false,
      mediaUrls: [],
    ));

    // 3. Учебные заметки с дедлайнами
    notes.add(Note(
      id: generateId(),
      content:
          '# Подготовка к экзамену\n\n**Темы для изучения:**\n1. История развития концепции\n2. Основные принципы работы\n3. Практические примеры использования\n4. Современные подходы и тенденции',
      themeIds: [studyTheme.id],
      createdAt: now.subtract(const Duration(days: 14)),
      updatedAt: now.subtract(const Duration(days: 14)),
      hasDeadline: true,
      deadlineDate: now.add(const Duration(days: 7)),
      hasDateLink: true,
      linkedDate: now.add(const Duration(days: 7)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Конспект лекции по Flutter\n\n## Основные виджеты\n- StatelessWidget\n- StatefulWidget\n- Material Design widgets\n- Cupertino widgets\n\n## Управление состоянием\n- setState\n- Provider\n- Bloc/Cubit\n- Riverpod',
      themeIds: [studyTheme.id],
      createdAt: now.subtract(const Duration(days: 8)),
      updatedAt: now.subtract(const Duration(days: 8)),
      hasDeadline: false,
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 8)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Курсовая работа\n\n**Тема:** Разработка мобильного приложения для учета личных финансов\n\n**План работы:**\n1. Анализ существующих решений\n2. Проектирование архитектуры\n3. Разработка пользовательского интерфейса\n4. Реализация бизнес-логики\n5. Тестирование и отладка',
      themeIds: [studyTheme.id],
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now.subtract(const Duration(days: 30)),
      hasDeadline: true,
      deadlineDate: now.add(const Duration(days: 15)),
      hasDateLink: true,
      linkedDate: now.add(const Duration(days: 15)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Материалы по машинному обучению\n\n## Полезные ресурсы\n- [Курс на Coursera](https://www.coursera.org)\n- [Документация TensorFlow](https://www.tensorflow.org)\n- [Книга "Глубокое обучение"](https://www.deeplearningbook.org)\n\n## Библиотеки Python\n- NumPy\n- Pandas\n- Scikit-learn\n- TensorFlow\n- PyTorch',
      themeIds: [studyTheme.id],
      createdAt: now.subtract(const Duration(days: 18)),
      updatedAt: now.subtract(const Duration(days: 18)),
      hasDeadline: false,
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 18)),
      isCompleted: false,
      mediaUrls: [],
    ));

    // 4. Идеи и вдохновение
    notes.add(Note(
      id: generateId(),
      content:
          '# Идеи для мобильного приложения\n\n1. Приложение для обмена книгами с людьми поблизости\n2. Сервис для поиска компаньонов для занятий спортом\n3. Планировщик путешествий с локальными гидами\n4. Платформа для обмена профессиональными навыками',
      themeIds: [ideasTheme.id],
      createdAt: now.subtract(const Duration(days: 22)),
      updatedAt: now.subtract(const Duration(days: 22)),
      hasDeadline: false,
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 22)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Концепция рассказа\n\n**Основная идея:** Мир, где люди могут обмениваться воспоминаниями через специальное устройство.\n\n**Главный герой:** Детектив, расследующий кражу воспоминаний известной личности.\n\n**Сюжетные повороты:**\n- Герой обнаруживает, что его собственные воспоминания были изменены\n- Технология используется для манипуляции обществом\n- Финальное противостояние с создателем технологии',
      themeIds: [ideasTheme.id],
      createdAt: now.subtract(const Duration(days: 9)),
      updatedAt: now.subtract(const Duration(days: 9)),
      hasDeadline: false,
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 9)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Дизайн интерьера гостиной\n\n**Цветовая схема:**\n- Основной цвет: спокойный зеленый\n- Акценты: терракотовый и золотой\n- Дерево: натуральный дуб\n\n**Мебель:**\n- Угловой диван с текстильной обивкой\n- Кофейный столик из состаренного дерева\n- Открытые полки для книг и декора\n- Удобное кресло-качалка',
      themeIds: [ideasTheme.id],
      createdAt: now.subtract(const Duration(days: 16)),
      updatedAt: now.subtract(const Duration(days: 16)),
      hasDeadline: false,
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 16)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Идеи для подарков\n\n## Для мамы\n- Набор косметики натуральных брендов\n- Подписка на кулинарные мастер-классы\n- Персонализированные украшения\n\n## Для папы\n- Набор инструментов для барбекю\n- Умные часы для отслеживания активности\n- Абонемент в спортзал\n\n## Для друга\n- Настольная игра\n- Подарочный сертификат в его любимый магазин\n- Билеты на концерт',
      themeIds: [ideasTheme.id, personalTheme.id],
      createdAt: now.subtract(const Duration(days: 4)),
      updatedAt: now.subtract(const Duration(days: 4)),
      hasDeadline: true,
      deadlineDate: now.add(const Duration(days: 3)),
      hasDateLink: true,
      linkedDate: now.add(const Duration(days: 3)),
      isCompleted: false,
      mediaUrls: [],
    ));

    // 5. Заметки с несколькими темами
    notes.add(Note(
      id: generateId(),
      content:
          '# Проект по анализу данных\n\n**Цель:** Разработать систему анализа данных для маркетингового отдела\n\n**Этапы:**\n1. Сбор требований от заказчика\n2. Изучение существующих решений\n3. Проектирование архитектуры системы\n4. Разработка и тестирование\n5. Внедрение и обучение персонала',
      themeIds: [workTheme.id, studyTheme.id],
      createdAt: now.subtract(const Duration(days: 25)),
      updatedAt: now.subtract(const Duration(days: 25)),
      hasDeadline: true,
      deadlineDate: now.add(const Duration(days: 20)),
      hasDateLink: true,
      linkedDate: now.add(const Duration(days: 20)),
      isCompleted: false,
      mediaUrls: [],
    ));

    notes.add(Note(
      id: generateId(),
      content:
          '# Планирование семейного отдыха\n\n**Варианты направлений:**\n- Италия (история, культура, кухня)\n- Испания (пляжи, архитектура, активности)\n- Греция (древняя история, острова, отдых)\n\n**Бюджет:** примерно 200 000 рублей\n\n**Длительность:** 10-14 дней',
      themeIds: [personalTheme.id, ideasTheme.id],
      createdAt: now.subtract(const Duration(days: 11)),
      updatedAt: now.subtract(const Duration(days: 11)),
      hasDeadline: false,
      hasDateLink: true,
      linkedDate: now.subtract(const Duration(days: 11)),
      isCompleted: false,
      mediaUrls: [],
    ));

    // Обновляем noteIds в темах
    for (var note in notes) {
      for (var themeId in note.themeIds) {
        final themeIndex = themes.indexWhere((theme) => theme.id == themeId);
        if (themeIndex != -1) {
          themes[themeIndex].noteIds.add(note.id);
        }
      }
    }

    return notes;
  }
}
