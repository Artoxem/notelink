import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';
import '../utils/constants.dart';
import '../utils/note_status_utils.dart';
import '../screens/note_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

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

        // Подтверждение действия при свайпе с улучшенной обработкой ошибок
        confirmDismiss: (direction) async {
          if (!mounted) return false;

          try {
            if (direction == DismissDirection.endToStart) {
              // Свайп влево - удаление или отвязка от темы
              if (widget.isInThemeView && widget.themeId != null) {
                // Отвязка от темы, если мы находимся внутри темы
                final result = await _showUnlinkConfirmationDialog(note);
                if (result && widget.onNoteUnlinked != null) {
                  widget.onNoteUnlinked!(note);
                }
                return result;
              } else {
                // Удаление заметки в других случаях
                final result = await _showDeleteConfirmationDialog(note);
                if (result && widget.onNoteDeleted != null) {
                  widget.onNoteDeleted!(note);
                }
                return result;
              }
            } else if (direction == DismissDirection.startToEnd) {
              // Свайп вправо - добавление/удаление из избранного

              // Тактильная обратная связь
              HapticFeedback.lightImpact();

              // Вызываем колбэк для переключения избранного
              if (widget.onNoteFavoriteToggled != null) {
                widget.onNoteFavoriteToggled!(note);
              }

              // Показываем сообщение
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(note.isFavorite
                        ? 'Заметка добавлена в избранное'
                        : 'Заметка удалена из избранного'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: AppColors.accentSecondary,
                  ),
                );
              }

              return false; // Не убираем карточку
            }
            return false;
          } catch (e) {
            // Обработка ошибок при взаимодействии
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Произошла ошибка: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return false;
          }
        },

        // Действие после успешного свайпа
        onDismissed: (direction) async {
          if (direction == DismissDirection.endToStart) {
            try {
              // Сообщение об удалении
              if (mounted && !widget.isInThemeView) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Заметка удалена'),
                    action: SnackBarAction(
                      label: 'Отмена',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Функция восстановления будет доступна в будущем')),
                        );
                      },
                    ),
                  ),
                );
              }

              // Вызываем соответствующее действие через колбэк
              if (widget.onActionSelected != null) {
                widget.onActionSelected!(
                    note,
                    widget.isInThemeView
                        ? NoteListAction.unlinkFromTheme
                        : NoteListAction.delete);
              }
            } catch (e) {
              // Обработка ошибок
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ошибка: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },

        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Stack(
            children: [
              Card(
                margin: EdgeInsets.zero,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.cardBorderRadius),
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
                  borderRadius:
                      BorderRadius.circular(AppDimens.cardBorderRadius),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Цветная вертикальная полоса слева
                        Container(
                          width: 6.0,
                          decoration: BoxDecoration(
                            color: noteColor,
                            borderRadius: const BorderRadius.only(
                              topLeft:
                                  Radius.circular(AppDimens.cardBorderRadius),
                              bottomLeft:
                                  Radius.circular(AppDimens.cardBorderRadius),
                            ),
                          ),
                        ),

                        // Основное содержимое
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Верхняя часть: дата создания, дедлайн и меню
                                Row(
                                  children: [
                                    // Дата создания
                                    Text(
                                      DateFormat('d MMM yyyy')
                                          .format(note.createdAt),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textOnLight
                                            .withOpacity(0.7),
                                      ),
                                    ),

                                    // Дедлайн
                                    if (note.hasDeadline &&
                                        note.deadlineDate != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color.fromRGBO(
                                              255, 255, 7, 0.35),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              note.isCompleted
                                                  ? Icons.check_circle
                                                  : Icons.timer,
                                              size: 12,
                                              color: AppColors.textOnLight,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              note.isCompleted
                                                  ? 'Готово'
                                                  : 'до ${DateFormat('d MMM').format(note.deadlineDate!)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textOnLight,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    const Spacer(),

                                    // Кнопка меню
                                    if (widget.showOptionsOnLongPress)
                                      Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(15),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          onTap: () =>
                                              _showNoteOptionsMenu(note),
                                          child: Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: Icon(
                                              Icons.more_vert,
                                              size: 18,
                                              color: AppColors.textOnLight
                                                  .withOpacity(0.7),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                // Заголовок заметки (первая строка)
                                Text(
                                  _getFirstLine(note.content),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textOnLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Добавляем проверку на наличие контента
                                if (_getContentWithoutFirstLine(note.content)
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  // Содержимое заметки с градиентным затемнением
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 0,
                                      maxHeight: 60,
                                    ),
                                    child: ShaderMask(
                                      shaderCallback: (Rect bounds) {
                                        return LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.black,
                                            Colors.transparent
                                          ],
                                          stops: const [0.7, 1.0],
                                        ).createShader(bounds);
                                      },
                                      blendMode: BlendMode.dstIn,
                                      child: Text(
                                        _getContentWithoutFirstLine(
                                            note.content),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textOnLight,
                                        ),
                                        maxLines: 3,
                                      ),
                                    ),
                                  ),
                                ],

                                // Индикаторы медиа и темы
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    // Индикаторы медиа
                                    if (_hasMediaContent(note))
                                      _buildMediaIndicators(note),

                                    const Spacer(),

                                    // Индикатор темы
                                    if (widget.showThemeBadges &&
                                        note.themeIds.isNotEmpty &&
                                        !widget.isInThemeView)
                                      _buildFirstThemeTag(note.themeIds),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Индикатор избранного
              if (note.isFavorite)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Material(
                    color: Colors.amber,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppDimens.cardBorderRadius),
                      bottomRight:
                          Radius.circular(AppDimens.cardBorderRadius - 3),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

// Вспомогательные методы для форматирования и отображения содержимого заметок
  String _getFirstLine(String content) {
    final firstLineEnd = content.indexOf('\n');
    if (firstLineEnd == -1) return content;
    return content
        .substring(0, firstLineEnd)
        .trim()
        .replaceAll(RegExp(r'^#+\s+'), '');
  }

  String _getContentWithoutFirstLine(String content) {
    final firstLineEnd = content.indexOf('\n');
    if (firstLineEnd == -1) return '';
    return content.substring(firstLineEnd + 1).trim();
  }

  bool _hasMediaContent(Note note) {
    return note.hasImages ||
        note.hasAudio ||
        note.hasFiles ||
        note.hasVoiceNotes ||
        note.content.contains('![voice]');
  }

// Метод для отображения индикаторов медиа
  Widget _buildMediaIndicators(Note note) {
    List<Widget> indicators = [];

    // Изображения
    if (note.hasImages) {
      indicators.add(
        _buildMediaIndicator(Icons.image, AppColors.accentPrimary),
      );
    }

    // Аудио и голосовые заметки
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

// Метод для отображения только первого тега темы
  Widget _buildFirstThemeTag(List<String> themeIds) {
    return Consumer<ThemesProvider>(
      builder: (context, themesProvider, _) {
        if (themeIds.isEmpty) return const SizedBox();

        // Берем только первую тему
        final themeId = themeIds.first;
        final theme = themesProvider.getThemeById(themeId);

        if (theme == null) return const SizedBox();

        // Определяем цвет темы
        Color themeColor;
        try {
          themeColor = Color(int.parse(theme.color));
        } catch (e) {
          themeColor = Color(0xFFFF9800); // Оранжевый по умолчанию
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: themeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            theme.name,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
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
                widget.themeId !=
                    null) // Убираем проверку !widget.isInThemeView
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
