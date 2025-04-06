import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/themes_provider.dart';
import '../providers/notes_provider.dart';
import '../utils/constants.dart';
import 'note_detail_screen.dart';
import 'theme_detail_screen.dart';
import '../widgets/note_list.dart';
import '../widgets/media_badge.dart';

class ThemeNotesScreen extends StatefulWidget {
  final NoteTheme theme;

  const ThemeNotesScreen({super.key, required this.theme});

  @override
  State<ThemeNotesScreen> createState() => _ThemeNotesScreenState();
}

class _ThemeNotesScreenState extends State<ThemeNotesScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<Note> _themeNotes = [];
  late Color _themeColor;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool _isColorDark(Color color) {
    // Формула для вычисления яркости (0-1)
    double brightness =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return brightness < 0.3; // Если яркость < 0.3, считаем цвет тёмным
  }

  @override
  void initState() {
    super.initState();
    _initThemeColor();

    // Настройка анимации
    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimations.mediumDuration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _loadNotes();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initThemeColor() {
    try {
      _themeColor = Color(int.parse(widget.theme.color));
    } catch (e) {
      debugPrint('Ошибка при парсинге цвета темы: $e');
      _themeColor = AppColors.themeColors[0];
    }
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final themesProvider = Provider.of<ThemesProvider>(
        context,
        listen: false,
      );
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      // Обновляем данные заметок и тем
      await Future.wait([
        notesProvider.loadNotes(force: true),
        themesProvider.loadThemes(force: true),
      ]);

      // Запрашиваем заметки для конкретной темы
      final notesList = await themesProvider.getNotesForTheme(
        widget.theme.id,
        forceRefresh: true,
      );

      // Сортировка и установка заметок
      notesList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _themeNotes = notesList;
          _isLoading = false;
        });

        debugPrint(
          'Загружено ${notesList.length} заметок для темы: ${widget.theme.name}',
        );
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке заметок темы: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Не удалось загрузить заметки: $e';
        });

        // Показываем сообщение об ошибке пользователю
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ошибка загрузки заметок'),
            action: SnackBarAction(label: 'Повторить', onPressed: _loadNotes),
          ),
        );
      }
    }
  }

  void _createNoteInTheme() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => NoteDetailScreen(initialThemeIds: [widget.theme.id]),
      ),
    ).then((_) {
      _loadNotes();
    });
  }

  void _editTheme() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ThemeDetailScreen(theme: widget.theme),
      ),
    ).then((_) {
      // Обновляем цвет темы и список заметок
      _initThemeColor();
      _loadNotes();
    });
  }

  Widget _buildThemeLogo(NoteTheme theme, Color themeColor) {
    // Получаем номер иконки (от 01 до 55)
    String iconNumber = (theme.logoType.index + 1).toString().padLeft(2, '0');
    String assetName = 'assets/icons/$iconNumber.png';

    // Проверяем, является ли цвет темы темным
    bool isDark = _isColorDark(themeColor);

    // Создаем круглую форму с иконкой внутри
    return Material(
      shape: const CircleBorder(),
      color: themeColor, // Используем цвет темы как фон
      elevation: 4,
      shadowColor: themeColor.withOpacity(0.3),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Padding(
          padding: const EdgeInsets.all(6.0), // Отступ для иконки
          child: ClipOval(
            child:
                isDark
                    ? ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      child: Image.asset(
                        assetName,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.image_not_supported,
                            color: Colors.white,
                            size: 24,
                          );
                        },
                      ),
                    )
                    : Image.asset(
                      assetName,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported,
                          color: Colors.black,
                          size: 24,
                        );
                      },
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeLogoIcon(ThemeLogoType logoType) {
    // Получаем номер иконки (от 01 до 55)
    String iconNumber = (logoType.index + 1).toString().padLeft(2, '0');
    String assetName = 'assets/icons/$iconNumber.png';

    // Проверяем, является ли цвет темы темным (здесь нужно передать цвет параметром)
    Color themeColor = Colors.blue; // Замените на реальный цвет темы
    bool isDark = _isColorDark(themeColor);

    return isDark
        ? ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          child: Image.asset(
            assetName,
            width: 18,
            height: 18,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.image_not_supported,
                color: Colors.white,
                size: 18,
              );
            },
          ),
        )
        : Image.asset(
          assetName,
          width: 18,
          height: 18,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.image_not_supported,
              color: Colors.white,
              size: 18,
            );
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              margin: const EdgeInsets.only(right: 12),
              child: _buildThemeLogo(widget.theme, _themeColor),
            ),
            Expanded(child: Text(widget.theme.name)),
          ],
        ),
        actions: [
          // Счетчик заметок в теме
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _themeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                _themeNotes.length.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _themeColor,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editTheme,
            tooltip: 'Редактировать тему',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotes,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Произошла ошибка',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_errorMessage, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotes,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [
                    // Информация о теме
                    if (widget.theme.description != null &&
                        widget.theme.description!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _themeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _themeColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.theme.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: _themeColor.withOpacity(0.8),
                          ),
                        ),
                      ),

                    // Список заметок
                    Expanded(
                      child:
                          _themeNotes.isEmpty
                              ? _buildEmptyState()
                              : _buildNotesInTheme(),
                    ),
                  ],
                ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _themeColor,
        foregroundColor:
            _isColorDark(_themeColor) ? Colors.white : Colors.black87,
        onPressed: _createNoteInTheme,
        tooltip: 'Создать заметку',
        child: const Icon(Icons.add),
        heroTag: 'themeNotesScreenFAB',
      ),
    );
  }

  // Метод для построения списка заметок в теме с использованием NoteListWidget
  Widget _buildNotesInTheme() {
    return NoteListWidget(
      notes: _themeNotes,
      emptyMessage: 'В этой теме пока нет заметок',
      showThemeBadges:
          false, // Не показываем метки тем, так как уже в контексте темы
      isInThemeView: true, // Указываем, что находимся в контексте темы
      themeId: widget.theme.id,
      swipeDirection: SwipeDirection.both,
      showOptionsOnLongPress: true,
      availableActions: const [
        NoteListAction.edit,
        NoteListAction.favorite,
        NoteListAction.unlinkFromTheme,
        NoteListAction.delete,
      ],
      onNoteUnlinked: (note) {
        _removeNoteFromTheme(note.id);
      },
      onNoteDeleted: (note) {
        _loadNotes();
      },
      onNoteFavoriteToggled: (note) {
        _loadNotes();
      },
      onNoteTap: (note) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NoteDetailScreen(note: note)),
        ).then((_) {
          _loadNotes();
        });
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_alt_outlined,
            size: 80,
            color: _themeColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'В теме "${widget.theme.name}" пока нет заметок',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте заметку и добавьте её в эту тему',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createNoteInTheme,
            icon: const Icon(Icons.add),
            label: const Text('Создать заметку'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _themeColor,
              foregroundColor:
                  _isColorDark(_themeColor) ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeNoteFromTheme(String noteId) async {
    final themesProvider = Provider.of<ThemesProvider>(context, listen: false);

    try {
      // Используем правильный метод из провайдера тем
      final success = await themesProvider.removeNoteFromTheme(
        noteId,
        widget.theme.id,
      );

      if (success) {
        // Перезагружаем заметки темы
        _loadNotes();

        // Сообщаем пользователю об успешном удалении
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Заметка отвязана от темы'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось отвязать заметку от темы'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Ошибка при отвязке заметки от темы: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }
}
