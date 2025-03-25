import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../models/note.dart';
import '../utils/constants.dart';
import '../screens/note_detail_screen.dart';
import 'package:flutter/services.dart';

class UnthemedNotesScreen extends StatefulWidget {
  const UnthemedNotesScreen({Key? key}) : super(key: key);

  @override
  State<UnthemedNotesScreen> createState() => _UnthemedNotesScreenState();
  // Статический метод для открытия экрана
  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UnthemedNotesScreen(),
      ),
    );
  }
}

class _UnthemedNotesScreenState extends State<UnthemedNotesScreen> {
  bool _isLoading = true;
  List<Note> _unthemedNotes = [];
  final Set<String> _selectedNoteIds = {};
  bool _selectMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnthemedNotes();
    });
  }

  Future<void> _loadUnthemedNotes() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      // Принудительно загружаем актуальные заметки из базы данных
      await notesProvider.loadNotes(force: true);

      // Фильтруем заметки без темы
      final filteredNotes =
          notesProvider.notes.where((note) => note.themeIds.isEmpty).toList();

      // Сортируем по дате создания (от новых к старым)
      filteredNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _unthemedNotes = filteredNotes;
          _isLoading = false;

          // Сбрасываем выделение при обновлении списка
          if (_selectMode) {
            _selectedNoteIds.clear();
          }
        });
      }
    } catch (e) {
      print('Ошибка при загрузке заметок без темы: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке заметок: $e')),
        );
      }
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) {
        _selectedNoteIds.clear();
      }
    });
  }

  void _toggleNoteSelection(String noteId) {
    setState(() {
      if (_selectedNoteIds.contains(noteId)) {
        _selectedNoteIds.remove(noteId);
      } else {
        _selectedNoteIds.add(noteId);
      }
    });
  }

  void _selectAllNotes() {
    setState(() {
      if (_selectedNoteIds.length == _unthemedNotes.length) {
        // Если все заметки уже выбраны, снимаем выделение со всех
        _selectedNoteIds.clear();
      } else {
        // Иначе выбираем все заметки
        _selectedNoteIds.clear();
        for (final note in _unthemedNotes) {
          _selectedNoteIds.add(note.id);
        }
      }
    });
  }

  Future<void> _deleteSelectedNotes() async {
    if (_selectedNoteIds.isEmpty) return;

    // Подтверждение удаления
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удаление заметок'),
            content: Text(
                'Вы действительно хотите удалить ${_selectedNoteIds.length} '
                '${_getPluralForm(_selectedNoteIds.length, "заметку", "заметки", "заметок")}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      // Копируем список ID для безопасного удаления
      final notesToDelete = List<String>.from(_selectedNoteIds);

      // Удаляем заметки по очереди
      for (final noteId in notesToDelete) {
        await notesProvider.deleteNote(noteId);
      }

      // Показываем уведомление об успешном удалении
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Удалено ${notesToDelete.length} '
                '${_getPluralForm(notesToDelete.length, "заметка", "заметки", "заметок")}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Перезагружаем список заметок
      _loadUnthemedNotes();

      // Выходим из режима выбора
      setState(() {
        _selectMode = false;
        _selectedNoteIds.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при удалении заметок: $e')),
        );
      }
    }
  }

  // Вспомогательная функция для правильного склонения слов
  String _getPluralForm(int count, String form1, String form2, String form5) {
    if (count % 10 == 1 && count % 100 != 11) {
      return form1;
    } else if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return form2;
    } else {
      return form5;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectMode
            ? Text('Выбрано: ${_selectedNoteIds.length}')
            : const Text('Заметки без темы'),
        actions: [
          // Кнопка переключения режима выбора
          IconButton(
            icon: Icon(_selectMode ? Icons.close : Icons.check_box_outlined),
            tooltip: _selectMode ? 'Отменить выбор' : 'Режим выбора',
            onPressed: _toggleSelectMode,
          ),

          // Показываем дополнительные действия только в режиме выбора
          if (_selectMode) ...[
            // Кнопка "Выбрать все"
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Выбрать все',
              onPressed: _selectAllNotes,
            ),

            // Кнопка удаления выбранных заметок
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Удалить выбранные',
              onPressed:
                  _selectedNoteIds.isNotEmpty ? _deleteSelectedNotes : null,
            ),
          ],

          // В обычном режиме показываем кнопку обновления
          if (!_selectMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Обновить',
              onPressed: _loadUnthemedNotes,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _unthemedNotes.isEmpty
              ? _buildEmptyState()
              : _buildNotesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.layers_clear,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Нет заметок без темы',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Все ваши заметки распределены по темам',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NoteDetailScreen(),
                ),
              ).then((_) => _loadUnthemedNotes());
            },
            icon: const Icon(Icons.add),
            label: const Text('Создать заметку'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return RefreshIndicator(
      onRefresh: _loadUnthemedNotes,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _unthemedNotes.length,
        itemBuilder: (context, index) {
          final note = _unthemedNotes[index];
          final isSelected = _selectedNoteIds.contains(note.id);

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
              side: BorderSide(
                color:
                    isSelected ? AppColors.accentSecondary : Colors.transparent,
                width: isSelected ? 2.0 : 0.0,
              ),
            ),
            child: InkWell(
              onTap: _selectMode
                  ? () => _toggleNoteSelection(note.id)
                  : () {
                      // Открываем детальный просмотр заметки
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteDetailScreen(note: note),
                        ),
                      ).then((_) => _loadUnthemedNotes());
                    },
              onLongPress: () {
                if (!_selectMode) {
                  // Включаем режим выбора при долгом нажатии
                  HapticFeedback.mediumImpact();
                  _toggleSelectMode();
                  _toggleNoteSelection(note.id);
                }
              },
              borderRadius: BorderRadius.circular(8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Чекбокс или иконка в зависимости от режима
                    if (_selectMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleNoteSelection(note.id),
                        activeColor: AppColors.accentSecondary,
                      )
                    else
                      Icon(
                        Icons.note,
                        color: AppColors.textOnLight.withOpacity(0.6),
                        size: 20,
                      ),

                    const SizedBox(width: 8),

                    // Контент заметки
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Заголовок заметки - первая строка
                          Text(
                            _getFirstLine(note.content),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 4),

                          // Фрагмент контента
                          Text(
                            _getContentPreview(note.content),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textOnLight.withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // Дата создания
                          Text(
                            _getFormattedDate(note.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textOnLight.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Статусы заметки
                    if (note.hasDeadline && !_selectMode)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: note.isCompleted
                              ? AppColors.completed.withOpacity(0.2)
                              : const Color.fromRGBO(255, 255, 7, 0.35),
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
                              color: note.isCompleted
                                  ? AppColors.completed
                                  : AppColors.textOnLight,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              note.isCompleted ? 'Выполнено' : 'Дедлайн',
                              style: TextStyle(
                                fontSize: 12,
                                color: note.isCompleted
                                    ? AppColors.completed
                                    : AppColors.textOnLight,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Получение первой строки текста заметки (для заголовка)
  String _getFirstLine(String content) {
    if (content.isEmpty) return 'Без заголовка';

    final firstLineEnd = content.indexOf('\n');
    if (firstLineEnd == -1) return content;

    return content.substring(0, firstLineEnd).replaceAll(RegExp(r'^#+\s+'), '');
  }

  // Получение превью контента заметки без первой строки
  String _getContentPreview(String content) {
    if (content.isEmpty) return '';

    final firstLineEnd = content.indexOf('\n');
    if (firstLineEnd == -1) return '';

    final restContent = content.substring(firstLineEnd + 1).trim();
    return restContent.replaceAll(
        RegExp(r'!\[voice\]\(voice:[^)]+\)'), '[голосовая заметка]');
  }

  // Форматирование даты для отображения
  String _getFormattedDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Сегодня, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateToCheck == yesterday) {
      return 'Вчера, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }
}
