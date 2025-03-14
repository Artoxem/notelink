import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/themes_provider.dart';
import '../providers/notes_provider.dart';
import 'theme_detail_screen.dart';
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
  String? _selectedThemeId;
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

              // Заголовок списка тем
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Все темы',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_selectedThemeId != null)
                        TextButton.icon(
                          icon: const Icon(Icons.filter_list_off),
                          label: const Text('Сбросить фильтр'),
                          onPressed: () {
                            setState(() => _selectedThemeId = null);
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // Список тем (карточки)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final themes = themesProvider.themes;

                      // Фильтрация тем, если выбрана конкретная
                      final filteredThemes = _selectedThemeId != null
                          ? themes
                              .where((t) => t.id == _selectedThemeId)
                              .toList()
                          : themes;

                      if (index >= filteredThemes.length) return null;

                      final theme = filteredThemes[index];
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
        itemCount: themesProvider.themes.length + 1, // +1 для кнопки "Все"
        itemBuilder: (context, index) {
          // Первая кнопка - "Все темы"
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Все темы'),
                selected: _selectedThemeId == null,
                onSelected: (_) {
                  setState(() => _selectedThemeId = null);
                },
                backgroundColor: AppColors.secondary.withOpacity(0.2),
                selectedColor: AppColors.accentSecondary.withOpacity(0.7),
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: _selectedThemeId == null
                      ? Colors.white
                      : AppColors.textOnLight,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }

          // Кнопки для конкретных тем
          final theme = themesProvider.themes[index - 1];

          // Парсим цвет из строки
          Color themeColor;
          try {
            themeColor = Color(int.parse(theme.color));
          } catch (e) {
            themeColor = AppColors.themeColors[0];
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(theme.name),
              selected: _selectedThemeId == theme.id,
              onSelected: (_) {
                setState(() => _selectedThemeId =
                    _selectedThemeId == theme.id ? null : theme.id);
              },
              backgroundColor: themeColor.withOpacity(0.3),
              selectedColor: themeColor.withOpacity(0.7),
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: _selectedThemeId == theme.id
                    ? Colors.white
                    : AppColors.textOnLight,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  // Построение карточки темы с красивым дизайном
  Widget _buildThemeCard(NoteTheme theme, ThemesProvider themesProvider) {
    // Парсим цвет из строки
    Color themeColor;
    try {
      themeColor = Color(int.parse(theme.color));
    } catch (e) {
      themeColor = Colors.blue; // Дефолтный цвет в случае ошибки
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: themeColor.withOpacity(0.6),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThemeDetailScreen(theme: theme),
            ),
          ).then((_) {
            // Перезагружаем темы после возврата
            if (mounted) {
              themesProvider.loadThemes();
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Иконка темы с круглым контейнером
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: themeColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.category,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Информация о теме
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          theme.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textOnLight,
                          ),
                        ),
                        if (theme.description != null &&
                            theme.description!.isNotEmpty)
                          Text(
                            theme.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textOnLight.withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Счетчик заметок
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${theme.noteIds.length} заметок',
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),

              // Отображение связанных заметок
              if (theme.noteIds.isNotEmpty)
                FutureBuilder<List<Note>>(
                  future: themesProvider.getNotesForTheme(theme.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 40,
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
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(
                            'Связанные заметки:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textOnLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Предпросмотр заметок
                        ...previewNotes.map((noteItem) =>
                            _buildNotePreviewer(noteItem, themeColor)),

                        // Индикатор дополнительных заметок
                        if (notes.length > 5)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: themeColor.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: themeColor.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: themeColor.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Виджет предпросмотра заметки в одну строку с иконками медиа
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
        .trim();

    // Подготавливаем иконки медиа-файлов
    String mediaIcons = '';

    // Проверяем содержимое заметки на наличие специальных маркеров и типы файлов
    // Изображения
    if (noteItem.hasImages ||
        noteItem.content.contains('![image]') ||
        noteItem.mediaUrls.any((url) =>
            url.toLowerCase().endsWith('.jpg') ||
            url.toLowerCase().endsWith('.jpeg') ||
            url.toLowerCase().endsWith('.png') ||
            url.toLowerCase().endsWith('.gif'))) {
      mediaIcons += '🖼️ ';
    }

    // Аудио файлы
    if (noteItem.hasAudio ||
        noteItem.content.contains('![audio]') ||
        noteItem.mediaUrls.any((url) =>
            url.toLowerCase().endsWith('.mp3') ||
            url.toLowerCase().endsWith('.wav') ||
            url.toLowerCase().endsWith('.m4a') ||
            url.toLowerCase().endsWith('.ogg'))) {
      mediaIcons += '🔊 ';
    }

    // Файлы
    if (noteItem.hasFiles ||
        noteItem.content.contains('![file]') ||
        noteItem.mediaUrls.any((url) =>
            url.toLowerCase().endsWith('.pdf') ||
            url.toLowerCase().endsWith('.doc') ||
            url.toLowerCase().endsWith('.docx') ||
            url.toLowerCase().endsWith('.txt'))) {
      mediaIcons += '📎 ';
    }

    // Голосовые заметки
    if (noteItem.hasVoiceNotes ||
        noteItem.content.contains('![voice]') ||
        noteItem.content.contains('voice:') ||
        noteItem.voiceNotes.isNotEmpty) {
      mediaIcons += '🎤 ';
    }

    // Специальная обработка для заметки с названием "!" - добавляем иконку аудио
    if (noteItem.content.trim() == "!" || noteItem.content.startsWith("!")) {
      mediaIcons += '🔊 ';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Иконка заметки
            Icon(Icons.note, size: 16, color: themeColor),
            const SizedBox(width: 8),

            // Единая строка с иконками медиа и текстом
            Expanded(
              child: Text(
                mediaIcons + previewText,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textOnLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    );
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
