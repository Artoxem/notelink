import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/themes_provider.dart';
import '../providers/notes_provider.dart';
import '../utils/constants.dart';
import 'note_detail_screen.dart';
import 'theme_detail_screen.dart';
import '../utils/note_status_utils.dart';
import 'package:intl/intl.dart';

class ThemeNotesScreen extends StatefulWidget {
  final NoteTheme theme;

  const ThemeNotesScreen({super.key, required this.theme});

  @override
  State<ThemeNotesScreen> createState() => _ThemeNotesScreenState();
}

class _ThemeNotesScreenState extends State<ThemeNotesScreen> {
  bool _isLoading = false;
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
    });

    try {
      // Загружаем заметки для темы
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      final notesList = await themesProvider.getNotesForTheme(widget.theme.id);

      // Сортируем по дате создания (новые сверху)
      notesList.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _themeNotes = notesList;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка при загрузке заметок темы: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Метод для создания новой заметки, привязанной к теме
  void _createNoteInTheme() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(
          initialThemeIds: [widget.theme.id],
        ),
      ),
    ).then((_) {
      // После возврата обновляем список заметок
      _loadNotes();
    });
  }

  // Метод для редактирования темы
  void _editTheme() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ThemeDetailScreen(
          theme: widget.theme,
          isEditMode: true,
        ),
      ),
    ).then((_) {
      // После возврата обновляем данные
      _loadNotes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Тема: ${widget.theme.name}'),
        backgroundColor: _themeColor.withOpacity(0.9),
        foregroundColor: Colors.white,
        actions: [
          // Кнопка редактирования темы
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
          : _themeNotes.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _themeNotes.length,
                    itemBuilder: (context, index) {
                      final note = _themeNotes[index];
                      return _buildSwipeableNoteItem(note);
                    },
                  ),
                ),
      // Добавляем кнопку создания заметки
      floatingActionButton: FloatingActionButton(
        backgroundColor: _themeColor,
        onPressed: _createNoteInTheme,
        tooltip: 'Создать заметку',
        child: const Icon(Icons.add, color: Colors.white),
      ),
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

  // Метод для создания свайпабельной заметки
  Widget _buildSwipeableNoteItem(Note note) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final Color indicatorColor = NoteStatusUtils.getNoteStatusColor(note);

    return Dismissible(
      key: Key('theme_note_${note.id}'),
      direction: DismissDirection.horizontal,

      // Фон при свайпе вправо (добавление/удаление из избранного)
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20.0),
        color: Colors.amber,
        child: Icon(
          note.isFavorite ? Icons.star_border : Icons.star,
          color: Colors.white,
        ),
      ),

      // Фон при свайпе влево (удаление заметки)
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),

      // Обработка свайпов
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Свайп влево - удаление заметки
          return await _showDeleteConfirmation(note);
        } else if (direction == DismissDirection.startToEnd) {
          // Свайп вправо - добавление/удаление из избранного
          await notesProvider.toggleFavorite(note.id);
          // Перезагружаем заметки чтобы увидеть изменение
          _loadNotes();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(note.isFavorite
                  ? 'Заметка удалена из избранного'
                  : 'Заметка добавлена в избранное'),
              duration: const Duration(seconds: 2),
            ),
          );
          return false; // Не убираем карточку
        }
        return false;
      },

      // Действие при свайпе
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          // Удаление заметки
          notesProvider.deleteNote(note.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Заметка удалена')),
          );
          // Обновляем список
          setState(() {
            _themeNotes.remove(note);
          });
        }
      },

      // Сама карточка заметки
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: indicatorColor,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: () => _openNoteDetail(note),
          onLongPress: () => _showNoteOptionsMenu(note),
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
                              color: indicatorColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              note.isCompleted
                                  ? 'Выполнено'
                                  : 'До ${DateFormat('d MMM').format(note.deadlineDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: indicatorColor,
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

                // Индикаторы медиа внизу
                if (_hasMediaContent(note))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        _buildMediaIndicators(note),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Диалог подтверждения удаления заметки
  Future<bool> _showDeleteConfirmation(Note note) async {
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

  // Контекстное меню по долгому нажатию
  void _showNoteOptionsMenu(Note note) {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.accentSecondary),
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
                ).then((_) => _loadNotes());
              },
            ),
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
                await notesProvider.toggleFavorite(note.id);
                _loadNotes();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить заметку',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(note).then((shouldDelete) {
                  if (shouldDelete) {
                    notesProvider.deleteNote(note.id);
                    _loadNotes();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Заметка удалена')),
                    );
                  }
                });
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
      // Обновляем данные при возврате
      _loadNotes();
    });
  }

  // Форматирование текста заметки для отображения
  String _formatNoteContent(String content) {
    // Удаляем разметку Markdown
    String formattedContent = content
        .replaceAll(RegExp(r'#{1,3}\s+'), '') // Заголовки
        .replaceAll(RegExp(r'\*\*|\*|__'), '') // Жирный, курсив
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // Ссылки
        .replaceAll('![voice](voice:.*?)', '') // Голосовые заметки
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
}
