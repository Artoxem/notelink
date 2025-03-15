import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';
import '../utils/constants.dart';
import '../utils/note_status_utils.dart';
import '../screens/note_detail_screen.dart';
import 'package:intl/intl.dart';

enum NoteListAction {
  edit,
  favorite,
  delete,
  complete,
  unlinkFromTheme,
  custom
}

enum SwipeDirection { none, left, right, both }

class NoteListWidget extends StatefulWidget {
  final List<Note> notes;
  final String? emptyMessage;
  final Function(Note note)? onNoteTap;
  final Function(Note note, NoteListAction action)? onActionSelected;
  final Function(Note note)? onNoteDeleted;
  final Function(Note note)? onNoteFavoriteToggled;
  final Function(Note note)? onNoteUnlinked;
  final bool showThemeBadges;
  final bool isInThemeView;
  final String? themeId;
  final bool useCachedAnimation;
  final SwipeDirection swipeDirection;
  final bool showOptionsOnLongPress;
  final List<NoteListAction> availableActions;

  const NoteListWidget({
    Key? key,
    required this.notes,
    this.emptyMessage,
    this.onNoteTap,
    this.onActionSelected,
    this.onNoteDeleted,
    this.onNoteFavoriteToggled,
    this.onNoteUnlinked,
    this.showThemeBadges = true,
    this.isInThemeView = false,
    this.themeId,
    this.useCachedAnimation = true,
    this.swipeDirection = SwipeDirection.both,
    this.showOptionsOnLongPress = true,
    this.availableActions = const [
      NoteListAction.edit,
      NoteListAction.favorite,
      NoteListAction.delete
    ],
  }) : super(key: key);

  @override
  State<NoteListWidget> createState() => _NoteListWidgetState();
}

