import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';
import '../utils/constants.dart';
import '../screens/note_detail_screen.dart';
import '../utils/note_status_utils.dart';
import 'package:intl/intl.dart';

class SwipeableNoteCard extends StatefulWidget {
  final Note note;
  final Function? onDelete;
  final Future<bool> Function()? onFavorite;

  const SwipeableNoteCard({
    Key? key,
    required this.note,
    this.onDelete,
    this.onFavorite,
  }) : super(key: key);

  @override
  State<SwipeableNoteCard> createState() => _SwipeableNoteCardState();
}

class _SwipeableNoteCardState extends State<SwipeableNoteCard> {
  // Флаг для отслеживания, была ли карточка недавно помечена как избранная
  bool _recentlyFavorited = false;

  @override
  Widget build(BuildContext context) {
    // Определяем цвет бордюра в зависимости от статуса
    final borderColor = NoteStatusUtils.getNoteStatusColor(widget.note);

    // Создаем константы для отступов и радиуса скругления для согласованности
    const cardMargin = EdgeInsets.symmetric(vertical: 8, horizontal: 4);
    const borderRadius =
        BorderRadius.all(Radius.circular(AppDimens.cardBorderRadius));

    // Используем Padding снаружи, чтобы сохранить пространство между карточками
    return Padding(
      padding: cardMargin,
      child: Dismissible(
        key: Key('note-${widget.note.id}'),
        direction: DismissDirection.horizontal,

        // Фон для свайпа вправо (избранное)
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20.0),
          color: Colors.transparent,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.fabBackground.withOpacity(0.8),
                  AppColors.fabBackground.withOpacity(0.6)
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Icon(
                  Icons.star,
                  color: Colors.orange,
                  size: 22,
                ),
              ],
            ),
          ),
        ),

        // Фон для свайпа влево (удаление)
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          color: Colors.transparent,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.fabBackground.withOpacity(0.6),
                  AppColors.fabBackground.withOpacity(0.8),
                ],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Spacer(),
                Icon(
                  Icons.delete,
                  color: Colors.red,
                  size: 22,
                ),
              ],
            ),
          ),
        ),

        // Подтверждение действия при свайпе
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Свайп влево - удаление
            return await showDialog(
                // Код удаления без изменений...
                );
          } else if (direction == DismissDirection.startToEnd) {
            // Свайп вправо - добавление в избранное
            if (widget.onFavorite != null) {
              final success = await widget.onFavorite!();

              // Устанавливаем флаг только если операция успешна
              if (success) {
                setState(() {
                  _recentlyFavorited = true;
                });
                // Сбрасываем флаг через некоторое время
                Future.delayed(const Duration(milliseconds: 1500), () {
                  if (mounted) {
                    setState(() {
                      _recentlyFavorited = false;
                    });
                  }
                });
              }
            }
            return false; // Не убираем карточку после свайпа для избранного
          }
          return false;
        },

        // Действие при успешном свайпе
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart &&
              widget.onDelete != null) {
            widget.onDelete!();
          }
        },

        // Основной контент карточки - без внешних отступов
        child: Stack(
          children: [
            Card(
              // Важно! Убираем отступы у самой карточки
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius,
                side: BorderSide(
                  color: borderColor,
                  width: 2,
                ),
              ),
              elevation: AppDimens.cardElevation,
              child: InkWell(
                onTap: () => _openNoteDetails(widget.note),
                borderRadius: borderRadius,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Верхняя часть с датой
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('d MMMM yyyy')
                                .format(widget.note.createdAt),
                            style: AppTextStyles.bodySmall,
                          ),
                          if (widget.note.hasDeadline &&
                              widget.note.deadlineDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: borderColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.note.isCompleted
                                    ? 'Выполнено'
                                    : 'до ${DateFormat('d MMM').format(widget.note.deadlineDate!)}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: borderColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Содержимое заметки
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          widget.note.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),

                      // Темы заметки
                      if (widget.note.themeIds.isNotEmpty)
                        _buildThemeTags(widget.note.themeIds),
                    ],
                  ),
                ),
              ),
            ),

            // Анимированная звездочка при добавлении в избранное
            if (_recentlyFavorited || widget.note.isFavorite)
              Positioned(
                top: 12,
                right: 12,
                child: AnimatedOpacity(
                  opacity: _recentlyFavorited
                      ? 1.0
                      : (widget.note.isFavorite ? 0.8 : 0.0),
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: _recentlyFavorited ? 36 : 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Отображение тегов тем
  Widget _buildThemeTags(List<String> themeIds) {
    return Consumer<ThemesProvider>(
      builder: (context, themesProvider, _) {
        final themes = themeIds
            .map((id) => themesProvider.themes.firstWhere(
                  (t) => t.id == id,
                  orElse: () => themesProvider.themes.firstWhere(
                    (t) => true,
                    orElse: () => NoteTheme(
                      id: '',
                      name: 'Unknown',
                      color: AppColors.themeColors[0].value.toString(),
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                      noteIds: [],
                    ),
                  ),
                ))
            .where((t) => t.id.isNotEmpty)
            .toList();

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: themes.map((theme) {
            Color themeColor;
            try {
              themeColor = Color(int.parse(theme.color));
            } catch (e) {
              themeColor = AppColors.themeColors[0];
            }

            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: themeColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Text(
                theme.name,
                style: TextStyle(
                  fontSize: 12,
                  color: themeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Открытие экрана детальной информации о заметке
  void _openNoteDetails(Note note) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            NoteDetailScreen(note: note),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(1.0, 0.0);
          var end = Offset.zero;
          var curve = Curves.easeOutQuint;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: AppAnimations.mediumDuration,
      ),
    ).then((_) {
      // Перезагружаем заметки после возврата с экрана редактирования
      Provider.of<NotesProvider>(context, listen: false).loadNotes();
    });
  }
}
