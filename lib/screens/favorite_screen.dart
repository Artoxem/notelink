import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';
import '../utils/constants.dart';
import 'note_detail_screen.dart';
import 'package:intl/intl.dart';

class FavoriteScreen extends StatefulWidget {
  const FavoriteScreen({super.key});

  @override
  State<FavoriteScreen> createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Загружаем данные при создании экрана
    _loadData();
  }

  Future<void> _loadData() async {
    // Загружаем заметки при инициализации
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    // Отмечаем, что инициализация началась
    setState(() {
      _isInitialized = false;
    });

    try {
      await notesProvider.loadNotes();
      print('📌 FavoriteScreen: загрузка заметок завершена');

      // Получаем избранные заметки для проверки
      final favorites = notesProvider.getFavoriteNotes();
      print(
          '📌 FavoriteScreen._loadData: найдено ${favorites.length} избранных заметок');
    } catch (e) {
      print('📌 FavoriteScreen: ошибка при загрузке заметок: $e');
    } finally {
      // Отмечаем, что инициализация завершена
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
        actions: [
          // Кнопка обновления для ручной перезагрузки
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(
              child:
                  CircularProgressIndicator()) // Показываем индикатор во время загрузки
          : Consumer<NotesProvider>(
              builder: (context, notesProvider, _) {
                // Получаем список избранных заметок
                final favoriteNotes = notesProvider.getFavoriteNotes();
                print(
                    '📌 FavoriteScreen.build: ${favoriteNotes.length} избранных заметок');

                // Если список пуст, показываем сообщение
                if (favoriteNotes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min, // Ограничиваем Column
                      children: [
                        Icon(Icons.star_border,
                            size: 80, color: Colors.amber.withOpacity(0.7)),
                        const SizedBox(height: 16),
                        const Text(
                          'Нет избранных заметок',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Свайпните заметку вправо на главном экране,\nчтобы добавить в избранное',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Показываем список избранных заметок
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: favoriteNotes.length,
                  itemBuilder: (context, index) {
                    final note = favoriteNotes[index];
                    return _buildFavoriteCard(note, notesProvider);
                  },
                );
              },
            ),
    );
  }

  // Построение карточки избранной заметки
  Widget _buildFavoriteCard(Note note, NotesProvider notesProvider) {
    // Определяем цвет индикатора в зависимости от статуса и темы
    Color indicatorColor = _getNoteStatusColor(note);

    // Если есть темы, используем цвет темы
    if (note.themeIds.isNotEmpty) {
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      final themeId = note.themeIds.first;

      try {
        final theme = themesProvider.themes.firstWhere(
          (t) => t.id == themeId,
          orElse: () => NoteTheme(
            id: '',
            name: 'Без темы',
            color: AppColors.secondary.value.toString(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            noteIds: [],
          ),
        );

        if (theme.id.isNotEmpty) {
          try {
            indicatorColor = Color(int.parse(theme.color));
          } catch (e) {
            // Используем fallback цвет, если не удалось распарсить
          }
        }
      } catch (e) {
        print('📌 Ошибка при получении темы: $e');
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewNoteDetails(note),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Цветной индикатор слева
            Container(
              width: 6,
              height: null, // NULL! Позволит контейнеру принять высоту родителя
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),

            // Основное содержимое
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Ограничиваем высоту Column
                  children: [
                    // Верхняя часть с датой и иконкой избранного
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('d MMMM yyyy').format(note.createdAt),
                          style: AppTextStyles.bodySmallLight,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min, // Ограничиваем Row
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            // Кнопка для удаления из избранного
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: AppColors.textOnLight),
                              onPressed: () {
                                print('📌 Удаление из избранного: ${note.id}');
                                notesProvider.toggleFavorite(note.id);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Заметка удалена из избранного'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Содержимое заметки
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        note.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMediumLight,
                      ),
                    ),

                    // Дедлайн (если есть)
                    if (note.hasDeadline && note.deadlineDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: note.isCompleted
                              ? AppColors.deadlineBgGray
                              : AppColors.deadlineBgGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          note.isCompleted
                              ? 'Выполнено'
                              : 'до ${DateFormat('d MMM').format(note.deadlineDate!)}',
                          style: AppTextStyles.deadlineText,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Определение цвета заметки на основе статуса
  Color _getNoteStatusColor(Note note) {
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

  void _viewNoteDetails(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    ).then((_) {
      // Обновляем список после возврата с экрана деталей
      _loadData();
    });
  }
}
