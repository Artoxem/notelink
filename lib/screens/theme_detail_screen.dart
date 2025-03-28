import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme.dart';
import '../models/note.dart';
import '../providers/themes_provider.dart';
import '../providers/notes_provider.dart';
import '../utils/constants.dart';
import 'note_detail_screen.dart';
import '../widgets/note_list.dart';
import '../models/theme.dart';

class ThemeDetailScreen extends StatefulWidget {
  final NoteTheme? theme; // Null если создаем новую тему

  const ThemeDetailScreen({super.key, this.theme});

  @override
  State<ThemeDetailScreen> createState() => _ThemeDetailScreenState();
}

class _ThemeDetailScreenState extends State<ThemeDetailScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  Color _selectedColor = AppColors.themeColors.first;
  List<String> _selectedNoteIds = [];
  List<Note> _notes = [];
  List<Note> _themeNotes = [];
  bool _isEditing = false;
  bool _isLoading = false;
  ThemeLogoType _selectedLogoType = ThemeLogoType.book;
  bool _isSettingsChanged = false;
  ThemeLogoType _defaultLogoType = ThemeLogoType.values[0];

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

      // Безопасное присваивание типа логотипа
      _selectedLogoType = widget.theme!.logoType;
    } else {
      // Для новой темы используем безопасное значение
      _selectedLogoType =
          ThemeLogoType.values[0]; // Первое значение из перечисления
    }

    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<NotesProvider>(context, listen: false).loadNotes();
      final notes = Provider.of<NotesProvider>(context, listen: false).notes;

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

  // Упрощенный метод для построения селектора логотипа
  Widget _buildLogoTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            'Иконка темы',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Показываем все иконки в более компактной сетке
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, // Увеличиваем количество колонок с 4 до 5
            childAspectRatio: 1.0,
            crossAxisSpacing: 8, // Уменьшаем отступы
            mainAxisSpacing: 8,
          ),
          itemCount: ThemeLogoType.values.length,
          itemBuilder: (context, index) {
            final logoType = ThemeLogoType.values[index];
            return _buildCircleLogoOption(
              logoType,
              _getLogoIcon(logoType),
            );
          },
        ),
      ],
    );
  }

  // Метод для получения PNG-иконки в зависимости от типа
  Widget _getLogoIcon(ThemeLogoType type) {
    // Получаем номер иконки на основе индекса перечисления
    String iconNumber;

    if (type.index <= 11) {
      // Для старых названий используем смещение
      iconNumber = (type.index + 1).toString().padLeft(2, '0');
    } else {
      // Для новых типов используем номер из названия
      iconNumber = (type.index - 11 + 13).toString().padLeft(2, '0');
    }

    String assetName = 'assets/icons/aztec$iconNumber.png';

    return Image.asset(
      assetName,
      width: 32,
      height: 32,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.image_not_supported,
          size: 20,
          color: Colors.white,
        );
      },
    );
  }

  // Обновлённый метод для создания круглого логотипа с PNG-иконкой
  Widget _buildCircleLogoOption(ThemeLogoType type, Widget icon) {
    final isSelected = _selectedLogoType == type;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLogoType = type;
          _isSettingsChanged = true;
        });
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _selectedColor,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        ),
        padding: const EdgeInsets.all(
            8), // Увеличено с 4 до 8 для пропорционального уменьшения иконки
        child: ClipOval(
          child: icon,
        ),
      ),
    );
  }

  // Упрощенный метод для отображения выбора цветов
  Widget _buildColorSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            'Цвет темы',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppColors.themeColors.map((color) {
            final isSelected = _selectedColor.value == color.value;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedColor = color;
                  _isSettingsChanged = true;
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
                child: isSelected
                    ? const Center(
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        ),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Упрощенный метод для построения полей ввода
  Widget _buildInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Поле ввода названия темы
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _nameController,
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Введите название темы',
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ),

        // Поле ввода описания темы (с тем же стилем)
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: 'Введите описание темы (необязательно)',
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
            style: const TextStyle(
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  // Упрощенный метод для списка заметок
  Widget _buildNoteSelector() {
    if (_notes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            'Выберите заметки для добавления',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Карточки заметок в простом стиле
        ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(), // Отключаем отдельную прокрутку
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
                ),
                subtitle: Text(
                  _getNotePreviewFromContent(note.content),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                value: isSelected,
                activeColor: _selectedColor,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedNoteIds.add(note.id);
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
    );
  }

  // Упрощенный метод построения формы
  Widget _buildEditForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Основные поля ввода
            _buildInputFields(),

            // Выбор цвета
            _buildColorSelector(),

            const SizedBox(height: 20),

            // Выбор логотипа
            _buildLogoTypeSelector(),

            const SizedBox(height: 20),

            // Выбор заметок
            if (!_isEditing) _buildNoteSelector(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
          ? Center(child: CircularProgressIndicator())
          : _buildEditForm(),
    );
  }

  // Методы для работы с контентом заметок (оставлены без изменений)
  String _getNoteTitleFromContent(String content) {
    String cleanContent =
        content.replaceAll(RegExp(r'!\[voice\]\(voice:[^)]+\)'), '');

    final headerMatch =
        RegExp(r'^#{1,3}\s+(.+)$', multiLine: true).firstMatch(cleanContent);
    if (headerMatch != null && headerMatch.group(1) != null) {
      return headerMatch.group(1)!;
    }

    final firstLineEnd = cleanContent.indexOf('\n');
    if (firstLineEnd > 0) {
      return cleanContent.substring(0, firstLineEnd).trim();
    }

    return cleanContent.trim();
  }

  String _getNotePreviewFromContent(String content) {
    String cleanContent =
        content.replaceAll(RegExp(r'!\[voice\]\(voice:[^)]+\)'), '');

    final headerMatch =
        RegExp(r'^#{1,3}\s+(.+)$', multiLine: true).firstMatch(cleanContent);

    if (headerMatch != null) {
      final headerEnd = headerMatch.end;
      if (headerEnd < cleanContent.length) {
        final previewText = cleanContent.substring(headerEnd).trim();
        return previewText.isEmpty ? 'Нет дополнительного текста' : previewText;
      }
    }

    final firstLineEnd = cleanContent.indexOf('\n');
    if (firstLineEnd > 0 && firstLineEnd < cleanContent.length - 1) {
      return cleanContent.substring(firstLineEnd + 1).trim();
    }

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
        logoType: _selectedLogoType,
      );

      await themesProvider.updateTheme(updatedTheme);
      if (mounted) {
        Navigator.pop(context);
      }
    } else {
      // Создание новой темы
      await themesProvider.createTheme(
        name,
        description.isNotEmpty ? description : null,
        _selectedColor.value.toString(),
        _selectedNoteIds,
        _selectedLogoType,
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
}
