import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';
import '../utils/constants.dart';
import '../screens/note_detail_screen.dart';
import 'package:intl/intl.dart';

class SwipeableNoteCard extends StatefulWidget {
  final Note note;
  final Function? onDelete;
  final Function? onFavorite;

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
  // Контроллер для отслеживания смахиваний
  late final DismissDirectionCallback _onDismissed;

  // Флаг для отслеживания, была ли карточка недавно помечена как избранная
  bool _recentlyFavorited = false;

  @override
  void initState() {
    super.initState();

    // Инициализируем функцию-обработчик для смахиваний
    _onDismissed = (DismissDirection direction) {
      if (direction == DismissDirection.endToStart) {
        // Смахивание влево - удаление
        if (widget.onDelete != null) {
          widget.onDelete!();
        }
      } else if (direction == DismissDirection.startToEnd) {
        // Смахивание вправо - добавление в избранное
        if (widget.onFavorite != null) {
          widget.onFavorite!();
          // Устанавливаем флаг для показа анимации
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
    };
  }

  @override
  Widget build(BuildContext context) {
    // Определяем цвет бордюра в зависимости от статуса
    final borderColor = _getNoteStatusColor(widget.note);

    return Dismissible(
      key: Key('note-${widget.note.id}'),
      direction: DismissDirection.horizontal,
      onDismissed: _onDismissed,

      // Фон при смахивании влево (удаление)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),

      // Фон при смахивании вправо (добавление в избранное)
      secondaryBackground: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        color: Colors.amber,
        child: const Icon(
          Icons.star,
          color: Colors.white,
        ),
      ),

      // Подтверждение перед удалением
      confirmDismiss: (DismissDirection direction) async {
        if (direction == DismissDirection.endToStart) {
          // Подтверждение удаления
          return await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Удалить заметку'),
                content:
                    const Text('Вы уверены, что хотите удалить эту заметку?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Удалить',
                        style: TextStyle(color: Colors.red)),
                  ),
                ],
              );
            },
          );
        } else {
          // Добавление в избранное не требует подтверждения
          return true;
        }
      },

      // Основной контент карточки
      child: Stack(
        children: [
          _buildNoteCard(borderColor),

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
    );
  }

  // Построение карточки заметки
  Widget _buildNoteCard(Color borderColor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
        side: BorderSide(
          color: borderColor,
          width: 2,
        ),
      ),
      elevation: AppDimens.cardElevation,
      child: InkWell(
        onTap: () => _openNoteDetails(widget.note),
        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
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
                    DateFormat('d MMMM yyyy').format(widget.note.createdAt),
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

  // Определение цвета статуса заметки
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
