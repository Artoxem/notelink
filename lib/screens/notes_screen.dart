import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../providers/app_provider.dart';
import '../providers/themes_provider.dart';
import '../models/note.dart';
import '../utils/constants.dart';
import '../utils/note_status_utils.dart';
import 'note_detail_screen.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  static void showAddNoteDialog(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NoteDetailScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0);
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
    );
  }

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen>
    with TickerProviderStateMixin {
  // Контроллеры анимаций
  late AnimationController _itemAnimationController;
  final Map<String, Animation<double>> _itemAnimations = {};

  // Кэши для оптимизации производительности
  final Map<String, Color> _noteColorCache = {};
  final Map<String, Color> _themeColorCache = {};
  final Map<String, List<Widget>> _themeTagsCache = {};

  // Время последнего обновления для инвалидации кэшей
  DateTime _lastCacheUpdate = DateTime.now();

  // Регулярные выражения для обработки Markdown (вынесены на уровень класса)
  final RegExp _headingsRegex = RegExp(r'#{1,6}\s+');
  final RegExp _boldRegex = RegExp(r'\*\*|__');
  final RegExp _italicRegex = RegExp(r'\*|_(?!\*)');
  final RegExp _linksRegex = RegExp(r'\[([^\]]+)\]\([^)]+\)');
  final RegExp _codeRegex = RegExp(r'`[^`]+`');

  // Контролируем состояние загрузки
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();

    // Инициализация контроллера анимации
    _itemAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimations.shortDuration,
    );

    // Загружаем заметки при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _itemAnimationController.dispose();
    _clearCaches();
    super.dispose();
  }

  // Очистка всех кэшей
  void _clearCaches() {
    _itemAnimations.clear();
    _noteColorCache.clear();
    _themeColorCache.clear();
    _themeTagsCache.clear();
  }

  // Инвалидация кэша темы при изменении
  void _invalidateThemeCache(String themeId) {
    _themeColorCache.remove(themeId);
    _themeTagsCache
        .clear(); // Очищаем все теги, так как сложно отследить затронутые
  }

  // Инвалидация кэшей, связанных с заметкой
  void _invalidateNoteCache(String noteId) {
    _noteColorCache.remove(noteId);
    // Также можно очистить другие кэши, связанные с заметкой
  }

  // Метод для получения цвета темы с кэшированием
  Color _getThemeColor(String themeId, {Color defaultColor = Colors.blue}) {
    // Проверяем кэш
    if (_themeColorCache.containsKey(themeId)) {
      return _themeColorCache[themeId]!;
    }

    // Получаем из провайдера
    final themesProvider = Provider.of<ThemesProvider>(context, listen: false);
    final theme = themesProvider.getThemeById(themeId) ??
        NoteTheme(
          id: '',
          name: 'Без темы',
          color: defaultColor.value.toString(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteIds: [],
        );

    try {
      final color = Color(int.parse(theme.color));
      // Сохраняем в кэш
      _themeColorCache[themeId] = color;
      return color;
    } catch (e) {
      return defaultColor;
    }
  }

  // Асинхронная загрузка данных с параллельными запросами
  Future<void> _loadData() async {
    if (_isRefreshing) return; // Предотвращаем параллельные запросы загрузки

    _isRefreshing = true;

    // Загружаем заметки, темы и связи между ними
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final themesProvider = Provider.of<ThemesProvider>(context, listen: false);

    try {
      // Используем Future.wait для параллельной загрузки
      await Future.wait(
          [notesProvider.loadNotes(), themesProvider.loadThemes()],
          eagerError: true);

      // Продолжаем только если компонент все еще в дереве
      if (!mounted) return;

      // Очищаем кэши после обновления данных
      _clearCaches();

      // Инициализируем анимации для каждой заметки
      _initializeItemAnimations(notesProvider.notes);

      // Обновляем время последнего обновления
      _lastCacheUpdate = DateTime.now();
    } catch (e) {
      // Обработка ошибок загрузки
      if (!mounted) return;

      // Показываем пользователю ошибку с возможностью повторить
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ошибка загрузки данных'),
          action: SnackBarAction(
            label: 'Повторить',
            onPressed: _loadData,
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      // Логируем ошибку для отладки
      print('Ошибка загрузки данных: $e');
    } finally {
      // Сбрасываем флаг загрузки, только если компонент все еще в дереве
      if (mounted) {
        _isRefreshing = false;
      }
    }
  }

  // Оптимизированная инициализация анимаций для улучшения производительности
  void _initializeItemAnimations(List<Note> notes) {
    if (notes.isEmpty) return;

    final random = math.Random();

    // Тщательно инициализируем только анимации для новых заметок
    for (var note in notes) {
      if (!_itemAnimations.containsKey(note.id)) {
        // Более плавная анимация со случайной задержкой
        final delay =
            random.nextDouble() * 0.3; // Уменьшаем максимальную задержку

        _itemAnimations[note.id] = CurvedAnimation(
          parent: _itemAnimationController,
          curve: Interval(
            delay,
            math.min(delay + 0.6, 1.0), // Ограничиваем верхнюю границу
            curve: Curves.easeOutQuint,
          ),
        );
      }
    }

    // Сбрасываем и запускаем анимацию только если контроллер не анимирует
    if (_itemAnimationController.status != AnimationStatus.forward) {
      _itemAnimationController.reset();
      _itemAnimationController.forward();
    }
  }

  // Улучшенный основной метод построения UI
  @override
  Widget build(BuildContext context) {
    // Выбираем только те свойства, которые влияют на отображение
    return Selector2<AppProvider, NotesProvider, Tuple2<NoteViewMode, bool>>(
      selector: (_, appProvider, notesProvider) => Tuple2(
        appProvider.noteViewMode,
        notesProvider.isLoading,
      ),
      builder: (context, data, _) {
        final noteViewMode = data.item1;
        final isLoading = data.item2;

        if (isLoading && !_isRefreshing) {
          return const Center(child: CircularProgressIndicator());
        }

        // Получаем заметки и настройки сортировки без вызова перестройки
        final notes = Provider.of<NotesProvider>(context, listen: false).notes;
        final noteSortMode =
            Provider.of<AppProvider>(context, listen: false).noteSortMode;

        // Копируем список, чтобы не модифицировать оригинал
        final displayNotes = List<Note>.from(notes);

        // Сортируем заметки в зависимости от настроек
        _sortNotes(displayNotes, noteSortMode);

        if (displayNotes.isEmpty) {
          return _buildEmptyState();
        }

        // Отображаем список заметок в выбранном режиме
        return _buildNotesList(displayNotes, noteViewMode,
            Provider.of<NotesProvider>(context, listen: false));
      },
    );
  }

  // Оптимизированное построение списка заметок
  Widget _buildNotesList(
      List<Note> notes, NoteViewMode viewMode, NotesProvider notesProvider) {
    // Используем кастомный ключ для сохранения состояния скролла
    final key = PageStorageKey<String>('notes_list_$viewMode');

    // Определяем базовый виджет списка в зависимости от режима просмотра
    Widget listWidget;

    if (viewMode == NoteViewMode.card) {
      listWidget = GridView.builder(
        key: key,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        padding: const EdgeInsets.all(AppDimens.mediumPadding),
        itemCount: notes.length,
        cacheExtent: 1000,
        addAutomaticKeepAlives: true,
        itemBuilder: (context, index) {
          final note = notes[index];
          return RepaintBoundary(
            key: ValueKey('note_card_${note.id}'),
            child: _buildNoteCard(note, notesProvider),
          );
        },
      );
    } else {
      listWidget = ListView.builder(
        key: key,
        padding: const EdgeInsets.all(AppDimens.mediumPadding),
        itemCount: notes.length,
        cacheExtent: 1000,
        addAutomaticKeepAlives: true,
        itemBuilder: (context, index) {
          final note = notes[index];
          return RepaintBoundary(
            key: ValueKey('note_list_${note.id}'),
            child: _buildNoteListItem(note, notesProvider),
          );
        },
      );
    }

    // Оборачиваем в RefreshIndicator для функции "pull-to-refresh"
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.accentSecondary,
      backgroundColor: AppColors.cardBackground,
      child: listWidget,
    );
  }

  // Оптимизированное получение цвета индикатора заметки
  Color _getNoteStatusColor(Note note) {
    // Проверяем кэш
    if (_noteColorCache.containsKey(note.id)) {
      return _noteColorCache[note.id]!;
    }

    // Вычисляем цвет
    Color color = NoteStatusUtils.getNoteStatusColor(note);

    // Если у заметки есть темы, используем цвет первой темы
    if (note.themeIds.isNotEmpty) {
      final themeId = note.themeIds.first;
      color = _getThemeColor(themeId, defaultColor: color);
    }

    // Сохраняем в кэш
    _noteColorCache[note.id] = color;
    return color;
  }

  // Оптимизированное построение карточки заметки
  Widget _buildNoteCard(Note note, NotesProvider notesProvider) {
    // Определяем цвет индикатора в зависимости от статуса и темы (с кэшированием)
    final indicatorColor = _getNoteStatusColor(note);

    // Получаем или создаем анимацию для заметки
    final Animation<double> animation =
        _itemAnimations[note.id] ?? const AlwaysStoppedAnimation(1.0);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: _buildDismissibleNote(
        note: note,
        notesProvider: notesProvider,
        child: Stack(
          children: [
            Card(
              margin: const EdgeInsets.all(2),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
              ),
              child: InkWell(
                onTap: () => _viewNoteDetails(note),
                onLongPress: () => _showNoteOptions(note),
                borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
                child: Row(
                  children: [
                    // Цветной индикатор слева
                    Container(
                      width: 6,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(AppDimens.cardBorderRadius),
                          bottomLeft:
                              Radius.circular(AppDimens.cardBorderRadius),
                        ),
                      ),
                    ),
                    // Основное содержимое
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimens.mediumPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Верхняя часть с датой и меню
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Дата
                                Text(
                                  DateFormat('d MMM yyyy')
                                      .format(note.createdAt),
                                  style: AppTextStyles.bodySmallLight,
                                ),
                                // Кнопка меню
                                InkWell(
                                  onTap: () => _showNoteOptions(note),
                                  borderRadius: BorderRadius.circular(15),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(AppIcons.more,
                                        size: 18, color: AppColors.textOnLight),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Содержимое заметки - увеличиваем maxLines с 2 до 5
                            Expanded(
                              child: Text(
                                _createPreviewFromMarkdown(note.content,
                                    120), // Увеличиваем длину превью
                                maxLines: 5, // Увеличиваем с 2 до 5
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmallLight,
                              ),
                            ),

                            // Перенесем индикаторы медиа и тем после текста
                            if (note.mediaUrls.isNotEmpty ||
                                note.themeIds.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _buildNoteIndicators(note),
                              ),

                            // Переносим информацию о дедлайне в нижнюю часть
                            if (note.hasDeadline && note.deadlineDate != null)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
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
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        note.isCompleted
                                            ? 'Выполнено'
                                            : 'до ${DateFormat('d MMM').format(note.deadlineDate!)}',
                                        style: AppTextStyles.deadlineText,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Индикатор избранного
            if (note.isFavorite)
              const Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.amber,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(AppDimens.cardBorderRadius),
                    bottomLeft: Radius.circular(AppDimens.cardBorderRadius - 4),
                  ),
                  child: Padding(
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
    );
  }

  // Обновленный метод построения элемента списка
  Widget _buildNoteListItem(Note note, NotesProvider notesProvider) {
    // Получаем цвета с кэшированием для улучшения производительности
    final statusColor = _getNoteStatusColor(note);

    // Создаем анимацию для заметки
    final Animation<double> animation =
        _itemAnimations[note.id] ?? const AlwaysStoppedAnimation(1.0);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - animation.value), 0),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
      child: _buildDismissibleNote(
        note: note,
        notesProvider: notesProvider,
        isListItem: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
              side: BorderSide(
                color: statusColor,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: () => _viewNoteDetails(note),
              onLongPress: () => _showNoteOptions(note),
              borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppDimens.mediumPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Верхняя часть с датами и меню
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment
                              .center, // Выравниваем по центру
                          children: [
                            // Левая часть: аватар и дата создания в одном ряду
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: statusColor.withOpacity(0.8),
                                  radius:
                                      14, // Немного уменьшаем размер аватара
                                  child: note.emoji != null &&
                                          note.emoji!.isNotEmpty
                                      ? Text(
                                          note.emoji!,
                                          style: const TextStyle(fontSize: 12),
                                        )
                                      : Icon(
                                          note.hasDeadline
                                              ? (note.isCompleted
                                                  ? Icons.check_circle
                                                  : Icons.timer)
                                              : Icons.note,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('d MMMM yyyy, HH:mm')
                                      .format(note.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppColors.textOnLight.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),

                            // Увеличиваем пространство между датами
                            const Spacer(), // Добавляем гибкое пространство между датами

                            // Дата дедлайна (если есть)
                            if (note.hasDeadline && note.deadlineDate != null)
                              Text(
                                'Дедлайн: ${DateFormat('d MMMM yyyy').format(note.deadlineDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),

                            const SizedBox(width: 8), // Отступ перед меню

                            // Кнопка меню
                            InkWell(
                              onTap: () => _showNoteOptions(note),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.more_vert,
                                  size: 18,
                                  color: AppColors.textOnLight,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Убираем лишнее пространство и сразу переходим к контенту
                        const SizedBox(height: 4), // Уменьшаем отступ

                        // Заголовок заметки (берем первую строку)
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

                        const SizedBox(height: 2), // Минимальный отступ

                        // Содержимое заметки
                        Text(
                          _createPreviewFromMarkdown(
                              _getContentWithoutFirstLine(note.content), 200),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMediumLight,
                        ),

                        // Темы заметки (в виде маленьких тегов)
                        if (note.themeIds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 6), // Уменьшаем отступ
                            child: _buildThemeTags(note.themeIds),
                          ),
                      ],
                    ),
                  ),

                  // Индикатор избранного
                  if (note.isFavorite)
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: Material(
                        color: Colors.amber,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(AppDimens.cardBorderRadius),
                          bottomLeft:
                              Radius.circular(AppDimens.cardBorderRadius - 4),
                        ),
                        child: Padding(
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
        ),
      ),
    );
  }

// Вспомогательные методы для извлечения заголовка и содержимого
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

  // Выделенный виджет для отображения содержимого заметки с Markdown
  Widget _buildNoteContent(Note note) {
    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        return appProvider.enableMarkdownFormatting
            ? SizedBox(
                height: 50,
                child: MarkdownBody(
                  data: note.content.length > 100
                      ? note.content.substring(0, 100) + "..."
                      : note.content,
                  softLineBreak: true,
                  selectable: false,
                  shrinkWrap: true,
                  styleSheet: MarkdownStyleSheet(
                    p: AppTextStyles.bodySmallLight,
                    h1: AppTextStyles.bodySmallLight.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    h2: AppTextStyles.bodySmallLight.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    strong: AppTextStyles.bodySmallLight.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    em: AppTextStyles.bodySmallLight.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    listBullet: AppTextStyles.bodySmallLight,
                  ),
                ),
              )
            : Text(
                note.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmallLight,
              );
      },
    );
  }

  // Виджет Dismissible с улучшенной обработкой ошибок и анимацией
  Widget _buildDismissibleNote({
    required Note note,
    required NotesProvider notesProvider,
    required Widget child,
    bool isListItem = false,
  }) {
    final dismissKey =
        ValueKey('dismissible_${isListItem ? 'list_' : ''}${note.id}');

    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.horizontal,
      // Фон для свайпа вправо (избранное)
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        color: Colors.amber,
        child: const Icon(
          Icons.star,
          color: Colors.white,
        ),
      ),
      // Фон для свайпа влево (удаление)
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      // Подтверждение действия при свайпе с улучшенной обработкой ошибок
      confirmDismiss: (direction) async {
        if (!mounted) return false;

        try {
          if (direction == DismissDirection.endToStart) {
            // Свайп влево - удаление
            return await _showDeleteConfirmation(note);
          } else if (direction == DismissDirection.startToEnd) {
            // Свайп вправо - добавление в избранное
            await notesProvider.toggleFavorite(note.id);

            // Продолжаем только если виджет еще в дереве
            if (!mounted) return false;

            // Получаем обновленную заметку
            final updatedNote = notesProvider.notes.firstWhere(
              (n) => n.id == note.id,
              orElse: () => note,
            );

            // Инвалидируем кэш для этой заметки
            _invalidateNoteCache(note.id);

            // Отображаем уведомление о результате
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(updatedNote.isFavorite
                    ? 'Заметка добавлена в избранное'
                    : 'Заметка удалена из избранного'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.accentSecondary,
              ),
            );

            // Обновляем состояние для отображения изменений
            if (mounted) {
              setState(() {});
            }

            return false; // Не убираем виджет после свайпа в избранное
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
      // Действие после успешного свайпа с обработкой ошибок
      onDismissed: (direction) async {
        if (direction == DismissDirection.endToStart) {
          try {
            // Удаляем заметку
            await notesProvider.deleteNote(note.id);

            // Инвалидируем кэш
            _invalidateNoteCache(note.id);

            // Обновляем UI только если виджет еще в дереве
            if (mounted) {
              // Показываем подтверждение
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Заметка удалена'),
                  action: SnackBarAction(
                    label: 'Отмена',
                    onPressed: () {
                      // В будущем здесь можно реализовать отмену удаления
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Функция восстановления будет доступна в будущем')),
                      );
                    },
                  ),
                ),
              );

              // Обновляем состояние
              setState(() {});
            }
          } catch (e) {
            // Обработка ошибок удаления
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ошибка при удалении: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
      child: child,
    );
  }

  // Метод построения меню действий с заметкой
  void _showNoteOptions(Note note) {
    if (!mounted) return;

    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Действия с заметкой',
                      style: AppTextStyles.heading3,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Действия
              ListTile(
                leading:
                    const Icon(Icons.edit, color: AppColors.accentSecondary),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(context); // Закрываем меню
                  // Вместо _viewNoteDetails напрямую открываем экран с параметром isEditMode: true
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          NoteDetailScreen(note: note, isEditMode: true),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
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
                    if (mounted) {
                      _clearCaches();
                      Provider.of<NotesProvider>(context, listen: false)
                          .loadNotes();
                    }
                  });
                },
              ),
              if (note.hasDeadline && !note.isCompleted)
                ListTile(
                  leading: const Icon(Icons.check_circle,
                      color: AppColors.completed),
                  title: const Text('Отметить как выполненное'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await notesProvider.completeNote(note.id);

                      // Инвалидируем кэш для этой заметки
                      _invalidateNoteCache(note.id);

                      // Обновляем UI и показываем подтверждение
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Задача отмечена как выполненная')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка: $e')),
                        );
                      }
                    }
                  },
                ),
              if (note.hasDeadline)
                ListTile(
                  leading: const Icon(Icons.update,
                      color: AppColors.accentSecondary),
                  title: const Text('Продлить дедлайн'),
                  onTap: () async {
                    Navigator.pop(context);

                    final initialDate =
                        note.deadlineDate!.isBefore(DateTime.now())
                            ? DateTime.now().add(const Duration(days: 1))
                            : note.deadlineDate!.add(const Duration(days: 1));

                    if (!mounted) return;

                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: initialDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );

                    if (selectedDate != null && mounted) {
                      try {
                        await notesProvider.extendDeadline(
                            note.id, selectedDate);

                        // Инвалидируем кэш для этой заметки
                        _invalidateNoteCache(note.id);

                        // Обновляем UI и показываем подтверждение
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Дедлайн продлен до ${DateFormat('d MMMM yyyy').format(selectedDate)}'),
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Ошибка: $e')),
                          );
                        }
                      }
                    }
                  },
                ),

              ListTile(
                leading: Icon(
                  note.isFavorite ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                title: Text(note.isFavorite
                    ? 'Удалить из избранного'
                    : 'Добавить в избранное'),
                onTap: () async {
                  Navigator.pop(context);

                  try {
                    await notesProvider.toggleFavorite(note.id);

                    // Инвалидируем кэш для этой заметки
                    _invalidateNoteCache(note.id);

                    // Обновляем UI и показываем подтверждение
                    if (mounted) {
                      setState(() {});
                      final action =
                          note.isFavorite ? 'удалена из' : 'добавлена в';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Заметка $action избранное')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ошибка: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(note);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Улучшенное создание превью из Markdown-текста
  String _createPreviewFromMarkdown(String markdown, int maxLength) {
    if (markdown.isEmpty) {
      return '';
    }

    // Предварительная проверка наличия разметки для оптимизации производительности
    bool hasMarkdown = _headingsRegex.hasMatch(markdown) ||
        _boldRegex.hasMatch(markdown) ||
        _italicRegex.hasMatch(markdown) ||
        _linksRegex.hasMatch(markdown) ||
        _codeRegex.hasMatch(markdown);

    if (!hasMarkdown) {
      // Если разметки нет, просто обрезаем текст
      return markdown.length > maxLength
          ? '${markdown.substring(0, maxLength)}...'
          : markdown;
    }

    // Последовательно удаляем разметку
    String text = markdown;

    // Заменяем ссылки их текстовым представлением
    text = text.replaceAllMapped(_linksRegex, (match) => match.group(1) ?? '');

    // Удаляем заголовки
    text = text.replaceAll(_headingsRegex, '');

    // Удаляем разметку жирного и курсивного текста
    text = text.replaceAll(_boldRegex, '');
    text = text.replaceAll(_italicRegex, '');

    // Удаляем разметку кода
    text = text.replaceAllMapped(_codeRegex, (match) {
      final code = match.group(0) ?? '';
      return code.length > 2 ? code.substring(1, code.length - 1) : '';
    });

    // Обрезаем по максимальной длине
    if (text.length > maxLength) {
      text = '${text.substring(0, maxLength)}...';
    }

    return text;
  }

  // Улучшенный метод сортировки заметок
  void _sortNotes(List<Note> notes, NoteSortMode sortMode) {
    switch (sortMode) {
      case NoteSortMode.dateDesc:
        _quickSortByDate(notes, true);
        break;
      case NoteSortMode.dateAsc:
        _quickSortByDate(notes, false);
        break;
      case NoteSortMode.alphabetical:
        _quickSortByContent(notes);
        break;
    }
  }

  // Эффективная реализация быстрой сортировки по дате
  void _quickSortByDate(List<Note> notes, bool descending) {
    if (notes.length <= 1) return;

    // Используем встроенную эффективную сортировку
    notes.sort((a, b) {
      final comparison = a.createdAt.compareTo(b.createdAt);
      return descending ? -comparison : comparison;
    });
  }

  // Эффективная реализация быстрой сортировки по содержимому
  void _quickSortByContent(List<Note> notes) {
    if (notes.length <= 1) return;

    // Кэшируем предварительно обработанный контент для сравнения
    final Map<String, String> contentCache = {};

    notes.sort((a, b) {
      // Получаем обработанный контент из кэша или создаем новый
      final aContent = contentCache[a.id] ?? _createComparisonText(a.content);
      final bContent = contentCache[b.id] ?? _createComparisonText(b.content);

      // Сохраняем в кэш
      contentCache[a.id] = aContent;
      contentCache[b.id] = bContent;

      return aContent.compareTo(bContent);
    });
  }

  // Создает текст для сравнения, удаляя спецсимволы и Markdown
  String _createComparisonText(String content) {
    return content
        .toLowerCase()
        .replaceAll(RegExp(r'[#*_`\[\]\(\)]+'), '') // Удаляем Markdown символы
        .replaceAll(RegExp(r'\s+'), ' ') // Нормализуем пробелы
        .trim();
  }

  // Улучшенное состояние "нет заметок"
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_add,
              size: 80, color: AppColors.secondary.withOpacity(0.7)),
          const SizedBox(height: 16),
          const Text(
            'Нет заметок',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте свою первую заметку',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              NotesScreen.showAddNoteDialog(context);
            },
            icon: const Icon(Icons.add),
            label: const Text('Создать заметку'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.mediumPadding * 2,
                vertical: AppDimens.mediumPadding,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Отображение индикаторов медиа и тем
  Widget _buildNoteIndicators(Note note) {
    return Row(
      children: [
        if (note.hasImages)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.photo, size: 14, color: AppColors.textOnLight),
          ),
        if (note.hasAudio)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Icon(Icons.mic, size: 14, color: AppColors.textOnLight),
          ),
        if (note.hasFiles)
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child:
                Icon(Icons.attach_file, size: 14, color: AppColors.textOnLight),
          ),
        const Spacer(),
        if (note.themeIds.isNotEmpty) _buildThemeIndicators(note.themeIds),
      ],
    );
  }

  // Метод отображения индикаторов тем с кэшированием
  Widget _buildThemeIndicators(List<String> themeIds) {
    // Генерируем ключ для кэша
    final cacheKey = themeIds.join('_');

    // Проверяем кэш
    if (_themeTagsCache.containsKey(cacheKey)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: _themeTagsCache[cacheKey]!,
      );
    }

    // Если нет в кэше, создаем индикаторы
    final indicators = <Widget>[];

    // Ограничиваем количество отображаемых индикаторов
    final displayCount = math.min(themeIds.length, 3);

    // Обработка каждой темы
    for (var i = 0; i < displayCount; i++) {
      if (i >= themeIds.length) break;

      final themeId = themeIds[i];
      final themeColor = _getThemeColor(themeId);

      indicators.add(
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: themeColor,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    // Добавляем индикатор "+X" если есть еще темы
    if (themeIds.length > 3) {
      indicators.add(
        Container(
          margin: const EdgeInsets.only(left: 4),
          child: Text(
            '+${themeIds.length - 3}',
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 10,
            ),
          ),
        ),
      );
    }

    // Сохраняем в кэш
    _themeTagsCache[cacheKey] = indicators;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: indicators,
    );
  }

  // Метод для отображения тегов тем в режиме списка с кэшированием
  Widget _buildThemeTags(List<String> themeIds) {
    // Используем кэш для тегов
    final cacheKey = 'tags_${themeIds.join('_')}';

    if (_themeTagsCache.containsKey(cacheKey)) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        children: _themeTagsCache[cacheKey]!,
      );
    }

    // Ограничимся отображением максимум 2 тем для компактности
    final displayIds = themeIds.take(2).toList();
    final widgets = <Widget>[];

    // Создаем тег для каждой темы
    for (final id in displayIds) {
      final themeColor = _getThemeColor(id);
      final themeName = _getThemeName(id);

      widgets.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: themeColor.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: Text(
            themeName,
            style: TextStyle(
              fontSize: 10,
              color: themeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // Показываем "+X" если есть дополнительные темы
    if (themeIds.length > 2) {
      widgets.add(
        Text(
          '+${themeIds.length - 2}',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textOnLight.withOpacity(0.6),
          ),
        ),
      );
    }

    // Сохраняем в кэш
    _themeTagsCache[cacheKey] = widgets;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: widgets,
    );
  }

  // Получение имени темы по ID с использованием кэша
  String _getThemeName(String themeId) {
    final themesProvider = Provider.of<ThemesProvider>(context, listen: false);
    final theme = themesProvider.getThemeById(themeId);
    return theme?.name ?? 'Без темы';
  }

  // Открытие экрана детальной информации о заметке
  void _viewNoteDetails(Note note) {
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
      // Обновляем заметки после возврата с экрана редактирования
      if (mounted) {
        // Инвалидируем кэши и перезагружаем данные
        _clearCaches();
        Provider.of<NotesProvider>(context, listen: false).loadNotes();
      }
    });
  }

  // Улучшенный диалог подтверждения удаления с анализом важности заметки
  Future<bool> _showDeleteConfirmation(Note note) async {
    if (!mounted) return false;

    // Проверка, содержит ли заметка важный контент
    final isImportant = note.hasDeadline ||
        note.content.length > 200 ||
        note.mediaUrls.isNotEmpty;

    final shouldDelete = await showDialog<bool>(
          context: context,
          barrierDismissible:
              !isImportant, // Можно закрыть касанием фона только для неважных заметок
          builder: (context) => AlertDialog(
            title: const Text('Удалить заметку'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Вы уверены, что хотите удалить эту заметку? Это действие нельзя будет отменить.'),

                // Предпросмотр только для важных заметок
                if (isImportant) ...[
                  const SizedBox(height: 16),
                  const Text('Содержимое заметки:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _createPreviewFromMarkdown(note.content, 100),
                      style: const TextStyle(fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;

    // Если пользователь подтвердил удаление, выполняем операцию
    if (shouldDelete && mounted) {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      try {
        await notesProvider.deleteNote(note.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Заметка удалена'),
              duration: Duration(seconds: 2),
            ),
          );

          // Обновляем список заметок
          _invalidateNoteCache(note.id);
          setState(() {});
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при удалении: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }

    return shouldDelete;
  }
}

// Вспомогательный класс для работы с Selector
class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;

  Tuple2(this.item1, this.item2);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tuple2 && other.item1 == item1 && other.item2 == item2;
  }

  @override
  int get hashCode => item1.hashCode ^ item2.hashCode;
}
