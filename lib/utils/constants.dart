import 'package:flutter/material.dart';

class AppColors {
  // Основные цвета приложения
  static const primary = Color.fromARGB(255, 190, 196, 195); // ФОН
  static const cardBackground =
      Color.fromARGB(255, 198, 197, 179); // White Asparagus
  static const secondary = Color.fromARGB(255, 59, 92, 23); // Evergreen

  // Акцентные цвета
  static const accentPrimary =
      Color.fromARGB(255, 196, 68, 22); // Last of Lettuce - кнопка плюс
  static const accentSecondary = Color(0xFF125B49); // Evergreen

  // Фон для текстовых полей (светлый)
  static const textBackground =
      Color.fromARGB(255, 224, 216, 202); // Dipped in Cream

  // Цвета текста
  static const textOnLight =
      Color.fromARGB(255, 10, 21, 19); // Зеленый текст для светлого фона
  static const textOnDark =
      Color.fromARGB(255, 10, 21, 19); // Почти белый для текста на темном фоне

  // Цвет для нижней навигации
  static const navSelectedItem =
      Color.fromARGB(255, 215, 255, 162); // Last of Lettuce
  static const navUnselectedItem =
      Color.fromARGB(255, 251, 249, 221); // White Asparagus

  // Цвета для статусов заметок (дедлайны и выполнение)
  static const completed = Color(0xFF125B49); // Evergreen
  static const deadlineFar =
      Color(0xFFAADD66); // Last of Lettuce - зеленый дедлайн
  static const deadlineNear = Color(0xFF888888); // Серый цвет для дедлайна
  static const deadlineUrgent = Color(0xFF888888); // Серый цвет для дедлайна
  static const deadlineLine =
      Color(0xFFAADD66); // Last of Lettuce - линия дедлайна

  // Цвета для тем (категорий) - цветные точки
  static const List<Color> themeColors = [
    Color.fromARGB(255, 75, 173, 0),
    Color.fromARGB(255, 187, 162, 0),
    Color(0xFFFF4500),
    Color(0xFF27AE60),
    Color.fromARGB(255, 179, 0, 0),
    Color(0xFF30336B),
    Color.fromARGB(255, 99, 0, 102),
    Color.fromARGB(255, 125, 73, 41),
    Color.fromARGB(255, 22, 66, 177),
    Color.fromARGB(255, 255, 0, 81),
    Color.fromARGB(255, 0, 0, 0),
    Color.fromARGB(255, 192, 60, 126),
    Color(0xFF0B4619),
    Color.fromARGB(255, 92, 11, 39),
  ];

  // Системные цвета для интерфейса
  static const success = Color(0xFFAADD66); // Last of Lettuce
  static const error = Color(0xFF8B0000); // Neon Current
  static const warning = Color(0xFFF5D300); // Neon Gold
  static const info = Color(0xFF125B49); // Evergreen

  // Цвета для FAB
  static const fabBackground =
      Color.fromARGB(255, 107, 170, 24); // Last of Lettuce
  static const fabIcon = Color(0xFFFFFFFF); // White

  // Специальные цвета для плашек дедлайнов
  static const deadlineBgGreen =
      Color(0xFFCCEEAA); // Светло-зеленый фон для дедлайнов
  static const deadlineBgGray =
      Color(0xFFD8D8D8); // Серый фон для выполненных задач

  // Новые цвета для медиа и бейджей
  static const mediaBadges = {
    'image': Color(0xFF009688), // Teal для изображений
    'audio': Color(0xFF9C27B0), // Purple для аудио
    'voice': Color(0xFF673AB7), // Deep Purple для голосовых заметок
    'file': Color(0xFF2196F3), // Blue для файлов
  };

  // Градиенты для эффектов анимации
  static const gradients = {
    'fadeBottom': [Colors.black, Colors.transparent],
    'fadeBottomStops': [0.7, 1.0],
    'highlight': [Color(0x33FFFFFF), Color(0x00FFFFFF)],
    'highlightStops': [0.0, 1.0],
  };