class _NoteListWidgetState extends State<NoteListWidget>
    with SingleTickerProviderStateMixin {
  // Для анимаций элементов списка
  late AnimationController _animationController;
  final Map<String, Animation<double>> _itemAnimations = {};

  // Кэш для оптимизации производительности
  final Map<String, Color> _noteColorCache = {};

  @override
  void initState() {
    super.initState();

    if (widget.useCachedAnimation) {
      _animationController = AnimationController(
        vsync: this,
        duration: AppAnimations.shortDuration,
      );

      // Инициализируем анимации
      _initializeItemAnimations();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    if (widget.useCachedAnimation) {
      _animationController.dispose();
    }
    _noteColorCache.clear();
    super.dispose();
  }

  // Инициализация анимаций элементов списка
  void _initializeItemAnimations() {
    if (!widget.useCachedAnimation) return;

    for (int i = 0; i < widget.notes.length; i++) {
      final note = widget.notes[i];
      _itemAnimations[note.id] = CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          i / widget.notes.length * 0.6, // Задержка в зависимости от позиции
          i / widget.notes.length * 0.6 + 0.4, // Перекрытие для плавности
          curve: Curves.easeOutQuint,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notes.isEmpty) {
      return Center(
        child: Text(
          widget.emptyMessage ?? 'Нет заметок для отображения',
          style: const TextStyle(
            fontSize: 16,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.notes.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final note = widget.notes[index];
        return _buildNoteItem(note);
      },
    );
  }

  Widget _buildNoteItem(Note note) {
    // Применяем анимацию, если включена
    if (widget.useCachedAnimation && _itemAnimations.containsKey(note.id)) {
      return AnimatedBuilder(
        animation: _itemAnimations[note.id]!,
        builder: (context, child) {
          return Opacity(
            opacity: _itemAnimations[note.id]!.value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - _itemAnimations[note.id]!.value)),
              child: child,
            ),
          );
        },
        child: _buildSwipeableNoteItem(note),
      );
    }

    return _buildSwipeableNoteItem(note);
  }

  Widget _buildSwipeableNoteItem(Note note) {
    // Получаем цвет для заметки
    final Color noteColor = _getNoteStatusColor(note);

    // Определяем направления свайпа
    final DismissDirection dismissDirection = _getDismissDirection();

    // Создаём свайпабельный элемент
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Dismissible(
        key: Key('note_${note.id}'),
        direction: dismissDirection,

        // Фон при свайпе вправо (избранное)
        background: widget.swipeDirection != SwipeDirection.left
            ? Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20.0),
                color: Colors.amber,
                child: Icon(
                  note.isFavorite ? Icons.star_border : Icons.star,
                  color: Colors.white,
                ),
              )
            : null,

        // Обработка свайпов
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Свайп влево
            if (widget.isInThemeView) {
              // Удаление заметки
              final result = await _showDeleteConfirmationDialog(note);
              if (result && widget.onNoteDeleted != null) {
                widget.onNoteDeleted!(note);
              }
              return result;
            } else {
              // Отвязка от темы
              if (widget.themeId != null) {
                final result = await _showUnlinkConfirmationDialog(note);
                if (result && widget.onNoteUnlinked != null) {
                  widget.onNoteUnlinked!(note);
                }
                return result;
              }
            }
          } else if (direction == DismissDirection.startToEnd) {
            // Свайп вправо - добавление/удаление из избранного
            final notesProvider =
                Provider.of<NotesProvider>(context, listen: false);
            await notesProvider.toggleFavorite(note.id);

            // Уведомляем о смене статуса
            if (widget.onNoteFavoriteToggled != null) {
              widget.onNoteFavoriteToggled!(note);
            }

            // Показываем сообщение
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(note.isFavorite
                      ? 'Заметка удалена из избранного'
                      : 'Заметка добавлена в избранное'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            return false; // Не убираем карточку
          }

          return false;
        },

        // Построение элемента списка
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: noteColor,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () {
              if (widget.onNoteTap != null) {
                widget.onNoteTap!(note);
              } else {
                _openNoteDetail(note);
              }
            },
            onLongPress: widget.showOptionsOnLongPress
                ? () => _showNoteOptionsMenu(note)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Верхняя часть с датой и иконками состояния
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('d MMMM yyyy').format(note.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textOnLight.withOpacity(0.7),
                        ),
                      ),
                      Row(
                        children: [
                          if (note.hasDeadline && note.deadlineDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: noteColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                note.isCompleted
                                    ? 'Выполнено'
                                    : 'До ${DateFormat('d MMM').format(note.deadlineDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: noteColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (note.isFavorite)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Текст заметки
                  Text(
                    _formatNoteContent(note.content),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textOnLight,
                    ),
                  ),

                  // Индикаторы медиа и темы
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        if (_hasMediaContent(note)) _buildMediaIndicators(note),

                        const Spacer(),

                        // Отображаем теги тем, если нужно
                        if (widget.showThemeBadges &&
                            note.themeIds.isNotEmpty &&
                            !widget.isInThemeView)
                          _buildThemeBadges(note),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Получение цвета для заметки с кэшированием
  Color _getNoteStatusColor(Note note) {
    // Проверяем кэш
    if (_noteColorCache.containsKey(note.id)) {
      return _noteColorCache[note.id]!;
    }

    Color color = NoteStatusUtils.getNoteStatusColor(note);

    // В режиме просмотра темы используем цвет текущей темы для заметок
    if (widget.isInThemeView && widget.themeId != null) {
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      final theme = themesProvider.getThemeById(widget.themeId!);

      if (theme != null) {
        try {
          color = Color(int.parse(theme.color));
        } catch (e) {
          // Оставляем изначальный цвет в случае ошибки
        }
      }
    }
    // В общем режиме используем цвет первой темы заметки, если есть
    else if (note.themeIds.isNotEmpty) {
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      final themeId = note.themeIds.first;
      final theme = themesProvider.getThemeById(themeId);

      if (theme != null) {
        try {
          color = Color(int.parse(theme.color));
        } catch (e) {
          // Оставляем цвет статуса в случае ошибки
        }
      }
    }

    // Сохраняем в кэш и возвращаем цвет
    _noteColorCache[note.id] = color;
    return color;
  }

  // Определение направления свайпа на основе настроек виджета
  DismissDirection _getDismissDirection() {
    switch (widget.swipeDirection) {
      case SwipeDirection.left:
        return DismissDirection.endToStart;
      case SwipeDirection.right:
        return DismissDirection.startToEnd;
      case SwipeDirection.both:
        return DismissDirection.horizontal;
      case SwipeDirection.none:
      default:
        return DismissDirection.none;
    }
  }

  // Форматирование текста заметки для отображения
  String _formatNoteContent(String content) {
    // Удаляем разметку Markdown
    String formattedContent = content
        .replaceAll(RegExp(r'#{1,3}\s+'), '') // Заголовки
        .replaceAll(RegExp(r'\*\*|\*|__'), '') // Жирный, курсив
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // Ссылки
        .replaceAll(
            RegExp(r'!\[voice\]\(voice:[^)]+\)'), '') // Голосовые заметки
        .trim();

    return formattedContent;
  }

  // Проверка наличия медиа-контента
  bool _hasMediaContent(Note note) {
    return note.hasImages ||
        note.hasAudio ||
        note.hasFiles ||
        note.hasVoiceNotes ||
        note.content.contains('![voice]');
  }

  // Построение индикаторов медиа
  Widget _buildMediaIndicators(Note note) {
    List<Widget> indicators = [];

    // Изображения
    if (note.hasImages) {
      indicators.add(
        _buildMediaIndicator(Icons.image, AppColors.accentPrimary),
      );
    }

    // Аудио и голосовые заметки (только микрофон)
    if (note.hasAudio ||
        note.hasVoiceNotes ||
        note.content.contains('![voice]')) {
      indicators.add(
        _buildMediaIndicator(Icons.mic, Colors.purple),
      );
    }

    // Файлы
    if (note.hasFiles) {
      indicators.add(
        _buildMediaIndicator(Icons.attach_file, Colors.blue),
      );
    }

    return Row(children: indicators);
  }

  Widget _buildMediaIndicator(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        size: 16,
        color: color,
      ),
    );
  }

  // Построение тегов тем
  Widget _buildThemeBadges(Note note) {
    return Consumer<ThemesProvider>(
      builder: (context, themesProvider, _) {
        // Ограничиваем количество отображаемых тем
        final limit = 2;
        final relevantThemeIds = note.themeIds.take(limit).toList();

        if (relevantThemeIds.isEmpty) return const SizedBox();

        return Wrap(
          spacing: 4,
          children: [
            ...relevantThemeIds.map((themeId) {
              final theme = themesProvider.getThemeById(themeId);
              if (theme == null) return const SizedBox();

              Color themeColor;
              try {
                themeColor = Color(int.parse(theme.color));
              } catch (e) {
                themeColor = AppColors.secondary;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: themeColor.withOpacity(0.5),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  theme.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: themeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),

            // Индикатор дополнительных тем
            if (note.themeIds.length > limit)
              Text(
                '+${note.themeIds.length - limit}',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textOnLight.withOpacity(0.6),
                ),
              ),
          ],
        );
      },
    );
  }

  // Открытие экрана деталей заметки
  void _openNoteDetail(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    ).then((_) {
      // Уведомляем о действии, если есть колбэк
      if (widget.onActionSelected != null) {
        widget.onActionSelected!(note, NoteListAction.custom);
      }
    });
  }

  // Диалог подтверждения удаления заметки
  Future<bool> _showDeleteConfirmationDialog(Note note) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить заметку'),
            content: const Text(
              'Вы уверены, что хотите удалить эту заметку? '
              'Это действие нельзя будет отменить.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('Удалить', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Диалог подтверждения отвязки заметки от темы
  Future<bool> _showUnlinkConfirmationDialog(Note note) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Отвязать заметку'),
            content: const Text(
              'Вы хотите отвязать эту заметку от текущей темы? '
              'Заметка не будет удалена и останется доступна.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Отвязать'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Контекстное меню с опциями для заметки
  void _showNoteOptionsMenu(Note note) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Опция редактирования
            if (widget.availableActions.contains(NoteListAction.edit))
              ListTile(
                leading:
                    const Icon(Icons.edit, color: AppColors.accentSecondary),
                title: const Text('Редактировать заметку'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteDetailScreen(
                        note: note,
                        isEditMode: true,
                      ),
                    ),
                  ).then((_) {
                    if (widget.onActionSelected != null) {
                      widget.onActionSelected!(note, NoteListAction.edit);
                    }
                  });
                },
              ),

            // Опция добавления/удаления из избранного
            if (widget.availableActions.contains(NoteListAction.favorite))
              ListTile(
                leading: Icon(
                  note.isFavorite ? Icons.star_border : Icons.star,
                  color: Colors.amber,
                ),
                title: Text(note.isFavorite
                    ? 'Удалить из избранного'
                    : 'Добавить в избранное'),
                onTap: () async {
                  Navigator.pop(context);
                  final notesProvider =
                      Provider.of<NotesProvider>(context, listen: false);
                  await notesProvider.toggleFavorite(note.id);
                  if (widget.onNoteFavoriteToggled != null) {
                    widget.onNoteFavoriteToggled!(note);
                  }
                  if (widget.onActionSelected != null) {
                    widget.onActionSelected!(note, NoteListAction.favorite);
                  }
                },
              ),

            // Опция отметки о выполнении
            if (widget.availableActions.contains(NoteListAction.complete) &&
                note.hasDeadline &&
                !note.isCompleted)
              ListTile(
                leading:
                    const Icon(Icons.check_circle, color: AppColors.completed),
                title: const Text('Отметить как выполненное'),
                onTap: () async {
                  Navigator.pop(context);
                  final notesProvider =
                      Provider.of<NotesProvider>(context, listen: false);
                  await notesProvider.completeNote(note.id);
                  if (widget.onActionSelected != null) {
                    widget.onActionSelected!(note, NoteListAction.complete);
                  }
                },
              ),

            // Опция отвязки от темы
            if (widget.availableActions
                    .contains(NoteListAction.unlinkFromTheme) &&
                widget.themeId != null &&
                !widget.isInThemeView)
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.blue),
                title: const Text('Отвязать от темы'),
                onTap: () async {
                  Navigator.pop(context);
                  final shouldUnlink =
                      await _showUnlinkConfirmationDialog(note);
                  if (shouldUnlink && widget.onNoteUnlinked != null) {
                    widget.onNoteUnlinked!(note);
                  }
                  if (widget.onActionSelected != null && shouldUnlink) {
                    widget.onActionSelected!(
                        note, NoteListAction.unlinkFromTheme);
                  }
                },
              ),

            // Опция удаления заметки
            if (widget.availableActions.contains(NoteListAction.delete))
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Удалить заметку',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final shouldDelete =
                      await _showDeleteConfirmationDialog(note);
                  if (shouldDelete && widget.onNoteDeleted != null) {
                    widget.onNoteDeleted!(note);
                  }
                  if (widget.onActionSelected != null && shouldDelete) {
                    widget.onActionSelected!(note, NoteListAction.delete);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
