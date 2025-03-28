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
import '../widgets/media_badge.dart';

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
  bool _isColorDark(Color color) {
    // Формула для вычисления яркости (0-1)
    double brightness =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return brightness < 0.3; // Если яркость < 0.3, считаем цвет тёмным
  }

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
                      // Иконка темы с разными формами - ИСПОЛЬЗУЕМ logoType из модели
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
    // Получаем номер иконки (от 01 до 55)
    String iconNumber = (theme.logoType.index + 1).toString().padLeft(2, '0');
    String assetName = 'assets/icons/$iconNumber.png';

    // Проверяем, является ли цвет темы темным
    bool isDark = _isColorDark(themeColor);

    // Создаем круглую форму с иконкой внутри
    return Material(
      shape: const CircleBorder(),
      color: themeColor, // Используем цвет темы как фон
      elevation: 4,
      shadowColor: themeColor.withOpacity(0.3),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.all(6.0), // Отступ для иконки
          child: ClipOval(
            child: isDark
                ? ColorFiltered(
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    child: Image.asset(
                      assetName,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported,
                          color: Colors.white,
                          size: 24,
                        );
                      },
                    ),
                  )
                : Image.asset(
                    assetName,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_not_supported,
                        color: Colors.white,
                        size: 24,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

// Метод для предпросмотра заметки
  Widget _buildNotePreviewer(Note note, Color themeColor) {
    // Извлекаем текст для превью
    String previewText = '';

    // Пробуем извлечь заголовок из Markdown или берем начало контента
    final headerMatch =
        RegExp(r'^#{1,3}\s+(.+)$', multiLine: true).firstMatch(note.content);
    if (headerMatch != null) {
      previewText = headerMatch.group(1) ?? '';
    } else {
      // Если нет заголовка, берем начало текста (первую строку)
      final firstLineBreak = note.content.indexOf('\n');
      if (firstLineBreak > 0) {
        previewText = note.content.substring(0, firstLineBreak).trim();
      } else {
        previewText = note.content.trim();
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

    // Подсчитываем разные типы медиа для значков
    int imagesCount = 0;
    int audioCount = 0;
    int voiceCount = 0;
    int filesCount = 0;

    // Подсчет медиа-файлов
    for (final mediaPath in note.mediaUrls) {
      final extension = mediaPath.toLowerCase();
      if (extension.endsWith('.jpg') ||
          extension.endsWith('.jpeg') ||
          extension.endsWith('.png')) {
        imagesCount++;
      } else if (extension.endsWith('.mp3') ||
          extension.endsWith('.wav') ||
          extension.endsWith('.m4a')) {
        audioCount++;
      } else {
        filesCount++;
      }
    }

    // Подсчет голосовых заметок в контенте
    final voiceMatches =
        RegExp(r'!\[voice\]\(voice:[^)]+\)').allMatches(note.content);
    voiceCount = voiceMatches.length;

    // Высота превью для полного скругления
    const double previewHeight = 32;

    return InkWell(
      onTap: () => _openNoteDetail(note),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(previewHeight / 2),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            height: previewHeight,
            decoration: BoxDecoration(
              color: AppColors.textBackground.withOpacity(0.7),
              borderRadius: BorderRadius.circular(previewHeight / 2),
              border: Border.all(
                color: themeColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Иконки медиа и дедлайна слева
                Padding(
                  padding: const EdgeInsets.only(left: 10, right: 8),
                  child: Row(
                    children: [
                      // Иконка дедлайна (если есть)
                      if (note.hasDeadline && note.deadlineDate != null)
                        Icon(
                          Icons.timer,
                          size: 13, // 60% от обычного размера иконок (20-22px)
                          color: note.isCompleted
                              ? Color(0xFF008000)
                              : Colors.orange,
                        ),

                      // Добавляем небольшой отступ между иконками
                      if (note.hasDeadline &&
                          note.deadlineDate != null &&
                          (note.hasImages ||
                              note.hasAudio ||
                              note.hasFiles ||
                              note.hasVoiceNotes))
                        const SizedBox(width: 6),

                      // Иконки медиа с использованием MediaBadgeGroup
                      if (imagesCount > 0 ||
                          audioCount > 0 ||
                          voiceCount > 0 ||
                          filesCount > 0)
                        MediaBadgeGroup(
                          imagesCount: imagesCount,
                          audioCount: audioCount,
                          voiceCount: voiceCount,
                          filesCount: filesCount,
                          badgeSize: 20, // Уменьшенный размер для превью
                          spacing: 4,
                          showCounters: false, // Без счетчиков
                          showOnlyUnique: true, // Только уникальные типы
                        ),
                    ],
                  ),
                ),

                // Текст превью
                Expanded(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.black, Colors.transparent],
                        stops: const [0.85, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Text(
                      previewText.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textOnLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ),

                // Дата
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 10),
                  child: Text(
                    _formatDate(note.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textOnLight.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
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