  // Фоны для карточек с улучшенной контрастностью
  static const cardElevatedBackground =
      Color.fromARGB(255, 208, 207, 189); // Более светлый фон для карточек
  static const cardHighlightBorder =
      Color.fromARGB(255, 215, 255, 162); // Подсветка для выбранных карточек
}

class AppTextStyles {
  // Заголовки
  // Существующие стили текста (заголовки)
  static const heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors
        .textOnDark, // Изменено с Color.fromARGB(255, 179, 221, 213) на AppColors.textOnDark
    letterSpacing: 0.5,
  );

  static const heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors
        .textOnDark, // Изменено с Color.fromARGB(255, 179, 221, 213) на AppColors.textOnDark
    letterSpacing: 0.5,
  );

  static const heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors
        .textOnDark, // Изменено с Color.fromARGB(255, 179, 221, 213) на AppColors.textOnDark
    letterSpacing: 0.5,
  );

  // Заголовки на светлом фоне
  static const heading1Light = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textOnLight,
    letterSpacing: 0.5,
  );

  static const heading2Light = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textOnLight,
    letterSpacing: 0.5,
  );

  static const heading3Light = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textOnLight,
    letterSpacing: 0.5,
  );

  // Основной текст
  static const bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.textOnDark,
    letterSpacing: 0.3,
  );

  static const bodyMedium = TextStyle(
    fontSize: 14,
    color: AppColors.textOnDark,
    letterSpacing: 0.3,
  );

  static const bodySmall = TextStyle(
    fontSize: 12,
    color: AppColors.textOnDark,
    letterSpacing: 0.3,
  );

