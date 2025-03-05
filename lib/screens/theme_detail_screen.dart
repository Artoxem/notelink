import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme.dart';
import '../models/note.dart';
import '../providers/themes_provider.dart';
import '../providers/notes_provider.dart';
import '../utils/constants.dart';
import 'note_detail_screen.dart';

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
        title: Text(_isEditing ? 'Edit Theme' : 'New Theme'),
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название
                    TextField(
                      controller: _nameController,
                      autofocus: false, // Отключаем автофокус
                      decoration: const InputDecoration(
                        labelText: 'Theme Name',
                        hintText: 'Enter theme name',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Описание
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Enter theme description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Выбор цвета
                    const Text(
                      'Theme Color:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

                    // Заметки в теме
                    if (_isEditing)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Notes in Theme:',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                onPressed: _showAddNotesToThemeDialog,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Notes'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_themeNotes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'No notes in this theme yet',
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
                              itemCount: _themeNotes.length,
                              itemBuilder: (context, index) {
                                final note = _themeNotes[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    subtitle: Text(
                                      note.content,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: _selectedColor,
                                      child: const Icon(
                                        Icons.note,
                                        color: Colors.white,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _removeNoteFromTheme(note.id),
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              NoteDetailScreen(note: note),
                                        ),
                                      ).then((_) {
                                        // Перезагружаем заметки после возврата
                                        _loadNotes();
                                      });
                                    },
                                  ),
                                );
                              },
                            ),
                        ],
                      ),

                    // Выбор заметок при создании новой темы
                    if (!_isEditing)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Notes to Include:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (_notes.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: Text(
                                  'No notes available',
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
                                final isSelected =
                                    _selectedNoteIds.contains(note.id);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: CheckboxListTile(
                                    subtitle: Text(
                                      note.content,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    value: isSelected,
                                    secondary: CircleAvatar(
                                      backgroundColor: isSelected
                                          ? _selectedColor
                                          : Colors.grey,
                                      child: const Icon(
                                        Icons.note,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          if (!_selectedNoteIds
                                              .contains(note.id)) {
                                            _selectedNoteIds.add(note.id);
                                          }
                                        } else {
                                          _selectedNoteIds.remove(note.id);
                                        }
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
            ),
    );
  }

  Future<void> _saveTheme() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Theme name cannot be empty')),
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
      );

      await themesProvider.updateTheme(updatedTheme);
    } else {
      // Создание новой темы
      await themesProvider.createTheme(
        name,
        description.isNotEmpty ? description : null,
        _selectedColor.value.toString(),
        _selectedNoteIds,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Theme'),
        content:
            Text('Are you sure you want to delete "${widget.theme!.name}"? '
                'This will remove the theme and unlink all notes from it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
              'Delete',
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
        const SnackBar(content: Text('No more notes available to add')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Notes to Theme'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: availableNotes.length,
                itemBuilder: (context, index) {
                  final note = availableNotes[index];
                  final isSelected = selectedIds.contains(note.id);

                  return CheckboxListTile(
                    subtitle: Text(
                      note.content,
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No notes selected')),
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
                child: const Text('Add Selected'),
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
