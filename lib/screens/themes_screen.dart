import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/themes_provider.dart';
import '../providers/notes_provider.dart';
import 'theme_detail_screen.dart';
import 'theme_notes_screen.dart';
import 'note_detail_screen.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../utils/constants.dart';

class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  static void showAddThemeDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ThemeDetailScreen(),
      ),
    );
  }

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Загружаем темы при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Загружаем темы и заметки параллельно
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      await Future.wait([
        themesProvider.loadThemes(),
        notesProvider.loadNotes(),
      ]);
    } catch (e) {
      print('Ошибка при загрузке данных: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemesProvider>(
      builder: (context, themesProvider, _) {
        if (_isLoading || themesProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (themesProvider.themes.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // Верхний блок с темами для быстрой навигации
              SliverToBoxAdapter(
                child: _buildThemeFilters(themesProvider),
              ),

              // Разделитель
              const SliverToBoxAdapter(
                child: Divider(
                  height: 1,
                  thickness: 1,
                ),
              ),

              // Список тем (карточки)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Фильтрация тем, если выбрана конкретная
                      final themes = themesProvider.themes;
                      if (index >= themes.length) return null;
                      final theme = themes[index];
                      return _buildThemeCard(theme, themesProvider);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Виджет для фильтров тем в виде горизонтальной ленты
  Widget _buildThemeFilters(ThemesProvider themesProvider) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: themesProvider
            .themes.length, // Убираем +1, так как не нужна кнопка "Все темы"
        itemBuilder: (context, index) {
          // Получаем тему для кнопки
          final theme = themesProvider.themes[index];

          // Парсим цвет из строки
          Color themeColor;
          try {
            themeColor = Color(int.parse(theme.color));
          } catch (e) {
            themeColor = AppColors.themeColors[0];
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(theme.name),
              backgroundColor: themeColor.withOpacity(0.3),
              labelStyle: TextStyle(
                color: AppColors.textOnLight,
              ),
              onPressed: () {
                // Переходим на экран выбранной темы
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ThemeNotesScreen(theme: theme),
                  ),
                ).then((_) {
                  // Перезагружаем темы после возврата
                  if (mounted) {
                    _loadData();
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }

  // Построение карточки темы с красивым дизайном
  // Метод для построения карточки темы
  Widget _buildThemeCard(NoteTheme theme, ThemesProvider themesProvider) {
    // Парсим цвет из строки
    Color themeColor;
    try {
      themeColor = Color(int.parse(theme.color));
    } catch (e) {
      themeColor = AppColors.themeColors[0]; // Дефолтный цвет в случае ошибки
    }

    return Card(
      margin:
          const EdgeInsets.only(bottom: 10), // Уменьшено на 40% (с ~16 до 10)
      elevation: 2,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // Удален цветной бордюр
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Основной контент темы (карточка)
          InkWell(
            onTap: () {
              // Открываем экран со списком заметок этой темы
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ThemeNotesScreen(theme: theme),
                ),
              ).then((_) {
                // Перезагружаем темы после возврата
                if (mounted) {
                  themesProvider.loadThemes();
                }
              });
            },
            onLongPress: () {
              _showThemeOptionsMenu(context, theme);
            },
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12), // Уменьшено
                  child: Row(
                    children: [
                      // Иконка темы с разными формами
                      _buildThemeLogo(theme, themeColor),

                      const SizedBox(width: 12), // Уменьшено

                      // Информация о теме - перестроена
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Название темы
                            Text(
                              theme.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnLight,
                              ),
                            ),
                            const SizedBox(height: 4), // Небольшой отступ

                            // Счетчик заметок теперь под названием темы
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: themeColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'notes: ${theme.noteIds.length}',
                                style: TextStyle(
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                            // Описание, если есть
                            if (theme.description != null &&
                                theme.description!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                    top: 4), // Маленький отступ
                                child: Text(
                                  theme.description!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        AppColors.textOnLight.withOpacity(0.8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Кнопка меню в верхнем правом углу
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(15),
                      onTap: () {
                        _showThemeOptionsMenu(context, theme);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.more_vert,
                          color: AppColors.textOnLight,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Отображение связанных заметок
          if (theme.noteIds.isNotEmpty)
            FutureBuilder<List<Note>>(
              future: themesProvider.getNotesForTheme(theme.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 30, // Уменьшено с 40 до 30
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox();
                }

                // Сортируем заметки по дате (от новых к старым) и берем не более 5
                final List<Note> notes = List<Note>.from(snapshot.data!);
                notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                final previewNotes = notes.take(5).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4), // Уменьшено в 2 раза
                    const Divider(height: 1),
                    const SizedBox(height: 4), // Уменьшено в 2 раза

                    // Предпросмотр заметок
                    ...previewNotes.map((noteItem) =>
                        _buildNotePreviewer(noteItem, themeColor)),

                    // Индикатор дополнительных заметок
                    if (notes.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(
                            top: 6, bottom: 8), // Уменьшено
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4), // Уменьшено
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

// Метод для создания логотипа темы
  Widget _buildThemeLogo(NoteTheme theme, Color themeColor) {
    // Определяем форму и содержимое логотипа в зависимости от типа
    Widget icon;
    ShapeBorder? shape;
    Widget? customShape;

    switch (theme.logoType) {
      case ThemeLogoType.book:
        // Круглая форма с иконкой книги
        icon = const Icon(
          Icons.book,
          color: Colors.white,
          size: 24,
        );
        shape = const CircleBorder();
        break;

      case ThemeLogoType.shapes:
        // Квадратная форма с иконкой геометрических фигур
        icon = const Icon(
          Icons.category,
          color: Colors.white,
          size: 24,
        );
        shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        );
        break;

      case ThemeLogoType.feather:
        // Треугольная форма с иконкой пера
        icon = const Icon(
          Icons.edit,
          color: Colors.white,
          size: 24,
        );
        // Треугольная форма реализована через ClipPath
        customShape = ClipPath(
          clipper: TriangleClipper(),
          child: Container(
            width: 48,
            height: 48,
            color: themeColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: icon,
              ),
            ),
          ),
        );
        break;

      case ThemeLogoType.scroll:
        // Пятиугольная форма с иконкой свитка
        icon = const Icon(
          Icons.description,
          color: Colors.white,
          size: 24,
        );
        // Пятиугольная форма реализована через ClipPath
        customShape = ClipPath(
          clipper: PentagonClipper(),
          child: Container(
            width: 48,
            height: 48,
            color: themeColor,
            child: Center(child: icon),
          ),
        );
        break;

      default:
        // По умолчанию - круглая форма с иконкой книги
        icon = const Icon(
          Icons.book,
          color: Colors.white,
          size: 24,
        );
        shape = const CircleBorder();
    }

    // Если есть кастомная форма, возвращаем ее
    if (customShape != null) {
      return customShape;
    }

    // Стандартная реализация для круглой и квадратной форм
    return Material(
      shape: shape,
      color: themeColor,
      elevation: 4,
      shadowColor: themeColor.withOpacity(0.3),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(child: icon),
      ),
    );
  }

// Метод для предпросмотра заметки
  Widget _buildNotePreviewer(Note noteItem, Color themeColor) {
    // Извлекаем текст для превью
    String previewText = '';

    // Пробуем извлечь заголовок из Markdown или берем начало контента
    final headerMatch = RegExp(r'^#{1,3}\s+(.+)$', multiLine: true)
        .firstMatch(noteItem.content);
    if (headerMatch != null) {
      previewText = headerMatch.group(1) ?? '';
    } else {
      // Если нет заголовка, берем начало текста (первую строку)
      final firstLineBreak = noteItem.content.indexOf('\n');
      if (firstLineBreak > 0) {
        previewText = noteItem.content.substring(0, firstLineBreak).trim();
      } else {
        previewText = noteItem.content.trim();
      }
    }

    // Удаляем разметку Markdown из текста превью
    previewText = previewText
        .replaceAll(RegExp(r'#{1,3}\s+'), '') // Убираем заголовки
        .replaceAll(RegExp(r'\*\*|\*|__|\[.*?\]\(.*?\)'),
            '') // Убираем жирный, курсив, ссылки
        .replaceAll(RegExp(r'!\[voice\]\(voice:[^)]+\)'),
            '') // Убираем голосовые заметки
        .trim();

    return InkWell(
      onTap: () => _openNoteDetail(noteItem),
      borderRadius: BorderRadius.circular(8),
      child: Card(
        margin: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 3), // Уменьшено на 25%
        elevation: 0.5,
        color: AppColors.textBackground.withOpacity(0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: themeColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6), // Уменьшено
          child: Row(
            children: [
              // Блок с иконками медиа
              if (_hasMediaContent(noteItem))
                Container(
                  padding: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: AppColors.secondary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                  ),
                  child: _buildMediaIcon(noteItem),
                ),

              // Отступ после иконок или если их нет, то от начала
              const SizedBox(width: 8),

              // Текст заметки с эффектом затухания
              Expanded(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.black, Colors.transparent],
                      stops: const [
                        0.85,
                        1.0
                      ], // 85% текста видно полностью, затем затухание
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Text(
                    previewText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textOnLight,
                    ),
                    maxLines: 1,
                    overflow:
                        TextOverflow.fade, // Используем fade вместо ellipsis
                  ),
                ),
              ),

              // Дата создания заметки
              Text(
                _formatDate(noteItem.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textOnLight.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Метод для показа контекстного меню
  void _showThemeOptionsMenu(BuildContext context, NoteTheme theme) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading:
                    const Icon(Icons.edit, color: AppColors.accentSecondary),
                title: const Text('Редактировать тему'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Удаляем параметр isEditMode: true
                      builder: (context) => ThemeDetailScreen(theme: theme),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _loadData();
                    }
                  });
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.note, color: AppColors.accentSecondary),
                title: const Text('Просмотреть все заметки'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ThemeNotesScreen(theme: theme),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить тему'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(theme);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Отмена'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // Диалог подтверждения удаления
  void _showDeleteConfirmation(NoteTheme theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тему'),
        content: Text('Вы действительно хотите удалить тему "${theme.name}"? '
            'Это действие нельзя будет отменить. Заметки останутся, но будут отвязаны от этой темы.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              final themesProvider =
                  Provider.of<ThemesProvider>(context, listen: false);
              await themesProvider.deleteTheme(theme.id);

              if (mounted) {
                _loadData();
              }
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Проверка наличия медиа в заметке
  bool _hasMediaContent(Note note) {
    return note.hasImages ||
        note.hasAudio ||
        note.hasFiles ||
        note.hasVoiceNotes ||
        RegExp(r'!\[voice\]\(voice:[^)]+\)').hasMatch(note.content);
  }

// Создание иконки медиа для заметки
  Widget _buildMediaIcon(Note note) {
    // Приоритет иконок: изображение > голос > файл
    if (note.hasImages) {
      return const Icon(Icons.image, size: 16, color: AppColors.accentPrimary);
    } else if (note.hasAudio ||
        note.hasVoiceNotes ||
        RegExp(r'!\[voice\]\(voice:[^)]+\)').hasMatch(note.content)) {
      return const Icon(Icons.mic, size: 16, color: Colors.purple);
    } else if (note.hasFiles) {
      return const Icon(Icons.attach_file, size: 16, color: Colors.blue);
    }

    return const Icon(Icons.note, size: 16, color: AppColors.textOnLight);
  }

  // Открытие заметки для просмотра
  void _openNoteDetail(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    ).then((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  // Форматирование даты для превью
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Сегодня';
    } else if (difference.inDays == 1) {
      return 'Вчера';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн. назад';
    } else {
      // Форматируем дату с ведущими нулями как "06.03"
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
    }
  }

  // Пустое состояние, когда нет тем
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined,
              size: 80, color: AppColors.accentSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'У вас пока нет тем',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Создайте темы для организации ваших заметок',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ThemeDetailScreen(),
                ),
              ).then((_) {
                // Перезагружаем темы после возврата
                if (mounted) {
                  _loadData();
                }
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Создать первую тему'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Клиппер для треугольной формы
class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(TriangleClipper oldClipper) => false;
}

// Клиппер для пятиугольной формы
class PentagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height);
    path.lineTo(size.width * 0.2, size.height);
    path.lineTo(0, size.height * 0.4);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(PentagonClipper oldClipper) => false;
}
