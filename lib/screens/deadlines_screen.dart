import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';
import '../models/note.dart';
import '../utils/constants.dart';
import '../widgets/note_list.dart';
import 'note_detail_screen.dart';

class DeadlinesScreen extends StatefulWidget {
  const DeadlinesScreen({Key? key}) : super(key: key);

  @override
  State<DeadlinesScreen> createState() => _DeadlinesScreenState();
}

class _DeadlinesScreenState extends State<DeadlinesScreen> {
  bool _isLoading = false;
  List<Note> _deadlineNotes = [];
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadDeadlines();
  }

  Future<void> _loadDeadlines() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      // Всегда загружаем актуальные заметки
      await notesProvider.loadNotes();

      // Фильтруем заметки с дедлайнами
      List<Note> deadlineNotes =
          notesProvider.notes.where((note) => note.hasDeadline).toList();

      // Применяем фильтр по статусу "выполнено"
      if (!_showCompleted) {
        deadlineNotes =
            deadlineNotes.where((note) => !note.isCompleted).toList();
      }

      // Сортируем по дате дедлайна (сначала ближайшие)
      deadlineNotes.sort((a, b) {
        if (a.deadlineDate == null && b.deadlineDate == null) return 0;
        if (a.deadlineDate == null) return 1;
        if (b.deadlineDate == null) return -1;
        return a.deadlineDate!.compareTo(b.deadlineDate!);
      });

      if (mounted) {
        setState(() {
          _deadlineNotes = deadlineNotes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при загрузке задач: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи с дедлайном'),
        actions: [
          // Переключатель для отображения/скрытия выполненных задач
          Switch(
            value: _showCompleted,
            onChanged: (value) {
              setState(() {
                _showCompleted = value;
              });
              _loadDeadlines();
            },
            activeColor: AppColors.completed,
            activeTrackColor: AppColors.completed.withOpacity(0.5),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'Выполненные',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDeadlines,
              child: NoteListWidget(
                notes: _deadlineNotes,
                emptyMessage: _showCompleted
                    ? 'Нет задач с дедлайном'
                    : 'Нет активных задач с дедлайном',
                showThemeBadges: true,
                swipeDirection: SwipeDirection.both,
                onNoteTap: (note) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteDetailScreen(note: note),
                    ),
                  ).then((_) => _loadDeadlines());
                },
                onNoteDeleted: (note) async {
                  final notesProvider =
                      Provider.of<NotesProvider>(context, listen: false);
                  await notesProvider.deleteNote(note.id);
                  _loadDeadlines();
                },
                onNoteFavoriteToggled: (note) async {
                  final notesProvider =
                      Provider.of<NotesProvider>(context, listen: false);
                  await notesProvider.toggleFavorite(note.id);
                  _loadDeadlines();
                },
              ),
            ),
    );
  }
}
