import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme.dart'; // Здесь определено ThemeLogoType
import '../models/note.dart';
import '../providers/themes_provider.dart';
import '../providers/notes_provider.dart';
import '../utils/constants.dart';
import 'note_detail_screen.dart';
import '../widgets/note_list.dart';

class ThemeDetailScreen extends StatefulWidget {
  final NoteTheme? theme; // Null если создаем новую тему

  const ThemeDetailScreen({super.key, this.theme});

  @override
  State<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends State<ThemeDetailScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  Color _selectedColor = AppColors.themeColors.first;
  List<String> _selectedNoteIds = [];
  List<Note> _notes = [];
  List<Note> _themeNotes = [];
  bool _isEditing = false;
  bool _isLoading = false;
  // Добавляем поле для типа логотипа
  ThemeLogoType _selectedLogoType = ThemeLogoType.book;
  bool _isSettingsChanged = false; // Для отслеживания изменений в настройках

  // Метод построения UI для выбора типа логотипа
  Widget _buildLogoTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Иконка темы:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Сетка с вариантами логотипов (все в круглой форме)
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            // Существующие логотипы (преобразованные в круглую форму)
            _buildCircleLogoOption(
              ThemeLogoType.book,
              const Icon(Icons.auto_stories, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.shapes,
              const Icon(Icons.category, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.feather,
              const Icon(Icons.brush, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.scroll,
              const Icon(Icons.description, color: Colors.white, size: 32),
            ),

            // Новые логотипы
            _buildCircleLogoOption(
              ThemeLogoType.microphone,
              const Icon(Icons.mic, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.code,
              const Icon(Icons.code, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.graduation,
              const Icon(Icons.school, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.beach,
              const Icon(Icons.beach_access, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.party,
              const Icon(Icons.celebration, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.home,
              const Icon(Icons.home, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.business,
              const Icon(Icons.business_center, color: Colors.white, size: 32),
            ),
            _buildCircleLogoOption(
              ThemeLogoType.fitness,
              const Icon(Icons.fitness_center, color: Colors.white, size: 32),
            ),
          ],
        ),
      ],
    );
  }

// Новый метод для создания однотипных круглых логотипов без подписей
  Widget _buildCircleLogoOption(ThemeLogoType type, Icon icon) {
    final isSelected = _selectedLogoType == type;
    final color = _selectedColor;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLogoType = type;
          _isSettingsChanged = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 3,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Material(
          shape: const CircleBorder(),
          color: color,
          elevation: isSelected ? 6 : 2,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }

// Добавить новый метод для создания опции логотипа без текстовой метки
  Widget _buildLogoOptionNoLabel(
    ThemeLogoType type,
    Icon icon,
  ) {
    final isSelected = _selectedLogoType == type;
    final color = _selectedColor;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedLogoType = type;
          _isSettingsChanged = true;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 3,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Material(
          shape: const CircleBorder(),
          color: color,
          elevation: isSelected ? 6 : 2,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }

  // Вспомогательный метод для создания стандартных опций логотипа
  Widget _buildLogoOption(
    ThemeLogoType type,
    Icon icon,
    String label,
    ShapeBorder shape,
  ) {
    final isSelected = _selectedLogoType == type;
    final color = _selectedColor;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _selectedLogoType = type;
              _isSettingsChanged = true;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 3,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: Material(
              shape: shape,
              color: color,
              elevation: isSelected ? 6 : 2,
              child: SizedBox(
                width: 64,
                height: 64,
                child: Center(child: icon),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? _selectedColor : AppColors.textOnLight,
          ),
        ),
      ],
    );
  }

// Вспомогательный метод для создания кастомных опций логотипа
  Widget _buildCustomLogoOption(
    ThemeLogoType type,
    Icon icon,
    String label,
    Widget Function(Color, Widget) shapeBuilder,
  ) {
    final isSelected = _selectedLogoType == type;
    final color = _selectedColor;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _selectedLogoType = type;
              _isSettingsChanged = true;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 3,
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: shapeBuilder(
              color,
              icon,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? _selectedColor : AppColors.textOnLight,
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();

    if (widget.theme != null) {
      // Редактирование существующей темы
      _nameController.text = widget.theme!.name;
      _descriptionController.text = widget.theme!.description ?? '';

      try {
        _selectedColor = Color(int.parse(widget.theme!.color));
      } catch (e) {
        _selectedColor = AppColors.themeColors.first;
      }

      _selectedNoteIds = List.from(widget.theme!.noteIds);
      _isEditing = true;

      // Инициализируем тип логотипа из существующей темы
      _selectedLogoType = widget.theme!.logoType;
    }

    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Загружаем все заметки
      await Provider.of<NotesProvider>(context, listen: false).loadNotes();
      final notes = Provider.of<NotesProvider>(context, listen: false).notes;

      // Если редактируем тему, загружаем её заметки
      if (_isEditing) {
        final themesProvider =
            Provider.of<ThemesProvider>(context, listen: false);
        final themeNotes =
            await themesProvider.getNotesForTheme(widget.theme!.id);

        setState(() {
          _notes = notes;
          _themeNotes = themeNotes;
          _isLoading = false;
        });
      } else {
        setState(() {
          _notes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Редактирование темы' : 'Новая тема'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _showDeleteConfirmation,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveTheme,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildEditForm(),
    );
  }

  // Форма редактирования темы
  Widget _buildEditForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Название
            TextField(
              controller: _nameController,
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Введите название темы',
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Описание
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Введите описание темы (необязательно)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Выбор цвета
            const Text(
              'Цвет темы:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: AppColors.themeColors.map((color) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                      _isSettingsChanged = true;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor.value == color.value
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: _selectedColor.value == color.value
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Выбор типа логотипа (новая секция)
            _buildLogoTypeSelector(),

            const SizedBox(height: 24),

            // Заметки в теме
            if (_isEditing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Заметки в теме:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _showAddNotesToThemeDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить заметки'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildThemeNotesList(),
                ],
              ),

            // Выбор заметок при создании новой темы
            if (!_isEditing)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Выберите заметки для добавления:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_notes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          'Нет доступных заметок',
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        final isSelected = _selectedNoteIds.contains(note.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            title: Text(
                              _getNoteTitleFromContent(note.content),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnLight,
                              ),
                            ),
                            subtitle: Text(
                              _getNotePreviewFromContent(note.content),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textOnLight.withOpacity(0.8),
                              ),
                            ),
                            value: isSelected,
                            secondary: CircleAvatar(
                              backgroundColor:
                                  isSelected ? _selectedColor : Colors.grey,
                              child: const Icon(
                                Icons.note,
                                color: Colors.white,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  if (!_selectedNoteIds.contains(note.id)) {
                                    _selectedNoteIds.add(note.id);
                                  }
                                } else {
                                  _selectedNoteIds.remove(note.id);
                                }
                                _isSettingsChanged = true;
                              });
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Метод для отображения списка заметок с поддержкой свайпов
  Widget _buildThemeNotesList() {
    return _themeNotes.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'В этой теме пока нет заметок',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          )
        : SizedBox(
            height: 300, // Фиксированная высота для списка
            child: NoteListWidget(
              notes: _themeNotes,
              emptyMessage: 'В этой теме пока нет заметок',
              showThemeBadges:
                  false, // Не показываем метки тем, так как уже в контексте темы
              isInThemeView: false, // Используем отвязку от темы, а не удаление
              themeId: widget.theme!.id,
              swipeDirection: SwipeDirection.both,
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
            ),
          );
  }

  // Извлечение заголовка из контента заметки
  String _getNoteTitleFromContent(String content) {
    // Удаляем разметку голосовых заметок
    String cleanContent =
        content.replaceAll(RegExp(r'!\[voice\]\(voice:[^)]+\)'), '');

    // Ищем заголовок Markdown (# Заголовок)
    final headerMatch =
        RegExp(r'^#{1,3}\s+(.+)$', multiLine: true).firstMatch(cleanContent);
    if (headerMatch != null && headerMatch.group(1) != null) {
      return headerMatch.group(1)!;
    }

    // Если нет заголовка, берем первую строку
    final firstLineEnd = cleanContent.indexOf('\n');
    if (firstLineEnd > 0) {
      return cleanContent.substring(0, firstLineEnd).trim();
    }

    // Если нет переноса строки, берем весь текст
    return cleanContent.trim();
  }

// Извлечение предпросмотра из контента заметки
  String _getNotePreviewFromContent(String content) {
    // Удаляем разметку голосовых заметок
    String cleanContent =
        content.replaceAll(RegExp(r'!\[voice\]\(voice:[^)]+\)'), '');

    // Ищем текст после заголовка или после первой строки
    final headerMatch =
        RegExp(r'^#{1,3}\s+(.+)$', multiLine: true).firstMatch(cleanContent);

    if (headerMatch != null) {
      // Если нашли заголовок, берем текст после него
      final headerEnd = headerMatch.end;
      if (headerEnd < cleanContent.length) {
        final previewText = cleanContent.substring(headerEnd).trim();
        return previewText.isEmpty ? 'Нет дополнительного текста' : previewText;
      }
    }

    // Если нет заголовка, ищем текст после первой строки
    final firstLineEnd = cleanContent.indexOf('\n');
    if (firstLineEnd > 0 && firstLineEnd < cleanContent.length - 1) {
      return cleanContent.substring(firstLineEnd + 1).trim();
    }

    // Если нет дополнительного текста
    return 'Нет дополнительного текста';
  }

  Future<void> _saveTheme() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Название темы не может быть пустым')),
      );
      return;
    }

    final themesProvider = Provider.of<ThemesProvider>(context, listen: false);

    if (_isEditing && widget.theme != null) {
      // Обновление существующей темы
      final updatedTheme = widget.theme!.copyWith(
        name: name,
        description: description.isNotEmpty ? description : null,
        color: _selectedColor.value.toString(),
        noteIds: _selectedNoteIds,
        logoType: _selectedLogoType, // Сохраняем выбранный тип логотипа
      );

      await themesProvider.updateTheme(updatedTheme);
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      // Создание новой темы с передачей типа логотипа
      await themesProvider.createTheme(
        name,
        description.isNotEmpty ? description : null,
        _selectedColor.value.toString(),
        _selectedNoteIds,
        _selectedLogoType, // Передаем выбранный тип логотипа
      );

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить тему'),
        content:
            Text('Вы уверены, что хотите удалить тему "${widget.theme!.name}"? '
                'Это действие удалит тему и отвяжет все заметки от неё.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<ThemesProvider>(context, listen: false)
                  .deleteTheme(widget.theme!.id);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNotesToThemeDialog() {
    final availableNotes =
        _notes.where((note) => !_selectedNoteIds.contains(note.id)).toList();
    final selectedIds = <String>[];

    if (availableNotes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных заметок для добавления')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Добавить заметки в тему'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableNotes.length,
                itemBuilder: (context, index) {
                  final note = availableNotes[index];
                  final isSelected = selectedIds.contains(note.id);

                  return CheckboxListTile(
                    title: Text(
                      _getNoteTitleFromContent(note.content),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      _getNotePreviewFromContent(note.content),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedIds.add(note.id);
                        } else {
                          selectedIds.remove(note.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Не выбрано ни одной заметки')),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  final updatedIds = [..._selectedNoteIds, ...selectedIds];

                  if (widget.theme != null) {
                    final themesProvider =
                        Provider.of<ThemesProvider>(context, listen: false);
                    await themesProvider.linkNotesToTheme(
                        widget.theme!.id, selectedIds);

                    setState(() {
                      _selectedNoteIds = updatedIds;
                    });

                    // Перезагружаем заметки темы
                    _loadNotes();
                  } else {
                    setState(() {
                      _selectedNoteIds = updatedIds;
                    });
                  }
                },
                child: const Text('Добавить выбранные'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeNoteFromTheme(String noteId) async {
    if (widget.theme != null) {
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      await themesProvider.unlinkNoteFromTheme(widget.theme!.id, noteId);

      setState(() {
        _selectedNoteIds.remove(noteId);
      });

      // Перезагружаем заметки темы
      _loadNotes();
    }
  }
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
