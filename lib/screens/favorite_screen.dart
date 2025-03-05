import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../utils/constants.dart';
import 'note_detail_screen.dart';
import 'package:intl/intl.dart';
import '../models/theme.dart';
import '../providers/themes_provider.dart'; // Убедитесь, что этот импорт тоже есть

class FavoriteScreen extends StatelessWidget {
  const FavoriteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Загружаем заметки при построении экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('📌 FavoriteScreen: загрузка заметок');
      Provider.of<NotesProvider>(context, listen: false).loadNotes();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Избранное'),
      ),
      body: Consumer<NotesProvider>(
        builder: (context, notesProvider, _) {
          if (notesProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Получаем список избранных заметок
          final favoriteNotes = notesProvider.getFavoriteNotes();
          print(
              '📌 FavoriteScreen: найдено ${favoriteNotes.length} избранных заметок');

          // Если список пуст, показываем сообщение
          if (favoriteNotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_border,
                      size: 80, color: Colors.amber.withOpacity(0.7)),
                  const SizedBox(height: 16),
                  const Text(
                    'Нет избранных заметок',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
              return _buildFavoriteCard(context, note, notesProvider);
            },
          );
        },
      ),
    );
  }

  // Построение карточки избранной заметки
  Widget _buildFavoriteCard(
      BuildContext context, Note note, NotesProvider notesProvider) {
    // Определяем цвет индикатора в зависимости от статуса и темы
    Color indicatorColor;
    if (note.isCompleted) {
      indicatorColor = AppColors.completed;
    } else if (note.hasDeadline && note.deadlineDate != null) {
      final now = DateTime.now();
      final daysUntilDeadline = note.deadlineDate!.difference(now).inDays;

      if (daysUntilDeadline < 0) {
        indicatorColor = AppColors.deadlineUrgent; // Просрочено
      } else if (daysUntilDeadline <= 2) {
        indicatorColor = AppColors.deadlineUrgent; // Срочно
      } else if (daysUntilDeadline <= 7) {
        indicatorColor = AppColors.deadlineNear; // Скоро
      } else {
        indicatorColor = AppColors.deadlineFar; // Не срочно
      }
    } else if (note.themeIds.isNotEmpty) {
      // Используем цвет первой темы заметки
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      final themeId = note.themeIds.first;
      final theme = themesProvider.themes.firstWhere(
        (t) => t.id == themeId,
        orElse: () => NoteTheme(
          id: '',
          name: 'Без темы',
          color: AppColors.themeColors[0].value.toString(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteIds: [],
        ),
      );
      try {
        indicatorColor = Color(int.parse(theme.color));
      } catch (e) {
        indicatorColor = AppColors.themeColors[0];
      }
    } else {
      indicatorColor = AppColors.secondary; // Обычный цвет
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      color: AppColors.cardBackground, // White Asparagus
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewNoteDetails(context, note),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Цветной индикатор слева
            Container(
              width: 6,
              height: double.infinity,
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
                              onPressed: () async {
                                print('📌 Удаление из избранного: ${note.id}');
                                await notesProvider.toggleFavorite(note.id);

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

                    // Нижняя часть с информацией о дедлайне
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

  void _viewNoteDetails(BuildContext context, Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    ).then((_) {
      // Обновляем список после возврата
      Provider.of<NotesProvider>(context, listen: false).loadNotes();
    });
  }
}
