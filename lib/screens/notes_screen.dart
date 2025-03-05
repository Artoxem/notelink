import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../providers/app_provider.dart';
import '../providers/themes_provider.dart';
import '../providers/note_links_provider.dart';
import '../models/note.dart';
import '../utils/constants.dart';
import 'note_detail_screen.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/theme.dart';

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
  late AnimationController _itemAnimationController;
  final Map<String, Animation<double>> _itemAnimations = {};

  @override
  void initState() {
    super.initState();

    // Инициализируем контроллер анимации
    _itemAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimations.shortDuration,
    );

    // Загружаем заметки при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() async {
    // Загружаем заметки, темы и связи между ними
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final themesProvider = Provider.of<ThemesProvider>(context, listen: false);
    final linksProvider =
        Provider.of<NoteLinksProvider>(context, listen: false);

    await notesProvider.loadNotes();
    await themesProvider.loadThemes();
    await linksProvider.loadLinks();

    // Инициализируем анимации для каждой заметки
    _initializeItemAnimations(notesProvider.notes);
  }

  void _initializeItemAnimations(List<Note> notes) {
    for (var note in notes) {
      if (!_itemAnimations.containsKey(note.id)) {
        // Создаем анимацию для каждой заметки с небольшим случайным смещением,
        // чтобы они не анимировались все одновременно
        final random = math.Random();
        final delay =
            random.nextDouble() * 0.5; // Случайная задержка от 0 до 0.5

        _itemAnimations[note.id] = CurvedAnimation(
          parent: _itemAnimationController,
          curve: Interval(
            delay, // Начальное значение (с задержкой)
            1.0, // Конечное значение
            curve: Curves.easeOutQuint,
          ),
        );
      }
    }

    // Запускаем анимацию
    _itemAnimationController.forward();
  }

  @override
  void dispose() {
    _itemAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotesProvider, AppProvider>(
      builder: (context, notesProvider, appProvider, _) {
        if (notesProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Получаем все заметки
        final notes = notesProvider.notes;
        print('Количество заметок для отображения: ${notes.length}');

        // Сортируем заметки в зависимости от настроек
        switch (appProvider.noteSortMode) {
          case NoteSortMode.dateDesc:
            notes.sort((a, b) =>
                b.createdAt.compareTo(a.createdAt)); // От новых к старым
            break;
          case NoteSortMode.dateAsc:
            notes.sort((a, b) =>
                a.createdAt.compareTo(b.createdAt)); // От старых к новым
            break;
          case NoteSortMode.alphabetical:
            notes.sort((a, b) => a.content.compareTo(b.content)); // По алфавиту
            break;
        }

        if (notes.isEmpty) {
          return _buildEmptyState();
        }

        // Отображаем список заметок в выбранном режиме
        return _buildNotesList(notes, appProvider.noteViewMode, notesProvider);
      },
    );
  }

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

  Widget _buildNotesList(
      List<Note> notes, NoteViewMode viewMode, NotesProvider notesProvider) {
    // Выбираем режим отображения
    return Padding(
      padding: const EdgeInsets.all(AppDimens.mediumPadding),
      child: viewMode == NoteViewMode.card
          ? GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8, // Соотношение сторон карточки
              ),
              itemCount: notes.length,
              itemBuilder: (context, index) =>
                  _buildNoteCard(notes[index], notesProvider),
            )
          : ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) =>
                  _buildNoteListItem(notes[index], notesProvider),
            ),
    );
  }

  Widget _buildNoteCard(Note note, NotesProvider notesProvider) {
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

    // Создаем анимацию для заметки
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
      child: Dismissible(
        key: Key(note.id),
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
        // Подтверждение действия при свайпе
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Свайп влево - удаление
            return await _showDeleteConfirmation(note);
          } else if (direction == DismissDirection.startToEnd) {
            // Свайп вправо - добавление в избранное
            await notesProvider.toggleFavorite(note.id);

            // Показываем уведомление
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(note.isFavorite
                    ? 'Заметка добавлена в избранное'
                    : 'Заметка удалена из избранного'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.accentSecondary,
              ),
            );

            return false; // Не убираем виджет после свайпа в избранное
          }
          return false;
        },
        // Действие после успешного свайпа
        onDismissed: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Удаляем связи и саму заметку
            final linksProvider =
                Provider.of<NoteLinksProvider>(context, listen: false);
            await linksProvider.deleteLinksForNote(note.id);
            await notesProvider.deleteNote(note.id);
          }
        },
        child: Stack(
          children: [
            AnimatedContainer(
              duration: AppAnimations.mediumDuration,
              curve: Curves.easeOutQuint,
              decoration: BoxDecoration(
                color: AppColors.cardBackground, // White Asparagus
                borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _viewNoteDetails(note),
                  onLongPress: () => _showNoteOptions(note),
                  borderRadius:
                      BorderRadius.circular(AppDimens.cardBorderRadius),
                  child: Row(
                    children: [
                      // Цветной индикатор слева
                      Container(
                        width: 6,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: indicatorColor,
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
                          padding:
                              const EdgeInsets.all(AppDimens.mediumPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Верхняя часть с датой и меню
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                          size: 18,
                                          color: AppColors.textOnLight),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Содержимое заметки
                              Expanded(
                                child: Text(
                                  note.content,
                                  maxLines: 8,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMediumLight,
                                ),
                              ),

                              // Нижняя часть с информацией о дедлайне и темах
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
                              // Индикаторы медиа и тем
                              if (note.mediaUrls.isNotEmpty ||
                                  note.themeIds.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      if (note.hasImages)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(Icons.photo,
                                              size: 14,
                                              color: AppColors.textOnLight),
                                        ),
                                      if (note.hasAudio)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(Icons.mic,
                                              size: 14,
                                              color: AppColors.textOnLight),
                                        ),
                                      if (note.hasFiles)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(Icons.attach_file,
                                              size: 14,
                                              color: AppColors.textOnLight),
                                        ),
                                      const Spacer(),
                                      if (note.themeIds.isNotEmpty)
                                        _buildThemeIndicators(note.themeIds),
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
            ),

            // Индикатор избранного
            if (note.isFavorite)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(AppDimens.cardBorderRadius),
                      bottomLeft:
                          Radius.circular(AppDimens.cardBorderRadius - 4),
                    ),
                  ),
                  child: const Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteListItem(Note note, NotesProvider notesProvider) {
    // Определяем цвет бордюра в зависимости от статуса
    final borderColor = _getNoteStatusColor(note);

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
      child: Dismissible(
        key: Key(note.id),
        // Настройка фона для свайпа вправо (избранное)
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20.0),
          color: Colors.amber,
          child: const Icon(
            Icons.star,
            color: Colors.white,
          ),
        ),
        // Настройка фона для свайпа влево (удаление)
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          color: Colors.red,
          child: const Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
        // Настройка направлений свайпа
        direction: DismissDirection.horizontal,
        // Подтверждение действия после свайпа
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Свайп влево - удаление
            return await _showDeleteConfirmation(note);
          } else if (direction == DismissDirection.startToEnd) {
            // Свайп вправо - добавление в избранное
            await notesProvider.toggleFavorite(note.id);

            // Показываем уведомление
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(note.isFavorite
                    ? 'Заметка добавлена в избранное'
                    : 'Заметка удалена из избранного'),
                duration: const Duration(seconds: 2),
                backgroundColor: AppColors.accentSecondary,
              ),
            );

            return false; // Не убираем виджет после свайпа в избранное
          }
          return false;
        },
        // Действие после успешного свайпа
        onDismissed: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Удаляем связи и саму заметку
            final linksProvider =
                Provider.of<NoteLinksProvider>(context, listen: false);
            await linksProvider.deleteLinksForNote(note.id);
            await notesProvider.deleteNote(note.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AnimatedContainer(
            duration: AppAnimations.mediumDuration,
            curve: Curves.easeOutQuint,
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border(
                left: BorderSide(
                  color: borderColor,
                  width: 4,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _viewNoteDetails(note),
                onLongPress: () => _showNoteOptions(note),
                borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.mediumPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Иконка в зависимости от типа
                      CircleAvatar(
                        backgroundColor: borderColor.withOpacity(0.8),
                        radius: 16,
                        child: Icon(
                          note.hasDeadline
                              ? (note.isCompleted
                                  ? Icons.check_circle
                                  : Icons.timer)
                              : Icons.note,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Информация о дате и времени
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  DateFormat('d MMMM yyyy, HH:mm')
                                      .format(note.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                if (note.isFavorite)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                            if (note.hasDeadline && note.deadlineDate != null)
                              Text(
                                'Дедлайн: ${DateFormat('d MMMM yyyy').format(note.deadlineDate!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: borderColor,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              note.content,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ),

                      // Правая часть с кнопкой меню
                      IconButton(
                        icon: const Icon(
                          AppIcons.more,
                          size: 18,
                        ),
                        onPressed: () => _showNoteOptions(note),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Метод для отображения индикаторов тем
  Widget _buildThemeIndicators(List<String> themeIds) {
    // Ограничиваем количество отображаемых индикаторов
    final displayCount = math.min(themeIds.length, 3);

    return Consumer<ThemesProvider>(
      builder: (context, themesProvider, _) {
        final indicators = <Widget>[];

        for (var i = 0; i < displayCount; i++) {
          final theme = themesProvider.themes.firstWhere(
            (t) => t.id == themeIds[i],
            orElse: () => themesProvider.themes.first, // Запасной вариант
          );

          Color themeColor;
          try {
            themeColor = Color(int.parse(theme.color));
          } catch (e) {
            themeColor = AppColors.themeColors.first;
          }

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

        return Row(children: indicators);
      },
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
      Provider.of<NotesProvider>(context, listen: false).loadNotes();
    });
  }

  void _showNoteOptions(Note note) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final linksProvider =
        Provider.of<NoteLinksProvider>(context, listen: false);

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
                  Navigator.pop(context);
                  _viewNoteDetails(note);
                },
              ),
              if (note.hasDeadline && !note.isCompleted)
                ListTile(
                  leading: const Icon(Icons.check_circle,
                      color: AppColors.completed),
                  title: const Text('Отметить как выполненное'),
                  onTap: () async {
                    Navigator.pop(context);
                    await notesProvider.completeNote(note.id);
                  },
                ),
              if (note.hasDeadline)
                ListTile(
                  leading: const Icon(Icons.update,
                      color: AppColors.accentSecondary),
                  title: const Text('Продлить дедлайн'),
                  onTap: () async {
                    Navigator.pop(context);
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: note.deadlineDate!.isBefore(DateTime.now())
                          ? DateTime.now().add(const Duration(days: 1))
                          : note.deadlineDate!.add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (selectedDate != null) {
                      await notesProvider.extendDeadline(note.id, selectedDate);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.link, color: AppColors.accentPrimary),
                title: const Text('Связи и ссылки'),
                onTap: () {
                  Navigator.pop(context);
                  // Здесь будет логика отображения и управления связями
                  // TODO: Реализовать экран управления связями
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
                  await notesProvider.toggleFavorite(note.id);
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

  Future<bool> _showDeleteConfirmation(Note note) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заметку'),
        content: const Text(
            'Вы уверены, что хотите удалить эту заметку? Это действие нельзя будет отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      // Удаляем связи и саму заметку
      final linksProvider =
          Provider.of<NoteLinksProvider>(context, listen: false);
      await linksProvider.deleteLinksForNote(note.id);
      await Provider.of<NotesProvider>(context, listen: false)
          .deleteNote(note.id);
      return true;
    }

    return false;
  }
}
