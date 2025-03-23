// lib/widgets/note_list.dart

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
import 'dart:math' as math;
import '../widgets/media_badge.dart';

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
  // Кэш для обработанных текстов - добавляем для оптимизации
  final Map<String, String> _firstLineCache = {};
  final Map<String, String> _contentPreviewCache = {};

  // Контроллер прокрутки для сохранения позиции
  final ScrollController _scrollController = ScrollController();

  // Ключ для AnimatedList
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // Локальная копия списка заметок для управления анимациями
  late List<Note> _localNotes;

  // Статические регулярные выражения для обработки Markdown - создаются один раз
  static final RegExp _headingsRegex = RegExp(r'#{1,6}\s+');
  static final RegExp _boldRegex = RegExp(r'\*\*|__');
  static final RegExp _italicRegex = RegExp(r'\*|_(?!\*)');
  static final RegExp _linksRegex = RegExp(r'\[([^\]]+)\]\([^)]+\)');
  static final RegExp _codeRegex = RegExp(r'`[^`]+`');

  // Обновленное регулярное выражение для полного удаления голосовых заметок
  static final RegExp _voiceRegex = RegExp(r'!\[voice\]\(voice:[^)]+\)');

  @override
  void initState() {
    super.initState();

    // Инициализируем локальный список
    _localNotes = List.from(widget.notes);

    if (widget.useCachedAnimation) {
      _animationController = AnimationController(
        vsync: this,
        duration: AppAnimations.shortDuration,
      );

      // Инициализируем анимации
      _initializeItemAnimations();
      _animationController.forward();
    }

    // Предварительно обрабатываем тексты заметок для кэширования
    _precacheNoteTexts();
  }

  // Новый метод для предварительной обработки текстов
  void _precacheNoteTexts() {
    for (final note in _localNotes) {
      if (!_firstLineCache.containsKey(note.id)) {
        _firstLineCache[note.id] = _processFirstLine(note.content);
      }
      if (!_contentPreviewCache.containsKey(note.id)) {
        _contentPreviewCache[note.id] = _processContentPreview(note.content);
      }
    }
  }

  @override
  void didUpdateWidget(NoteListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Если список заметок изменился извне, обновляем локальный список
    if (widget.notes != oldWidget.notes) {
      // Находим добавленные и удаленные заметки
      final Set<String> oldIds = oldWidget.notes.map((n) => n.id).toSet();
      final Set<String> newIds = widget.notes.map((n) => n.id).toSet();

      final Set<String> addedIds = newIds.difference(oldIds);
      final Set<String> removedIds = oldIds.difference(newIds);

      // Обрабатываем удаленные заметки
      for (final removedId in removedIds) {
        final index = _localNotes.indexWhere((n) => n.id == removedId);
        if (index != -1) {
          _removeNoteLocally(index);
        }
        // Очищаем кэш для удаленных заметок
        _firstLineCache.remove(removedId);
        _contentPreviewCache.remove(removedId);
      }

      // Обрабатываем добавленные заметки
      for (final addedId in addedIds) {
        final note = widget.notes.firstWhere((n) => n.id == addedId);
        _localNotes.add(note);
        // Кэшируем тексты для новых заметок
        _firstLineCache[addedId] = _processFirstLine(note.content);
        _contentPreviewCache[addedId] = _processContentPreview(note.content);
      }

      // Обновляем существующие заметки
      for (int i = 0; i < _localNotes.length; i++) {
        final noteId = _localNotes[i].id;
        final updatedNote = widget.notes.firstWhere(
          (n) => n.id == noteId,
          orElse: () => _localNotes[i],
        );

        if (updatedNote != _localNotes[i]) {
          // Если контент изменился, обновляем кэш
          if (updatedNote.content != _localNotes[i].content) {
            _firstLineCache[noteId] = _processFirstLine(updatedNote.content);
            _contentPreviewCache[noteId] =
                _processContentPreview(updatedNote.content);
          }
          _localNotes[i] = updatedNote;
        }
      }
    }
  }

  @override
  void dispose() {
    if (widget.useCachedAnimation) {
      _animationController.dispose();
    }
    _noteColorCache.clear();
    _firstLineCache.clear();
    _contentPreviewCache.clear();
    _scrollController.dispose();
    super.dispose();
  }

  // Оптимизированные методы для обработки текста
  // Метод для извлечения и форматирования первой строки
  String _processFirstLine(String content) {
    // Полностью удаляем голосовые метки (не оставляем никаких заменителей)
    String cleanContent = content.replaceAll(_voiceRegex, '');

    // Убираем лишние пробелы, которые могли остаться после удаления голосовых меток
    cleanContent = cleanContent.replaceAll(RegExp(r'\s+'), ' ').trim();

    final firstLineEnd = cleanContent.indexOf('\n');
    if (firstLineEnd == -1) {
      // Удаляем markdown разметку из всего текста
      return _cleanMarkdown(cleanContent);
    }

    // Очищаем только первую строку
    String firstLine = cleanContent.substring(0, firstLineEnd).trim();
    return _cleanMarkdown(firstLine);
  }

  // Метод для извлечения и форматирования контента без первой строки
  String _processContentPreview(String content) {
    // Полностью удаляем голосовые метки (не оставляем никаких заменителей)
    String cleanContent = content.replaceAll(_voiceRegex, '');

    // Убираем лишние пробелы, которые могли остаться после удаления голосовых меток
    cleanContent = cleanContent.replaceAll(RegExp(r'\s+'), ' ').trim();

    final firstLineEnd = cleanContent.indexOf('\n');
    if (firstLineEnd == -1) return '';

    // Берем только контент после первой строки
    String restContent = cleanContent.substring(firstLineEnd + 1).trim();
    // Очищаем markdown
    return _cleanMarkdown(restContent);
  }

  // Упрощенный метод очистки markdown (без частых регулярных выражений)
  String _cleanMarkdown(String text) {
    if (text.isEmpty) return '';

    // Последовательно удаляем разметку наиболее распространенных элементов
    String cleaned = text;

    // Удаляем заголовки
    cleaned = cleaned.replaceAll(_headingsRegex, '');

    // Удаляем жирный и курсив
    cleaned = cleaned.replaceAll(_boldRegex, '');
    cleaned = cleaned.replaceAll(_italicRegex, '');

    // Заменяем ссылки только текстом
    cleaned =
        cleaned.replaceAllMapped(_linksRegex, (match) => match.group(1) ?? '');

    // Удаляем код - используем replaceAllMapped вместо replaceAll с функцией
    cleaned = cleaned.replaceAllMapped(_codeRegex, (match) {
      final code = match.group(0) ?? '';
      return code.length > 2 ? code.substring(1, code.length - 1) : '';
    });

    return cleaned.trim();
  }

  Widget _buildNoteContentPreview(Note note) {
    // Получаем текст для превью из кэша
    final String previewText =
        _contentPreviewCache[note.id] ?? _processContentPreview(note.content);

    // Проверяем, не пустой ли текст
    if (previewText.isEmpty) {
      return const SizedBox.shrink();
    }

    // Показываем только текст без индикаторов голосовых заметок
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.transparent],
          stops: const [0.7, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: Text(
        previewText,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textOnLight,
        ),
        maxLines: 3,
      ),
    );
  }

  // Инициализация анимаций элементов списка
  void _initializeItemAnimations() {
    if (!widget.useCachedAnimation) return;

    for (int i = 0; i < _localNotes.length; i++) {
      final note = _localNotes[i];
      _itemAnimations[note.id] = CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          i / _localNotes.length * 0.6, // Задержка в зависимости от позиции
          i / _localNotes.length * 0.6 + 0.4, // Перекрытие для плавности
          curve: Curves.easeOutQuint,
        ),
      );
    }
  }

  // Метод для локального удаления заметки с анимацией
  void _removeNoteLocally(int index) {
    if (index < 0 || index >= _localNotes.length) return;

    final note = _localNotes[index];

    // Сохраняем текущую позицию прокрутки
    final currentScrollPosition = _scrollController.position.pixels;

    // Удаляем из локального списка
    _localNotes.removeAt(index);

    // Если используем AnimatedList, анимируем удаление
    if (_listKey.currentState != null) {
      _listKey.currentState!.removeItem(
        index,
        (context, animation) => _buildNoteItemWithAnimation(note, animation),
        duration: AppAnimations.mediumDuration,
      );
    } else {
      // Обновляем состояние, если AnimatedList не используется
      setState(() {});
    }

    // Восстанавливаем позицию прокрутки после анимации
    Future.delayed(AppAnimations.mediumDuration, () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(math.min(
            currentScrollPosition, _scrollController.position.maxScrollExtent));
      }
    });
  }

  // Метод для локального добавления заметки в избранное без полной перезагрузки
  void _toggleFavoriteLocally(Note note) async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    // Сохраняем текущую позицию прокрутки
    final currentScrollPosition =
        _scrollController.hasClients ? _scrollController.position.pixels : 0.0;

    // Тактильная обратная связь
    HapticFeedback.lightImpact();

    // Переключаем состояние избранного
    await notesProvider.toggleFavorite(note.id);

    // Обновляем локальное состояние без полной перезагрузки
    setState(() {
      final index = _localNotes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _localNotes[index] = _localNotes[index].copyWith(
          isFavorite: !_localNotes[index].isFavorite,
        );
      }
    });

    // Восстанавливаем позицию прокрутки
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(currentScrollPosition);
    }

    // Уведомляем родительский виджет
    if (widget.onNoteFavoriteToggled != null) {
      widget.onNoteFavoriteToggled!(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localNotes.isEmpty) {
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

    // Используем AnimatedList для анимации добавления/удаления
    return AnimatedList(
      key: _listKey,
      controller: _scrollController,
      initialItemCount: _localNotes.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index, animation) {
        final note = _localNotes[index];
        return _buildNoteItemWithAnimation(note, animation);
      },
    );
  }

  // Метод для построения элемента списка с анимацией
  Widget _buildNoteItemWithAnimation(Note note, Animation<double> animation) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuint,
      )),
      child: FadeTransition(
        opacity: animation,
        child: _buildNoteItem(note),
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    // Получаем цвет для заметки
    final Color noteColor = _getNoteStatusColor(note);

    // Определяем направления свайпа
    final DismissDirection dismissDirection = _getDismissDirection();

    // ВАЖНОЕ ИЗМЕНЕНИЕ: Убираем все ClipRRect из структуры виджетов
    // И используем отрицательное смещение для значка избранного

    return Dismissible(
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
                AppColors.accentSecondary.withOpacity(0.8),
                AppColors.accentSecondary.withOpacity(0.6)
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(22)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
                AppColors.accentSecondary.withOpacity(0.6),
                AppColors.accentSecondary.withOpacity(0.8),
              ],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(22)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
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
              if (result) {
                // Находим индекс заметки в локальном списке
                final index = _localNotes.indexWhere((n) => n.id == note.id);
                if (index != -1) {
                  // Локально удаляем заметку с анимацией
                  _removeNoteLocally(index);

                  // Вызываем обработчик удаления из родительского виджета
                  if (widget.onNoteDeleted != null) {
                    widget.onNoteDeleted!(note);
                  }
                }
              }
              return false; // Не позволяем Dismissible обрабатывать удаление
            }
          } else if (direction == DismissDirection.startToEnd) {
            // Свайп вправо - добавление/удаление из избранного
            _toggleFavoriteLocally(note);
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

      onDismissed: (direction) {},

      // Cтруктура виджетов карточки
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        child: Material(
          // Используем Material без ClipRRect для предотвращения обрезания
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none, // Отключаем обрезание в Stack
            children: [
              // Основная карточка без ClipRRect
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
                                                  ? 'Выполнено'
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
                                  // Используем кэшированную первую строку
                                  _firstLineCache[note.id] ??
                                      _processFirstLine(note.content),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textOnLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                // Добавляем проверку на наличие контента
                                if ((_contentPreviewCache[note.id] ?? '')
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  // Содержимое заметки с обработкой голосовых заметок
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 0,
                                      maxHeight: 60,
                                    ),
                                    child: _buildNoteContentPreview(note),
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

              // Индикатор избранного с отрицательным смещением
              if (note.isFavorite)
                Positioned(
                  top: -2, // ВАЖНОЕ ИЗМЕНЕНИЕ: отрицательное смещение вверх
                  left: -2, // ВАЖНОЕ ИЗМЕНЕНИЕ: отрицательное смещение влево
                  child: Material(
                    color: Colors.amber,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppDimens.cardBorderRadius),
                      bottomRight: Radius.circular(
                          8), // Фиксированное значение для углового скругления
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(3.0),
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

  bool _hasMediaContent(Note note) {
    return note.hasImages ||
        note.hasAudio ||
        note.hasFiles ||
        note.hasVoiceNotes ||
        note.content.contains('![voice]');
  }

  // Метод для отображения индикаторов медиа
  Widget _buildMediaIndicators(Note note) {
    // Определяем количество каждого типа медиа
    int imagesCount = 0;
    int audioCount = 0;
    int filesCount = 0;
    int voiceCount = 0;

    // Подсчитываем по типам файлов
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

    // Проверяем на голосовые заметки в контенте
    final voiceMatches =
        RegExp(r'!\[voice\]\(voice:[^)]+\)').allMatches(note.content);
    voiceCount = voiceMatches.length;

    // Используем MediaBadgeGroup - такой же компонент, как в режиме "плитка"
    return MediaBadgeGroup(
      imagesCount: imagesCount,
      audioCount: audioCount,
      voiceCount: voiceCount,
      filesCount: filesCount,
      badgeSize: 24.0,
      spacing: 4.0,
      onBadgeTap: (type) {
        // Тактильная обратная связь при нажатии
        HapticFeedback.lightImpact();
        if (widget.onNoteTap != null) {
          widget.onNoteTap!(note);
        } else {
          _openNoteDetail(note);
        }
      },
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
                onTap: () {
                  Navigator.pop(context);
                  _toggleFavoriteLocally(note);
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

                  // Сохраняем текущую позицию прокрутки
                  final currentScrollPosition = _scrollController.hasClients
                      ? _scrollController.position.pixels
                      : 0.0;

                  // Отмечаем заметку как выполненную
                  final notesProvider =
                      Provider.of<NotesProvider>(context, listen: false);
                  await notesProvider.completeNote(note.id);

                  // Обновляем локальное состояние
                  setState(() {
                    final index =
                        _localNotes.indexWhere((n) => n.id == note.id);
                    if (index != -1) {
                      _localNotes[index] = _localNotes[index].copyWith(
                        isCompleted: true,
                      );
                    }
                  });

                  // Восстанавливаем позицию прокрутки
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(currentScrollPosition);
                  }

                  if (widget.onActionSelected != null) {
                    widget.onActionSelected!(note, NoteListAction.complete);
                  }
                },
              ),

            // Опция отвязки от темы
            if (widget.availableActions
                    .contains(NoteListAction.unlinkFromTheme) &&
                widget.themeId != null)
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.blue),
                title: const Text('Отвязать от темы'),
                onTap: () async {
                  Navigator.pop(context);
                  final shouldUnlink =
                      await _showUnlinkConfirmationDialog(note);
                  if (shouldUnlink) {
                    // Находим индекс заметки в локальном списке
                    final index =
                        _localNotes.indexWhere((n) => n.id == note.id);
                    if (index != -1) {
                      // Локально удаляем заметку с анимацией
                      _removeNoteLocally(index);
                    }

                    if (widget.onNoteUnlinked != null) {
                      widget.onNoteUnlinked!(note);
                    }
                    if (widget.onActionSelected != null) {
                      widget.onActionSelected!(
                          note, NoteListAction.unlinkFromTheme);
                    }
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
                  if (shouldDelete) {
                    // Находим индекс заметки в локальном списке
                    final index =
                        _localNotes.indexWhere((n) => n.id == note.id);
                    if (index != -1) {
                      // Локально удаляем заметку с анимацией
                      _removeNoteLocally(index);

                      if (widget.onNoteDeleted != null) {
                        widget.onNoteDeleted!(note);
                      }
                      if (widget.onActionSelected != null) {
                        widget.onActionSelected!(note, NoteListAction.delete);
                      }
                    }
                  }
                },
              ),
          ],
        ),
      ),
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
}
