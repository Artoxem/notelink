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

// Клиппер для треугольной формы
class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(TriangleClipper oldClipper) => false;
}

// Клиппер для пятиугольной формы
class PentagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height * 0.4);
    path.lineTo(size.width * 0.8, size.height);
    path.lineTo(size.width * 0.2, size.height);
    path.lineTo(0, size.height * 0.4);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(PentagonClipper oldClipper) => false;
}

class _ThemeNotesScreenState extends State<ThemeNotesScreen> {
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<Note> _themeNotes = [];
  Color _themeColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _initThemeColor();
    _loadNotes();
  }

  void _initThemeColor() {
    try {
      _themeColor = Color(int.parse(widget.theme.color));
    } catch (e) {
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
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      // Добавление отладочной информации
      print(
          'Загружаем заметки для темы: ${widget.theme.id}, ${widget.theme.name}');

      final notesList = await themesProvider.getNotesForTheme(widget.theme.id);
      print('Загружено ${notesList.length} заметок');

      // Сортировка и установка заметок
      notesList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _themeNotes = notesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Критическая ошибка при загрузке заметок темы: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Не удалось загрузить заметки: $e';
        });
        // Показываем сообщение об ошибке пользователю
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки заметок'),
            action: SnackBarAction(
              label: 'Повторить',
              onPressed: _loadNotes,
            ),
          ),
        );
      }
    }
  }

  void _createNoteInTheme() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          initialThemeIds: [widget.theme.id],
        ),
      ),
    ).then((_) {
      _loadNotes();
    });
  }

  void _editTheme() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ThemeDetailScreen(
          theme: widget.theme,
          // Удаляем параметр isEditMode: true
        ),
      ),
    ).then((_) {
      _loadNotes();
    });
  }

  // Добавляем метод для отображения логотипа темы
  Widget _buildThemeLogo(NoteTheme theme, Color themeColor) {
    // Определяем форму и содержимое логотипа в зависимости от типа
    Widget icon;
    ShapeBorder? shape;
    Widget? customShape;

    switch (theme.logoType) {
      case ThemeLogoType.book:
        // Круглая форма с иконкой книги
        icon = const Icon(
          Icons.book,
          color: Colors.white,
          size: 24,
        );
        shape = const CircleBorder();
        break;

      case ThemeLogoType.shapes:
        // Квадратная форма с иконкой геометрических фигур
        icon = const Icon(
          Icons.category,
          color: Colors.white,
          size: 24,
        );
        shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        );
        break;

      case ThemeLogoType.feather:
        // Треугольная форма с иконкой пера
        icon = const Icon(
          Icons.edit,
          color: Colors.white,
          size: 24,
        );
        // Треугольная форма реализована через ClipPath
        customShape = ClipPath(
          clipper: TriangleClipper(),
          child: Container(
            width: 48,
            height: 48,
            color: themeColor,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: icon,
              ),
            ),
          ),
        );
        break;

      case ThemeLogoType.scroll:
        // Пятиугольная форма с иконкой свитка
        icon = const Icon(
          Icons.description,
          color: Colors.white,
          size: 24,
        );
        // Пятиугольная форма реализована через ClipPath
        customShape = ClipPath(
          clipper: PentagonClipper(),
          child: Container(
            width: 48,
            height: 48,
            color: themeColor,
            child: Center(child: icon),
          ),
        );
        break;

      case ThemeLogoType.microphone:
        // Микрофон - добавляем новые типы
        icon = const Icon(
          Icons.mic,
          color: Colors.white,
          size: 24,
        );
        shape = const CircleBorder();
        break;

      case ThemeLogoType.code:
        // Программирование
        icon = const Icon(
          Icons.code,
          color: Colors.white,
          size: 24,
        );
        shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        );
        break;

      case ThemeLogoType.graduation:
        // Образование
        icon = const Icon(
          Icons.school,
          color: Colors.white,
          size: 24,
        );
        shape = const CircleBorder();
        break;

      case ThemeLogoType.beach:
        // Отдых
        icon = const Icon(
          Icons.beach_access,
          color: Colors.white,
          size: 24,
        );
        shape = const CircleBorder();
        break;

      case ThemeLogoType.party:
        // Праздники
        icon = const Icon(
          Icons.celebration,
          color: Colors.white,
          size: 24,
        );
        shape = const CircleBorder();
        break;

      case ThemeLogoType.home:
        // Дом
        icon = const Icon(
          Icons.home,
          color: Colors.white,
          size: 24,
        );
        shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        );
        break;

      case ThemeLogoType.business:
        // Бизнес
        icon = const Icon(
          Icons.business_center,
          color: Colors.white,
          size: 24,
        );
        shape = const CircleBorder();
        break;

      case ThemeLogoType.fitness:
        // Фитнес
        icon = const Icon(
          Icons.fitness_center,
          color: Colors.white,
          size: 24,
        );
        shape = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        );
        break;

      default:
        // По умолчанию - круглая форма с иконкой книги
        icon = const Icon(
          Icons.book,
          color: Colors.white,
          size: 24,
        );
        shape = const CircleBorder();
    }

    // Если есть кастомная форма, возвращаем ее
    if (customShape != null) {
      return customShape;
    }

    // Стандартная реализация для круглой и квадратной форм
    return Material(
      shape: shape,
      color: themeColor,
      elevation: 4,
      shadowColor: themeColor.withOpacity(0.3),
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(child: icon),
      ),
    );
  }

  // Добавляем метод для отображения правильной иконки в зависимости от типа логотипа
  Widget _buildThemeLogoIcon(ThemeLogoType logoType) {
    // Определяем иконку в зависимости от типа логотипа
    IconData iconData;

    switch (logoType) {
      case ThemeLogoType.book:
        iconData = Icons.auto_stories;
        break;
      case ThemeLogoType.shapes:
        iconData = Icons.category;
        break;
      case ThemeLogoType.feather:
        iconData = Icons.brush;
        break;
      case ThemeLogoType.scroll:
        iconData = Icons.description;
        break;
      case ThemeLogoType.microphone:
        iconData = Icons.mic;
        break;
      case ThemeLogoType.code:
        iconData = Icons.code;
        break;
      case ThemeLogoType.graduation:
        iconData = Icons.school;
        break;
      case ThemeLogoType.beach:
        iconData = Icons.beach_access;
        break;
      case ThemeLogoType.party:
        iconData = Icons.celebration;
        break;
      case ThemeLogoType.home:
        iconData = Icons.home;
        break;
      case ThemeLogoType.business:
        iconData = Icons.business_center;
        break;
      case ThemeLogoType.fitness:
        iconData = Icons.fitness_center;
        break;
      default:
        iconData = Icons.auto_stories; // Значение по умолчанию
    }

    return Icon(
      iconData,
      color: Colors.white,
      size: 18,
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
            Expanded(
              child: Text('Тема: ${widget.theme.name}'),
            ),
          ],
        ),
        // Удалили покраску AppBar в цвет темы
        // Теперь используется стандартный цвет приложения
        actions: [
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Произошла ошибка',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotes,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : _themeNotes.isEmpty
                  ? _buildEmptyState()
                  : _buildNotesInTheme(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _themeColor,
        onPressed: _createNoteInTheme,
        tooltip: 'Создать заметку',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Новый метод для построения списка заметок в теме с использованием NoteListWidget
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
        NoteListAction.delete
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
          MaterialPageRoute(
            builder: (context) => NoteDetailScreen(note: note),
          ),
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
            color: AppColors.secondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'В этой теме пока нет заметок',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          ),
        ],
      ),
    );
  }

  Future<void> _removeNoteFromTheme(String noteId) async {
    if (widget.theme != null) {
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      await themesProvider.unlinkNoteFromTheme(widget.theme.id, noteId);

      // Перезагружаем заметки темы
      _loadNotes();
    }
  }
}
