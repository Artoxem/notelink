import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_links_service.dart';
import '../utils/constants.dart';
import '../utils/note_status_utils.dart';
import '../screens/note_detail_screen.dart';
import '../widgets/note_link_dialog.dart'; // Правильный импорт диалога
import 'package:intl/intl.dart';

class LinkedNotesSection extends StatefulWidget {
  final String noteId;
  final Function(Note)? onNoteSelected;

  const LinkedNotesSection({
    Key? key,
    required this.noteId,
    this.onNoteSelected,
  }) : super(key: key);

  @override
  State<LinkedNotesSection> createState() => _LinkedNotesSectionState();
}

class _LinkedNotesSectionState extends State<LinkedNotesSection> {
  final NoteLinksService _linkService = NoteLinksService();
  List<Note> _linkedNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLinkedNotes();
  }

  Future<void> _loadLinkedNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notes = await _linkService.getLinkedNotes(widget.noteId);
      if (mounted) {
        setState(() {
          _linkedNotes = notes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Связанные заметки',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // Кнопка добавления новой связи
              IconButton(
                icon: const Icon(Icons.add_link),
                tooltip: 'Добавить связь',
                onPressed: () => _addNewLink(context),
              ),
            ],
          ),
        ),

        // Индикатор загрузки или список связанных заметок
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_linkedNotes.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Нет связанных заметок',
                style: TextStyle(
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
            itemCount: _linkedNotes.length,
            itemBuilder: (context, index) {
              return _buildLinkedNoteItem(_linkedNotes[index]);
            },
          ),
      ],
    );
  }

  // Построение элемента связанной заметки
  Widget _buildLinkedNoteItem(Note note) {
    final borderColor = NoteStatusUtils.getNoteStatusColor(note);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: borderColor.withOpacity(0.2),
          foregroundColor: borderColor,
          child: Icon(NoteStatusUtils.getNoteStatusIcon(note)),
        ),
        title: Text(
          note.content.split('\n').first, // Первая строка как заголовок
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(DateFormat('d MMM yyyy').format(note.createdAt)),
            if (note.hasDeadline && note.deadlineDate != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: borderColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  NoteStatusUtils.getNoteStatusText(note),
                  style: TextStyle(
                    fontSize: 10,
                    color: borderColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.link_off),
          tooltip: 'Удалить связь',
          onPressed: () => _removeLink(note),
        ),
        onTap: () {
          if (widget.onNoteSelected != null) {
            widget.onNoteSelected!(note);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteDetailScreen(note: note),
              ),
            );
          }
        },
      ),
    );
  }

  // Исправленный метод добавления новой связи
  Future<void> _addNewLink(BuildContext context) async {
    // Используем статический метод show вместо прямого создания экземпляра
    final selectedNote = await NoteLinkDialog.show(context, widget.noteId);

    if (selectedNote != null) {
      // Создаем связь
      final linkId =
          await _linkService.createNoteLink(widget.noteId, selectedNote.id);

      if (linkId != null && mounted) {
        // Обновляем список связанных заметок
        _loadLinkedNotes();

        // Показываем уведомление об успешном создании связи
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Связь с заметкой "${selectedNote.content.split('\n').first}" создана'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  // Удаление связи
  Future<void> _removeLink(Note note) async {
    // Получаем все связи
    final links = await _linkService.getLinksForNote(widget.noteId);

    // Ищем связь между текущей и выбранной заметками
    String? linkIdToRemove;
    for (final link in links) {
      final sourceId = link['sourceNoteId'] as String;
      final targetId = link['targetNoteId'] as String;

      if ((sourceId == widget.noteId && targetId == note.id) ||
          (sourceId == note.id && targetId == widget.noteId)) {
        linkIdToRemove = link['id'] as String;
        break;
      }
    }

    if (linkIdToRemove != null) {
      // Удаляем связь
      final success = await _linkService.deleteNoteLink(linkIdToRemove);

      if (success && mounted) {
        // Обновляем список связанных заметок
        _loadLinkedNotes();

        // Показываем уведомление об успешном удалении связи
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Связь с заметкой "${note.content.split('\n').first}" удалена'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    }
  }
}