// Основной текст на светлом фоне (для карточек)
  static const bodyLargeLight = TextStyle(
    fontSize: 16,
    color: Color(0xFF125B49), // Зеленый текст
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const bodyMediumLight = TextStyle(
    fontSize: 14,
    color: Color(0xFF125B49), // Зеленый текст
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const bodySmallLight = TextStyle(
    fontSize: 12,
    color: Color(0xFF125B49), // Зеленый текст
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  // Стили для дедлайнов
  static const deadlineText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnLight,
    letterSpacing: 0.3,
  );
}

class AppIcons {
  static const home = Icons.home;
  static const notes = Icons.note;
  static const calendar = Icons.calendar_today;
  static const themes = Icons.category;
  static const search = Icons.search;
  static const add = Icons.add;
  static const edit = Icons.edit;
  static const delete = Icons.delete;
  static const export = Icons.upload_file;
  static const text = Icons.text_fields;
  static const camera = Icons.camera_alt;
  static const microphone = Icons.mic;
  static const attachment = Icons.attach_file;
  static const deadline = Icons.timer;
  static const link = Icons.link;
  static const done = Icons.check_circle;
  static const settings = Icons.settings;
  static const more = Icons.more_vert;
  static const format = Icons.format_paint;
  static const bold = Icons.format_bold;
  static const italic = Icons.format_italic;
  static const bulletList = Icons.format_list_bulleted;
  static const numberedList = Icons.format_list_numbered;
  static const focus = Icons.center_focus_strong;
  static const connectLink = Icons.link;
  static const grid = Icons.grid_view;
  static const list = Icons.view_list;
  static const connections = Icons.bubble_chart;
  static const favorite = Icons.star;
}

class AppDimens {
  // Базовые отступы
  static const double smallPadding = 8.0;
  static const double mediumPadding = 16.0;
  static const double largePadding = 24.0;

  // Скругления
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 8.0;
  static const double chipBorderRadius = 16.0;

  // Размеры элементов
  static const double cardElevation = 2.0;
  static const double iconSize = 24.0;
  static const double smallIconSize = 16.0;
  static const double largeIconSize = 32.0;

  // Высоты элементов
  static const double appBarHeight = 56.0;
  static const double bottomNavBarHeight = 60.0;
  static const double buttonHeight = 48.0;

  // Толщина линий
  static const double thinLineThickness = 1.0;
  static const double mediumLineThickness = 2.0;
  static const double thickLineThickness = 3.0;

  // Размеры для календаря
  static const double calendarCellSize = 50.0;
  static const double calendarDayTextSize = 12.0;
  static const double calendarDotSize = 6.0;
}

class AppMediaDimens {
  // Размеры для превью медиа
  static const double badgeSize = 24.0;
  static const double badgeSmallSize = 20.0;
  static const double badgeIconSize = 16.0;
  static const double badgeCountSize = 8.0;

  // Размеры для миниатюр
  static const double thumbnailSize = 40.0;
  static const double thumbnailBorderRadius = 4.0;

  // Размеры для аудио визуализации
  static const double audioWaveWidth = 40.0;
  static const double audioWaveHeight = 20.0;
  static const int audioWaveSegments = 12;
}

// Класс для анимаций
class AppAnimations {
  // Длительность анимаций
  static const Duration shortDuration = Duration(milliseconds: 150);
  static const Duration mediumDuration = Duration(milliseconds: 300);
  static const Duration longDuration = Duration(milliseconds: 500);

  // Кривые анимаций
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve sharpCurve = Curves.easeInOutQuint;

  // Новые анимации для интерактивных элементов
  static const Duration feedbackDuration = Duration(milliseconds: 100);
  static const Duration highlightDuration = Duration(milliseconds: 200);
  static const Duration expandDuration = Duration(milliseconds: 250);

  // Кривые для более плавных анимаций
  static const Curve popCurve = Curves.easeOutBack;
  static const Curve highlightCurve = Curves.easeOutQuad;
  static const Curve expandCurve = Curves.easeInOutCubic;

  // Коэффициенты масштабирования
  static const double pressedScale = 0.95;
  static const double hoverScale = 1.05;
  static const double normalScale = 1.0;
}

class AppEffects {
  // Тактильная обратная связь
  static const int lightFeedback = 10;
  static const int mediumFeedback = 20;
  static const int heavyFeedback = 30;

  // Стили подсветки элементов
  static BoxDecoration cardHighlight(Color color) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
      border: Border.all(
        color: color.withOpacity(0.7),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.3),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ],
    );
  }

  // Градиент для затухания текста
  static const List<double> fadeOutStops = [0.7, 1.0];
  static const List<Color> fadeOutColors = [Colors.black, Colors.transparent];
  static const Alignment fadeOutBegin = Alignment.topCenter;
  static const Alignment fadeOutEnd = Alignment.bottomCenter;
}

// Класс для теней
class AppShadows {
  static const BoxShadow small = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 4,
    offset: Offset(0, 1),
  );

  static const BoxShadow medium = BoxShadow(
    color: Color(0x40000000),
    blurRadius: 6,
    offset: Offset(0, 2),
  );

  static const BoxShadow large = BoxShadow(
    color: Color(0x4D000000),
    blurRadius: 10,
    offset: Offset(0, 4),
  );
}

// Класс с константами для Markdown
class MarkdownSyntax {
  static const String bold = '**';
  static const String italic = '*';
  static const String heading1 = '# ';
  static const String heading2 = '## ';
  static const String heading3 = '### ';
  static const String bulletList = '- ';
  static const String numberedList = '1. ';
  static const String quote = '> ';
  static const String codeBlock = '```';
  static const String inlineCode = '`';
}

// Добавляем перечисление для типов отображения заметок
enum NoteViewMode {
  card,
  list,
}

// Добавляем перечисление для типов сортировки заметок
enum NoteSortMode {
  dateDesc, // Сначала новые
  dateAsc, // Сначала старые
  alphabetical, // По алфавиту
}

// Расширяем перечисление тем приложения
enum AppThemeMode {
  light,
  dark,
  system,
}
