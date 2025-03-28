import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme.dart';
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

class _ThemeDetailScreenState extends State<ThemeDetailScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  Color _selectedColor = AppColors.themeColors.first;
  List<String> _selectedNoteIds = [];
  List<Note> _notes = [];
  List<Note> _themeNotes = [];
  bool _isEditing = false;
  bool _isLoading = false;
  ThemeLogoType _selectedLogoType = ThemeLogoType.icon01;
  bool _isSettingsChanged = false;

  // Метод для определения, является ли цвет темным
  bool _isColorDark(Color color) {
    // Формула для вычисления яркости (0-1)
    double brightness =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return brightness < 0.3; // Если яркость < 0.3, считаем цвет тёмным
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

      // Безопасное присваивание типа логотипа
      _selectedLogoType = widget.theme!.logoType;
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

// Обновленный метод для построения полей ввода в стиле приложения
  Widget _buildInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Поле ввода названия темы
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white, // Белый цвет для полей ввода как на скриншоте
            borderRadius: BorderRadius.circular(12), // Скругленные углы
          ),
          child: TextField(
            controller: _nameController,
            autofocus: false,
            decoration: const InputDecoration(
              hintText: 'Введите название темы',
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey),
            ),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),

        // Поле ввода описания темы (с тем же стилем)
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              hintText: 'Введите описание темы (необязательно)',
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey),
            ),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // Метод для отображения сетки с выбором иконок (5x11)
  Widget _buildLogoTypeSelector() {
    // Используем медиа-запрос для адаптации к размеру экрана
    final screenWidth = MediaQuery.of(context).size.width;

    // Вычисляем сколько иконок в ряду для разных размеров экрана
    int crossAxisCount = 5; // По умолчанию 5 в ряду
    if (screenWidth < 320) {
      crossAxisCount = 4; // Для очень маленьких экранов
    } else if (screenWidth > 600) {
      crossAxisCount = 6; // Для больших экранов
    }

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

        // Показываем все 55 иконок в сетке с адаптивным числом колонок
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: ThemeLogoType.values.length, // 55 иконок
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

  // Обновленный метод для отображения выбора цветов с оптимальным распределением
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

        // Используем оптимальное распределение цветов
        _buildOptimizedColorGrid(),
      ],
    );
  }

  // Новый метод для оптимального распределения цветов
  Widget _buildOptimizedColorGrid() {
    final totalColors = AppColors.themeColors.length;

    // Рассчитываем оптимальное количество цветов в строке (от 5 до 7)
    int optimalColorsPerRow = 6; // По умолчанию
    int minRowCount = (totalColors / 7)
        .ceil(); // Минимальное кол-во строк при 7 цветах в строке

    // Проверяем варианты с 5, 6 и 7 цветами в строке, выбираем оптимальный
    for (int i = 5; i <= 7; i++) {
      int rows = (totalColors / i).ceil();
      // Если последняя строка заполнена более чем на 70% или количество строк меньше
      if (rows < minRowCount || (totalColors % i) / i > 0.7) {
        optimalColorsPerRow = i;
        minRowCount = rows;
      }
    }

    // Количество строк
    int rowCount = (totalColors / optimalColorsPerRow).ceil();

    // Строим сетку
    return Column(
      children: List.generate(rowCount, (rowIndex) {
        // Вычисляем количество цветов в текущей строке
        int startIndex = rowIndex * optimalColorsPerRow;
        int endIndex = (startIndex + optimalColorsPerRow <= totalColors)
            ? startIndex + optimalColorsPerRow
            : totalColors;
        int colorsInThisRow = endIndex - startIndex;

        // Создаем подлист цветов для этой строки
        List<Color> rowColors =
            AppColors.themeColors.sublist(startIndex, endIndex);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // Распределяем равномерно
            children: List.generate(colorsInThisRow, (colIndex) {
              final color = rowColors[colIndex];
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
            }),
          ),
        );
      }),
    );
  }

  // Метод для получения PNG-иконки в зависимости от типа
  Widget _getLogoIcon(ThemeLogoType type) {
    // Получаем номер иконки (от 01 до 55)
    String iconNumber = (type.index + 1).toString().padLeft(2, '0');
    String assetName = 'assets/icons/$iconNumber.png';

    // Проверяем, является ли цвет темы темным
    bool isDark = _isColorDark(_selectedColor);

    return isDark
        ? ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            child: Image.asset(
              assetName,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.image_not_supported,
                  size: 20,
                  color: Colors.white,
                );
              },
            ),
          )
        : Image.asset(
            assetName,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.image_not_supported,
                size: 20,
                color: Colors.black45,
              );
            },
          );
  }

  // Метод для создания круглого логотипа с PNG-иконкой
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
        padding: const EdgeInsets.all(8),
        child: ClipOval(
          child: icon,
        ),
      ),
    );
  }

  // Обновленный метод для списка заметок - адаптивный для разных экранов
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

        // Адаптивные карточки заметок с ограничением высоты
        Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height *
                0.35, // Ограничиваем максимальную высоту
          ),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: _notes.length,
            itemBuilder: (context, index) {
              final note = _notes[index];
              final isSelected = _selectedNoteIds.contains(note.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
        ),
      ],
    );
  }

  // Обновленный метод построения формы с адаптивной прокруткой
  Widget _buildEditForm() {
    // Используем медиа-запрос для адаптации под разные экраны
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 600; // Для компактных экранов

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
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

          // Обеспечиваем отступ внизу для плавающей кнопки
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // Отображаем выбранный логотип
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _selectedColor,
              ),
              width: 36,
              height: 36,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: ClipOval(
                  child: _isColorDark(_selectedColor)
                      ? ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                          child: Image.asset(
                            'assets/icons/${(_selectedLogoType.index + 1).toString().padLeft(2, '0')}.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.image_not_supported,
                                size: 18,
                                color: Colors.white,
                              );
                            },
                          ),
                        )
                      : Image.asset(
                          'assets/icons/${(_selectedLogoType.index + 1).toString().padLeft(2, '0')}.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported,
                              size: 18,
                              color: Colors.black45,
                            );
                          },
                        ),
                ),
              ),
            ),
            // Отображаем заголовок
            Expanded(
              child: Text(_isEditing ? 'Редактирование темы' : 'Новая тема'),
            ),
          ],
        ),
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
          : SafeArea(
              child: _buildEditForm(),
            ),
    );
  }

  // Методы для работы с контентом заметок
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
