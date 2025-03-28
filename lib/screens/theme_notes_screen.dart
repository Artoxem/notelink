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
    // Определяем номер иконки из типа логотипа
    String iconNumber;

    if (theme.logoType.index <= 11) {
      // Для старых названий используем смещение
      iconNumber = (theme.logoType.index + 1).toString().padLeft(2, '0');
    } else {
      // Для новых типов используем номер из названия
      iconNumber = (theme.logoType.index - 11 + 13).toString().padLeft(2, '0');
    }

    String assetName = 'assets/icons/aztec$iconNumber.png';

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
            child: Image.asset(
              assetName,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image_not_supported,
                  color: Colors.white,
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
  // Определяем номер иконки из типа логотипа
  String iconNumber;
  
  if (logoType.index <= 11) {
    // Для старых названий используем смещение
    iconNumber = (logoType.index + 1).toString().padLeft(2, '0');
  } else {
    // Для новых типов используем номер из названия
    iconNumber = (logoType.index - 11 + 13).toString().padLeft(2, '0');
  }
  
  String assetName = 'assets/icons/aztec$iconNumber.png';
  
  return Image.asset(
    assetName,
    width: 18,
    height: 18,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) {
      return Icon(
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
