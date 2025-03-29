import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/app_provider.dart';
import '../providers/themes_provider.dart';
import '../utils/constants.dart';
import '../utils/note_status_utils.dart';
import '../utils/image_cache_helper.dart';
import '../widgets/audio_wave_preview.dart';
import '../widgets/media_badge.dart';
import 'note_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/note_list.dart';

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

  // Кэш для медиа-статистики
  final Map<String, Map<String, int>> _mediaCountCache = {};

  // Кэш миниатюр изображений
  final ImageCacheHelper _imageCacheHelper = ImageCacheHelper();

  // Время последнего обновления для инвалидации кэшей
  DateTime _lastCacheUpdate = DateTime.now();

  // Регулярные выражения для обработки Markdown (вынесены на уровень класса)
  final RegExp _headingsRegex = RegExp(r'#{1,6}\s+');
  final RegExp _boldRegex = RegExp(r'\*\*|__');
  final RegExp _italicRegex = RegExp(r'\*|_(?!\*)');
  final RegExp _linksRegex = RegExp(r'\[([^\]]+)\]\([^)]+\)');
  final RegExp _codeRegex = RegExp(r'`[^`]+`');
  final RegExp _voiceRegex = RegExp(r'!\[voice\]\(voice:[^)]+\)');

  // Контролируем состояние загрузки
  bool _isRefreshing = false;

  // Подсчитаем количество каждого типа медиа в заметке
  Map<String, int> _getMediaCounts(Note note) {
    // Проверяем кэш сначала
    if (_mediaCountCache.containsKey(note.id)) {
      return _mediaCountCache[note.id]!;
    }

    int imagesCount = 0;
    int audioCount = 0;
    int fileCount = 0;
    int voiceCount = 0;

    // Подсчитываем разные типы медиа
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
        fileCount++;
      }
    }

    // Подсчитываем голосовые заметки из содержимого
    final voiceMatches = _voiceRegex.allMatches(note.content);
    voiceCount = voiceMatches.length;

    // Сохраняем результат в кэш
    final result = {
      'images': imagesCount,
      'audio': audioCount,
      'files': fileCount,
      'voice': voiceCount,
    };

    _mediaCountCache[note.id] = result;
    return result;
  }

  @override
  void initState() {
    super.initState();

    // Инициализация контроллера анимации
    _itemAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimations.shortDuration,
    );

    // Инициализация кэша изображений
    _imageCacheHelper.initialize();

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
    _mediaCountCache.clear();
  }

  // Инвалидация кэшей, связанных с заметкой
  void _invalidateNoteCache(String noteId) {
    _noteColorCache.remove(noteId);
    _mediaCountCache.remove(noteId);
  }

  Widget _buildNoteContentPreview(Note note) {
    // Регулярное выражение для поиска маркеров голосовых заметок
    final RegExp voiceRegex = RegExp(r'!\[voice\]\(voice:[^)]+\)');
    final String content = note.content;

    // Проверяем наличие голосовых заметок
    final bool hasVoiceNote = voiceRegex.hasMatch(content);

    // Получаем текст для превью (без маркеров голосовых заметок)
    String previewText = _createPreviewFromMarkdown(content, 150);

    if (hasVoiceNote) {
      // Если есть голосовая заметка, показываем индикатор + текст
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Индикатор голосовой заметки
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              size: 14,
              color: Colors.purple,
            ),
          ),

          // Текст превью
          Expanded(
            child: ShaderMask(
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
                previewText.trim(),
                style: AppTextStyles.bodySmallLight.copyWith(
                  fontSize: 14,
                ),
                maxLines: 2,
              ),
            ),
          ),
        ],
      );
    } else {
      // Стандартное отображение без голосовой заметки
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
          style: AppTextStyles.bodySmallLight.copyWith(
            fontSize: 14,
          ),
          maxLines: 3,
        ),
      );
    }
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

    setState(() {
      _isRefreshing = true;
    });

    try {
      // Загружаем заметки, темы и связи между ними
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);

      try {
        // Используем принудительную перезагрузку данных
        await notesProvider
            .forceRefresh(); // Обновляем метод для принудительной перезагрузки
        await themesProvider.loadThemes();

        // Продолжаем только если компонент все еще в дереве
        if (!mounted) return;

        // Очищаем кэши после обновления данных
        _clearCaches();

        // Инициализируем анимации для каждой заметки
        _initializeItemAnimations(notesProvider.notes);

        // Обновляем время последнего обновления
        _lastCacheUpdate = DateTime.now();

        // Явно обновляем UI
        setState(() {});
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
          setState(() {
            _isRefreshing = false;
          });
        }
      }
    } catch (e) {
      print('Ошибка при получении провайдеров: $e');
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
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

    // Используем тернарный оператор вместо if-else для гарантированной инициализации
    final Widget listWidget = (viewMode == NoteViewMode.card)
        ? GridView.builder(
            key: key,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.98,
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
          )
        : NoteListWidget(
            key: key,
            notes: notes,
            emptyMessage: 'Нет заметок',
            showThemeBadges: true,
            useCachedAnimation: true,
            swipeDirection: SwipeDirection.both,
            showOptionsOnLongPress: true,
            onNoteDeleted: (note) async {
              await notesProvider.deleteNote(note.id);
            },
            onNoteFavoriteToggled: (note) async {
              // Переключение избранного будет обработано локально
            },
            onNoteTap: (note) {
              _viewNoteDetails(note);
            },
          );

    // Оборачиваем в RefreshIndicator
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

    // Для заметок без темы используем серый цвет
    if (note.themeIds.isEmpty) {
      color = Colors.grey;
    }
    // Если у заметки есть темы, используем цвет первой темы
    else if (note.themeIds.isNotEmpty) {
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

    // Получаем статистику медиа
    final mediaCounts = _getMediaCounts(note);

    // Очищаем контент только от меток голосовых заметок, сохраняя другое форматирование
    String cleanContent = note.content.replaceAll(_voiceRegex, '');

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
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Верхняя часть с датой, дедлайном и меню
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Колонка с датой и дедлайном
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Дата создания
                                    Text(
                                      DateFormat('d MMM yyyy')
                                          .format(note.createdAt),
                                      style:
                                          AppTextStyles.bodySmallLight.copyWith(
                                        fontSize: 13,
                                      ),
                                    ),

                                    // Минимальный вертикальный отступ
                                    if (note.hasDeadline &&
                                        note.deadlineDate != null)
                                      const SizedBox(height: 2),

                                    // Дедлайн под датой создания
                                    if (note.hasDeadline &&
                                        note.deadlineDate != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
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
                                              style: AppTextStyles.deadlineText,
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),

                                // Кнопка меню
                                const Spacer(),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(15),
                                    onTap: () => _showNoteOptions(note),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Icon(
                                        Icons.more_vert,
                                        size: 18,
                                        color: AppColors.textOnLight,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Содержимое заметки с поддержкой markdown
                            Expanded(
                              child: ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black, Colors.transparent],
                                    stops: const [0.7, 1.0],
                                  ).createShader(bounds);
                                },
                                blendMode: BlendMode.dstIn,
                                child: ClipRect(
                                  child: MarkdownBody(
                                    data: cleanContent.trim(),
                                    selectable: false,
                                    shrinkWrap: true,
                                    softLineBreak: true,
                                    styleSheet: MarkdownStyleSheet(
                                      p: AppTextStyles.bodyMediumLight
                                          .copyWith(fontSize: 13),
                                      h1: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textOnLight,
                                      ),
                                      h2: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textOnLight,
                                      ),
                                      h3: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textOnLight,
                                      ),
                                      em: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textOnLight,
                                      ),
                                      strong: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textOnLight,
                                      ),
                                      listBullet: AppTextStyles.bodyMediumLight
                                          .copyWith(
                                        fontSize: 13,
                                        color: AppColors.textOnLight,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Бейджи медиа внизу карточки (если есть)
                            if (mediaCounts.values.any((count) => count > 0))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    MediaBadgeGroup(
                                      imagesCount: mediaCounts['images'] ?? 0,
                                      audioCount: mediaCounts['audio'] ?? 0,
                                      voiceCount: mediaCounts['voice'] ?? 0,
                                      filesCount: mediaCounts['files'] ?? 0,
                                      badgeSize: AppMediaDimens.badgeSmallSize,
                                      spacing: 4.0,
                                      onBadgeTap: (type) {
                                        // Тактильная обратная связь при нажатии
                                        HapticFeedback.lightImpact();
                                        _viewNoteDetails(note);
                                      },
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
              Positioned(
                top: 0,
                left: 0,
                child: Material(
                  color: Colors.amber,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppDimens.cardBorderRadius),
                    bottomRight:
                        Radius.circular(AppDimens.cardBorderRadius - 1),
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

      // Подтверждение действия при свайпе с улучшенной обработкой ошибок
      confirmDismiss: (direction) async {
        if (!mounted) return false;

        try {
          if (direction == DismissDirection.endToStart) {
            // Код для удаления без изменений...
          } else if (direction == DismissDirection.startToEnd) {
            // Получаем провайдер из контекста
            final notesProvider =
                Provider.of<NotesProvider>(context, listen: false);

            // Свайп вправо - добавление/удаление из избранного
            await notesProvider.toggleFavorite(note.id);

            // Тактильная обратная связь
            HapticFeedback.lightImpact();

            // Получаем обновленную заметку после переключения
            final updatedNote = notesProvider.notes.firstWhere(
              (n) => n.id == note.id,
              orElse: () => note,
            );

            // Инвалидируем кэш для этой заметки
            _invalidateNoteCache(note.id);

            // Показываем сообщение
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(updatedNote.isFavorite
                      ? 'Заметка добавлена в избранное'
                      : 'Заметка удалена из избранного'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: AppColors.accentSecondary,
                ),
              );
            }

            // Обновляем UI
            if (mounted) {
              setState(() {});
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

  // Вспомогательные методы для извлечения заголовка и содержимого
  String _getFirstLine(String content) {
    // Сначала удаляем голосовые метки
    String cleanContent = content.replaceAll(_voiceRegex, '');

    final firstLineEnd = cleanContent.indexOf('\n');
    if (firstLineEnd == -1) return cleanContent;
    return cleanContent
        .substring(0, firstLineEnd)
        .trim()
        .replaceAll(RegExp(r'^#+\s+'), '');
  }

  String _getContentWithoutFirstLine(String content) {
    // Сначала удаляем голосовые метки
    String cleanContent = content.replaceAll(_voiceRegex, '');

    final firstLineEnd = cleanContent.indexOf('\n');
    if (firstLineEnd == -1) return '';
    return cleanContent.substring(firstLineEnd + 1).trim();
  }

  // Метод построения меню действий с заметкой с анимациями
  void _showNoteOptions(Note note) {
    if (!mounted) return;

    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    // Тактильная обратная связь
    HapticFeedback.mediumImpact();

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

              // Действия с анимациями и тактильной обратной связью
              _buildAnimatedActionTile(
                icon: note.isFavorite ? Icons.star_border : Icons.star,
                color: Colors.amber,
                text: note.isFavorite
                    ? 'Удалить из избранного'
                    : 'Добавить в избранное',
                onTap: () async {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);

                  try {
                    // Сохраняем исходное состояние для сравнения

                    await notesProvider.toggleFavorite(note.id);

                    // Получаем обновленную заметку
                    final updatedNote = notesProvider.notes.firstWhere(
                      (n) => n.id == note.id,
                      orElse: () => note,
                    );

                    // Инвалидируем кэш для этой заметки
                    _invalidateNoteCache(note.id);

                    // Обновляем UI и показываем подтверждение с правильным текстом
                    if (mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(updatedNote.isFavorite
                              ? 'Заметка добавлена в избранное'
                              : 'Заметка удалена из избранного'),
                        ),
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

              if (note.hasDeadline && !note.isCompleted)
                _buildAnimatedActionTile(
                  icon: Icons.check_circle,
                  color: AppColors.completed,
                  text: 'Отметить как выполненное',
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    try {
                      await notesProvider.completeNote(note.id);
                      _invalidateNoteCache(note.id);
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
                _buildAnimatedActionTile(
                  icon: Icons.update,
                  color: AppColors.accentSecondary,
                  text: 'Продлить дедлайн',
                  onTap: () async {
                    HapticFeedback.lightImpact();
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

              _buildAnimatedActionTile(
                icon: note.isFavorite ? Icons.star_border : Icons.star,
                color: Colors.amber,
                text: note.isFavorite
                    ? 'Удалить из избранного'
                    : 'Добавить в избранное',
                onTap: () async {
                  HapticFeedback.lightImpact();
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

              _buildAnimatedActionTile(
                icon: Icons.delete,
                color: Colors.red,
                text: 'Удалить',
                textColor: Colors.red,
                onTap: () {
                  HapticFeedback.heavyImpact();
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

  // Анимированный элемент действия для меню
  Widget _buildAnimatedActionTile({
    required IconData icon,
    required Color color,
    required String text,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            text,
            style: TextStyle(
              color: textColor ?? AppColors.textOnLight,
            ),
          ),
        ),
      ),
    );
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
        .replaceAll(_voiceRegex, '') // Удаляем голосовые метки
        .replaceAll(RegExp(r'[#*_`\[\]\(\)]+'), '') // Удаляем Markdown символы
        .replaceAll(RegExp(r'\s+'), ' ') // Нормализуем пробелы
        .trim();
  }

  // Улучшенное создание превью из Markdown-текста
  String _createPreviewFromMarkdown(String markdown, int maxLength) {
    if (markdown.isEmpty) {
      return '';
    }

    // Предварительная проверка наличия разметки
    bool hasMarkdown = _headingsRegex.hasMatch(markdown) ||
        _boldRegex.hasMatch(markdown) ||
        _italicRegex.hasMatch(markdown) ||
        _linksRegex.hasMatch(markdown) ||
        _codeRegex.hasMatch(markdown);

    if (!hasMarkdown) {
      // Если разметки нет, удаляем только ссылки на голосовые заметки
      String cleanText =
          markdown.replaceAll(_voiceRegex, '[голосовая заметка] ');
      return cleanText.length > maxLength
          ? '${cleanText.substring(0, maxLength)}...'
          : cleanText;
    }

    // Последовательно удаляем разметку
    String text = markdown;

    // Удаляем голосовые заметки и заменяем их маркером
    text = text.replaceAll(_voiceRegex, '[голосовая заметка] ');

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
              HapticFeedback.mediumImpact();
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

  // Открытие экрана детальной информации о заметке
  void _viewNoteDetails(Note note) {
    // Добавляем тактильную обратную связь
    HapticFeedback.lightImpact();

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

    // Тактильная обратная связь
    HapticFeedback.heavyImpact();

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
